package IMGames;

# Dancer2 modules
use Dancer2;
use Dancer2::Session::Cookie;
use Dancer2::Plugin::Deferred;
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Auth::Extensible;

use strict;
use warnings;

# IMGames modules
use IMGames::Schema;
use IMGames::Mail;
use IMGames::Log;
use IMGames::Util;

# Third Party modules
use version; our $VERSION = qv( 'v0.1.0' );

use DBIx::Class::Schema;
use DBICx::Sugar;
use Const::Fast;
use DateTime;
use Data::FormValidator;
use Data::FormValidator::Constraints;
use Data::Dumper;

const my $SCHEMA                    => IMGames::Schema->get_schema_connection();
const my $COUNTRY_CODE_SET          => 'LOCALE_CODE_ALPHA_2';
const my $USER_SESSION_EXPIRE_TIME  => 172800; # 48 hours in seconds.
const my $ADMIN_SESSION_EXPIRE_TIME => 600;    # 10 minutes in seconds.
const my $DATA_FORM_VALIDATOR       => Data::FormValidator->new( config->{'appdir'} . 'validation/form_validation_profiles.pl');
const my $DPAE_REALM                => 'site';

$SCHEMA->storage->debug(1);

DBICx::Sugar::config();

my $template = Template->new(
                              {
                                PLUGIN_BASE  => 'IMGames::Template::Plugin',
                              }
);


=head1 NAME

IMGames - The Infinite Monkeys Games website.


=head1 AUTHOR

Jason Lamey L<email:jasonlamey@gmail.com>


=head1 SYNOPSIS AND USAGE

Primary web application library, providing all routes and data calls.


=head1 HOOKS


=head2 before_template_render

Hooks to execute before template renders

=cut

hook before_template_render => sub
{
  my $tokens = shift;
  $tokens->{datetime_format_short} = config->{datetime_format_short};
  $tokens->{datetime_format_long}  = config->{datetime_format_long};
  $tokens->{date_format_short}     = config->{date_format_short};
  $tokens->{date_format_long}      = config->{date_format_long};
};


=head1 ROUTES


=head2 GET C</>

Returns the site index.

=cut

get '/' => sub
{
  template 'index';
};


=head2 POST C</signup>

Process sign-up information, and error-check.

=cut

post '/signup' => sub
{
  my $form_input   = body_parameters->as_hashref;
  my $form_results = $DATA_FORM_VALIDATOR->check( $form_input, 'signup_form' );

  if ( $form_results->has_invalid or $form_results->has_missing )
  {
    my @errors = ();
    for my $invalid ( $form_results->invalid )
    {
      push( @errors, sprintf( "<strong>%s</strong> is invalid: %s<br>", $invalid, $form_results->invalid( $invalid ) ) );
    }

    for my $missing ( $form_results->missing )
    {
      push( @errors, sprintf( "<strong>%s</strong> needs to be filled out.<br>", $missing ) );
    }

    deferred( error => sprintf( "Errors have occurred in your sign up information.<br>%s", join( '<br>', @errors ) ) );
    redirect '/';
  }

  my $user_check = $SCHEMA->resultset( 'User' )->find( { username => body_parameters->get( 'username' ) } );

  if (
      defined $user_check
      &&
      ref( $user_check ) eq 'IMGames::Schema::Result::User'
      &&
      $user_check->username eq body_parameters->get( 'username' )
     )
  {
    deferred error => sprintf( 'Username <strong>%s</strong> is already in use.', body_parameters->get( 'username' ) );
    redirect '/';
  }

  my $email_check = $SCHEMA->resultset( 'User' )->find( { email => body_parameters->get( 'email' ) } );

  if (
      defined $email_check
      &&
      ref( $email_check ) eq 'IMGames::Schema::Result::User'
      &&
      $email_check->email eq body_parameters->get( 'email' )
     )
  {
    deferred error => sprintf( 'There is already an account associated to the email address <strong>%s</strong>.', body_parameters->get( 'email' ) );
    redirect '/';
  }

  my $now = DateTime->now( time_zone => 'UTC' );

  # Create the user, and send the welcome e-mail.
  my $new_user = create_user(
                              username      => body_parameters->get( 'username' ),
                              realm         => $DPAE_REALM,
                              password      => body_parameters->get( 'password' ),
                              email         => body_parameters->get( 'email' ),
                              birthdate     => body_parameters->get( 'birthdate' ),
                              confirmed     => 0,
                              confirm_code  => IMGames::Util->generate_random_string(),
                              created_on    => $now,
                              email_welcome => 1,
                            );

  # Set the passord, encrypted.
  my $set_password = user_password( username => body_parameters->get( 'username' ), new_password => body_parameters->get( 'password' ) );

  # Set the initial user_role
  my $unconfirmed_role = $SCHEMA->resultset( 'Role' )->find( { role => 'Unconfirmed' } );

  my $user_role = $SCHEMA->resultset( 'UserRole' )->new(
                                                        {
                                                          user_id => $new_user->{id},
                                                          role_id => $unconfirmed_role->id,
                                                        }
                                                       );
  $SCHEMA->txn_do(
                  sub
                  {
                    $user_role->insert;
                  }
  );

  info sprintf( 'Created new user >%s<, ID: >%s<, on %s', body_parameters->get( 'username' ), $new_user->{id}, $now );

  # Email confirmation message to the user.

  deferred( success => sprintf("Thanks for signing up, %s! You have been logged in.", body_parameters->get( 'username' ) ) );

  # change session ID if we have a new enough D2 version with support
  # (security best practice on privilege level change)
  app->change_session_id if app->can('change_session_id');

  session 'logged_in_user' => body_parameters->get( 'username' );
  session 'logged_in_user_realm' => $DPAE_REALM;
  session->expires( $USER_SESSION_EXPIRE_TIME );

  redirect '/signed_up';
};


=head2 GET C</signed_up>

Successful sign-up page, with next-step instructions for account confirmation.

=cut

get '/signed_up' => require_login sub
{
  if ( ! session( 'logged_in_user' ) )
  {
    info 'An anonymous (not logged in) user attempted to access /signed_up.';
    deferred error => 'You need to be logged in to access that page.';
    redirect '/login';
  }

  my $user = $SCHEMA->resultset( 'User' )->find( { username => logged_in_user->{username} } );

  if ( ref( $user ) ne 'IMGames::Schema::Result::User' )
  {
    warning sprintf( 'A user (%s) attempted to reach /signed_up, but the account could not be confirmed to exist.', session( 'user' ) );
    deferred error => 'You need to be logged in to access that page.';
    redirect '/login';
  }

  template 'signed_up_success', {
                                  data =>
                                  {
                                    user         => $user,
                                    from_address => config->{mailer_address},
                                  },
                                };
};


=head2 GET C</login>

Login page for redirection, login errors, reattempt, etc.

=cut

get '/login/?:modal?' => sub
{
  my $layout = ( route_parameters->get( 'modal' ) ) ? 'modal' : 'main';
  template 'login',
    {},
    { layout => $layout };
};

=head2 POST C</login>

Authenticates user, and logs them in.  Otherwise, redirects them to the login page.

=cut

post '/login' => sub
{
  my ( $success, $realm ) = authenticate_user(
                                              body_parameters->get( 'username' ),
                                              body_parameters->get( 'password' ),
                                             );

  if ( ! $success )
  {
    deferred error => 'Invalid username or password.';
    warn sprintf( 'Invalid login attempt - Username:  >%s<, Password: >%s<', body_parameters->get( 'username' ), body_parameters->get( 'password' ) );
    redirect '/login';
  }

  # change session ID if we have a new enough D2 version with support
  # (security best practice on privilege level change)
  app->change_session_id if app->can('change_session_id');

  session 'logged_in_user'       => body_parameters->get( 'username' );
  session 'logged_in_user_realm' => $DPAE_REALM;
  session->expires( $USER_SESSION_EXPIRE_TIME );

  deferred success => sprintf( 'Welcome back, <strong>%s</strong>!', body_parameters->get( 'username' ) );
  info sprintf( 'User %s successfully logged in.', body_parameters->get( 'username' ) );

  redirect ( query_parameters->get( 'return_url' ) ) ? query_parameters->get( 'return_url' ) : '/user';
};


=head2 ANY C</logout>

Logout route, for killing user sessions, and redirecting to the index page.

=cut

any '/logout' => sub
{
  app->destroy_session;
  template 'logout';
};


=head2 ANY C</login/denied>

User denied access route for authentication failures.

=cut

any '/login/denied' => sub
{
  template 'login_denied';
};


=head2 GET C</account_confirmation>

GET route for confirmation code submission from welcome e-mails.

=cut

get '/account_confirmation/:ccode' => sub
{
  my $ccode = route_parameters->get( 'ccode' );

  my $user = $SCHEMA->resultset( 'User' )->find( { confirm_code => $ccode } );

  debug sprintf( 'User Ref: %s', ref( $user ) );

  if ( ! defined $user || ref( $user ) ne 'IMGames::Schema::Result::User' )
  {
    info sprintf( 'Confirmation Code submitted >%s< matched no user.', $ccode );
    return template 'account_confirmation', {
                                              data =>
                                              {
                                                ccode => $ccode,
                                              },
                                            };
  }

  update_user( $user->username, realm => $DPAE_REALM, confirm_code => undef, confirmed => 1 );

  # Set the user_role to Confirmed
  my $unconfirmed_role = $SCHEMA->resultset( 'Role' )->find( { role => 'Unconfirmed' } );
  my $role_to_delete   = $SCHEMA->resultset( 'UserRole' )->find( { user_id => $user->id, role_id => $unconfirmed_role->id } );
  $role_to_delete->delete();

  my $confirmed_role = $SCHEMA->resultset( 'Role' )->find( { role => 'Confirmed' } );

  my $user_role = $SCHEMA->resultset( 'UserRole' )->new(
                                                        {
                                                          user_id => $user->id,
                                                          role_id => $confirmed_role->id,
                                                        }
                                                       );
  $SCHEMA->txn_do(
                  sub
                  {
                    $user_role->insert;
                  }
  );

  template 'account_confirmation', {
                                    data =>
                                    {
                                      success => 1,
                                      user    => $user,
                                    },
                                   };
};


=head2 POST C</account_confirmation>

POST route for confirmation code resubmission.

=cut

post '/account_confirmation' => sub
{
  my $ccode = body_parameters->get( 'ccode' );

  redirect "/account_confirmation/$ccode";
};


=head2 GET C</user>

Logged in user's dashboard. User *must* be logged in to view this page.

=cut

get '/user' => require_login sub
{
  my $user = logged_in_user;
  template 'user_dashboard', {
                              data =>
                              {
                                user => $user,
                              },
                             };
};


=head2 GET C</products>

General product category listings route.

=cut

get '/products/?:category?/?:subcategory?' => sub
{
  my $category_shorthand = route_parameters->get( 'category' )    // undef;
  my $subcategory_id     = route_parameters->get( 'subcategory' ) // undef;

  my @breadcrumbs = ();
  my @categories  = ();
  my $display_mode = 'all';

  if ( $category_shorthand and $subcategory_id )
  {
    my $subcategory = $SCHEMA->resultset( 'ProductSubcategory' )->find( $subcategory_id,
                                                                  { prefetch  => [
                                                                                  { 'products' => 'product_type' },
                                                                                  'product_category',
                                                                                 ]
                                                                  }
                                                                );

    push @categories, $subcategory;

    $display_mode = 'subcategory';
    @breadcrumbs = (
                    { name => $subcategory->product_category->category, link => sprintf( '/products/%s', $category_shorthand ) },
                    { name => $subcategory->subcategory, link => sprintf( '/products/%s/%s', $category_shorthand, $subcategory_id ) },
                   );
  }
  elsif ( $category_shorthand and ! $subcategory_id )
  {
    my $category = $SCHEMA->resultset( 'ProductCategory' )->find( { shorthand => $category_shorthand },
                                                                  { prefetch  => [ { product_subcategories => 'products' } ] }
                                                                );

    push @categories, $category;

    @breadcrumbs = (
                    { name => $category->category, link => sprintf( '/products/%s', $category_shorthand ) },
                   );
    $display_mode = 'category';
  }
  else
  {
    my $categories_rs = $SCHEMA->resultset( 'ProductCategory' )->search( {},
                                                                         { prefetch  => [ { product_subcategories => 'products' } ] } );

    while ( my $category = $categories_rs->next )
    {
      push @categories, $category;
    }

    @breadcrumbs = (
                    { name => 'All Products', disabled => 1 },
                   );
  }

  template 'product_listing', {
                                data =>
                                {
                                  categories   => \@categories,
                                  display_mode => $display_mode,
                                },
                                breadcrumbs => \@breadcrumbs,
                              };
};


=head2 GET C</product>

Route to handle product details display.

=cut

get '/product/:product_id' => sub
{
  my $product_id = route_parameters->get( 'product_id' );

  my $product = $SCHEMA->resultset( 'Product' )->find( $product_id,
                                                        {
                                                          prefetch => [
                                                                        'product_type',
                                                                        { 'product_subcategory' => 'product_category' },
                                                                      ],
                                                        }
                                                     );
  my @breadcrumbs = (
                      { name => $product->product_subcategory->product_category->category,
                        link => sprintf( '/products/%s', $product->product_subcategory->product_category->shorthand ) },
                      { name => $product->product_subcategory->subcategory,
                        link => sprintf( '/products/%s/%s', $product->product_subcategory->product_category->shorthand, $product->product_subcategory->id ) },
                      { name => $product->name, disabled => 1 },
                    );
  template 'product', {
                        data =>
                          {
                            product => $product,
                          },
                        breadcrumbs => \@breadcrumbs,
                      };

};


=head2 GET C</admin>

Route to admin dashboard. Requires being logged in and of admin role.

=cut

get '/admin' => require_role Admin => sub
{
  template 'admin_dashboard',
    {
      data =>
      {
      },
      breadcrumbs =>
      [
        { name => 'Admin', current => 1 },
      ],
    };
};


=head2 GET C</admin/manage_products>

Route to Product Management dashboard. Requires being logged in and of admin role.

=cut

get '/admin/manage_products' => require_role Admin => sub
{

  my @products = $SCHEMA->resultset( 'Product' )->search( undef,
                                                          {
                                                            order_by => { -asc => 'name' },
                                                            prefetch => [
                                                                          'product_type',
                                                                          { 'product_subcategory' => 'product_category' },
                                                                        ],
                                                          }
                                                        );
  my @product_types = $SCHEMA->resultset( 'ProductType' )->search( undef,
                                                                    { order_by => { -asc => 'id' } }
                                                                 );
  my @product_subcategories = $SCHEMA->resultset( 'ProductSubcategory' )->search( undef,
                                                                    { order_by => { -asc => 'id' } }
                                                                 );

  debug Data::Dumper::Dumper( @products );

  template 'admin_manage_products',
                                    {
                                      data =>
                                      {
                                        products              => \@products,
                                        product_types         => \@product_types,
                                        product_subcategories => \@product_subcategories,
                                      },
                                      breadcrumbs =>
                                      [
                                        { name => 'Admin', link => '/admin' },
                                        { name => 'Manage Products', current => 1 },
                                      ],
                                    };
};


=head2 GET C</admin/manage_products/create>

Route to create new product. Requires being logged in and of Admin role.

=cut

get '/admin/manage_products/create/?:modal?' => require_role Admin => sub
{
  my @product_types = $SCHEMA->resultset( 'ProductType' )->search( undef,
                                                                    { order_by => { -asc => 'id' } }
                                                                 );
  my @product_subcategories = $SCHEMA->resultset( 'ProductSubcategory' )->search( undef,
                                                                    { order_by => { -asc => 'id' } }
                                                                 );

  my $layout = ( route_parameters->get( 'modal' ) ) ? 'modal' : 'main';
  template 'admin_manage_products_create',
      {
        data =>
        {
          product_types         => \@product_types,
          product_subcategories => \@product_subcategories,
        },
        breadcrumbs =>
        [
          { name => 'Admin', link => '/admin' },
          { name => 'Manage Products', link => '/admin/manage_products' },
          { name => 'Add New Product', current => 1 },
        ],
      },
      { layout => $layout };
};


=head2 POST C</admin/manage_products/add>

Route to save new product data to the database.  Requires being logged in and of Admin role.

=cut

post '/admin/manage_products/add' => require_role Admin => sub
{
  my $form_input   = body_parameters->as_hashref;
  my $form_results = $DATA_FORM_VALIDATOR->check( $form_input, 'admin_new_product_form' );

  if ( $form_results->has_invalid or $form_results->has_missing )
  {
    my @errors = ();
    for my $invalid ( $form_results->invalid )
    {
      push( @errors, sprintf( "<strong>%s</strong> is invalid: %s<br>", $invalid, $form_results->invalid( $invalid ) ) );
    }

    for my $missing ( $form_results->missing )
    {
      push( @errors, sprintf( "<strong>%s</strong> needs to be filled out.<br>", $missing ) );
    }

    deferred( error => sprintf( "Errors have occurred in your new product information.<br>%s", join( '<br>', @errors ) ) );
    redirect '/admin/manage_products';
  }

  my $product_check = $SCHEMA->resultset( 'Product' )->find( { name => body_parameters->get( 'name' ) } );

  if ( defined $product_check and ref( $product_check ) eq 'IMGames::Schema::Result::Product' )
  {
    deferred error => sprintf( 'Product &quot;<strong>%s</strong>&quot; already exists.', body_parameters->get( 'name' ) );
    redirect '/admin/manage_products';
  }

  my $now = DateTime->now( time_zone => 'UTC' );

  my $new_product = $SCHEMA->resultset( 'Product' )->create(
    {
      name                   => body_parameters->get( 'name' ),
      product_type_id        => body_parameters->get( 'product_type_id' ),
      product_subcategory_id => body_parameters->get( 'product_subcategory_id' ),
      base_price             => body_parameters->get( 'base_price' ),
      intro                  => body_parameters->get( 'intro' ),
      description            => body_parameters->get( 'description' ),
      created_on             => $now,
    }
  );

  info sprintf( 'Created new user >%s<, ID: >%s<, on %s', body_parameters->get( 'name' ), $new_product->{id}, $now );

  deferred success => sprintf( 'Successfully created &quot;<strong>%s</strong>&quot;!', body_parameters->get( 'name' ) );

  redirect '/admin/manage_products';
};


=head2 GET C</admin/manage_products/:product_id/edit>

Route for presenting the edit product form. Requires the user be logged in and an Admin.

=cut

get '/admin/manage_products/:product_id/edit' => require_role Admin => sub
{
  my $product_id = route_parameters->get( 'product_id' );

  my $product = $SCHEMA->resultset( 'Product' )->find( $product_id );

  my @product_types = $SCHEMA->resultset( 'ProductType' )->search( undef,
                                                                    { order_by => { -asc => 'id' } }
                                                                 );
  my @product_subcategories = $SCHEMA->resultset( 'ProductSubcategory' )->search( undef,
                                                                    { order_by => { -asc => 'id' } }
                                                                 );

  my $layout = ( route_parameters->get( 'modal' ) ) ? 'modal' : 'main';
  template 'admin_manage_products_edit',
      {
        data =>
        {
          product               => $product,
          product_types         => \@product_types,
          product_subcategories => \@product_subcategories,
        },
        breadcrumbs =>
        [
          { name => 'Admin', link => '/admin' },
          { name => 'Manage Products', link => '/admin/manage_products' },
          { name => sprintf( 'Edit Product (%s)', $product->name ), current => 1 },
        ],
      },
      { layout => $layout };
};


=head2 POST C</admin/manage_products/:product_id/update>

Route for updating a product record. Requires the user to be logged in and an Admin.

=cut

post '/admin/manage_products/:product_id/update' => require_role Admin => sub
{
  my $product_id = route_parameters->get( 'product_id' );

  my $form_input   = body_parameters->as_hashref;
  my $form_results = $DATA_FORM_VALIDATOR->check( $form_input, 'admin_edit_product_form' );

  if ( $form_results->has_invalid or $form_results->has_missing )
  {
    my @errors = ();
    for my $invalid ( $form_results->invalid )
    {
      push( @errors, sprintf( "<strong>%s</strong> is invalid: %s<br>", $invalid, $form_results->invalid( $invalid ) ) );
    }

    for my $missing ( $form_results->missing )
    {
      push( @errors, sprintf( "<strong>%s</strong> needs to be filled out.<br>", $missing ) );
    }

    deferred( error => sprintf( "Errors have occurred in your product information.<br>%s", join( '<br>', @errors ) ) );
    redirect '/admin/manage_products';
  }

  my $product = $SCHEMA->resultset( 'Product' )->find( $product_id );

  if ( not defined $product or ref( $product ) ne 'IMGames::Schema::Result::Product' )
  {
    deferred error => sprintf( 'Invalid Product ID <strong>%s</strong>.', $product_id );
    redirect '/admin/manage_products';
  }

  my $now = DateTime->now( time_zone => 'UTC' );
  $product->name( body_parameters->get( 'name' ) );
  $product->product_type_id( body_parameters->get( 'product_type_id' ) );
  $product->product_subcategory_id( body_parameters->get( 'product_subcategory_id' ) );
  $product->base_price( body_parameters->get( 'base_price' ) );
  $product->intro( body_parameters->get( 'intro' ) );
  $product->description( body_parameters->get( 'description' ) );
  $product->updated_on( $now );

  $product->update;

  deferred success => sprintf( 'Successfully updated Product <strong>%s</strong>!', $product->name );
  info sprintf( 'Product >%s< updated by %s on %s.', $product->name, logged_in_user->{ 'username' }, $now );

  redirect '/admin/manage_products';
};


=head2 GET C</admin/manage_products/:product_id/delete>

Route to delete a product. Requires the user be logged in and an Admin.

=cut

get '/admin/manage_products/:product_id/delete' => require_role Admin => sub
{
  my $product_id = route_parameters->get( 'product_id' );

  my $product = $SCHEMA->resultset( 'Product' )->find( $product_id );
  my $product_name = $product->name;

  $product->delete;

  deferred success => sprintf( 'Successfully deleted Product <strong>%s</strong>.', $product_name );
  redirect '/admin/manage_products';
};

=head1 COPYRIGHT & LICENSE

Copyright 2016, Infinite Monkeys Games L<http://www.infinitemonkeysgames.com>
All rights reserved.

=cut

true;
