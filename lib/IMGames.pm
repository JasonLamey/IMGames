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
use HTML::Restrict;
use GD::Thumbnail;

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

  my @featured_products = $SCHEMA->resultset( 'FeaturedProduct' )->search(
    {
      -or =>
      [
        expires_on => { '=' => undef },
        expires_on => { '>=' => DateTime->today() },
      ]
    },
  )->rand(4);

  my @products = $SCHEMA->resultset( 'Product' )->search(
    { 'featured_product.id' => undef },
    {
      join => 'featured_product',
    },
  )->rand(6);

  template 'index',
    {
      data =>
      {
        featured_products => \@featured_products,
        products          => \@products,
      }
    };
};


=head2 GET C</news>

Route to read posted news articles.

=cut

get '/news' => sub
{
  my @news = $SCHEMA->resultset( 'News' )->search(
    {},
    {
      order_by => { -desc => [ 'created_on' ] },
    },
  );

  template 'news',
    {
      data =>
      {
        news => \@news,
      },
      breadcrumbs =>
      [
        { name => 'News', current => 1 },
      ],
    };
};


=head2 GET C</news/:item_id>

Route to display a particular news item in full. Displays in a modal, called by AJAX.

=cut

get '/news/:item_id' => sub
{
  my $item_id = route_parameters->get( 'item_id' );

  my $item = $SCHEMA->resultset( 'News' )->find( $item_id );
  $item->views( $item->views + 1 );
  $item->update();

  return template 'news_modal',
    {
      data =>
      {
        item => $item,
      },
    },
    { layout => 'modal' };
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
  my $return_url = query_parameters->get( 'return_url' );

  template 'login',
    {
      data =>
      {
        return_url => $return_url
      }
    },
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

  redirect ( body_parameters->get( 'return_url' ) ) ? body_parameters->get( 'return_url' ) : '/user';
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
  template 'user_dashboard',
    {
      data =>
      {
        user => $user,
      },
      breadcrumbs =>
      [
        { name => 'User Dashboard', current => 1 },
      ],
    };
};


=head2 GET C</products>

General product category listings route.

=cut

get '/products/?:category?/?:subcategory?' => sub
{
  my $category_shorthand = route_parameters->get( 'category' )    // undef;
  my $subcategory_id     = route_parameters->get( 'subcategory' ) // undef;

  my @breadcrumbs           = ();
  my @categories            = ();
  my $display_mode          = 'all';
  my $num_featured_products = 0;
  my @featured_products     = ();

  if ( $category_shorthand and $subcategory_id )
  {
    my $subcategory = $SCHEMA->resultset( 'ProductSubcategory' )->find( $subcategory_id,
                                                                  { prefetch  => [
                                                                                  { 'products' => 'product_type' },
                                                                                  { 'products' => 'featured_product' },
                                                                                  'product_category',
                                                                                 ]
                                                                  }
                                                                );
    $num_featured_products = $subcategory->featured_products->count // 0;
    if ( $num_featured_products > 0 )
    {
      @featured_products = $subcategory->featured_products();
    }

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
                    { name => 'All Products', current => 1 },
                   );
  }

  template 'product_listing', {
                                data =>
                                {
                                  categories            => \@categories,
                                  num_featured_products => $num_featured_products,
                                  featured_products     => \@featured_products,
                                  display_mode          => $display_mode,
                                },
                                breadcrumbs => \@breadcrumbs,
                              };
};


=head2 GET C</product/:product_id/quickview>

Route to return page content via an AJAX call, to display product info in a modal.

=cut

get '/product/:product_id/quickview' => sub
{
  my $product_id = route_parameters->get( 'product_id' );

  my $product = $SCHEMA->resultset( 'Product' )->find( $product_id,
                                                        {
                                                          prefetch => [
                                                                        'product_type',
                                                                        'images',
                                                                      ],
                                                        }
  );

  if
  (
    ! defined $product
    or
    ref( $product ) ne 'IMGames::Schema::Result::Product'
  )
  {
    return 'Error finding product information.';
  }

  return template 'product_quick_info',
    {
      data =>
      {
        product => $product,
      }
    },
    { layout => 'modal' };
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
                                                                        'images',
                                                                      ],
                                                        }
                                                     );
  my @related_products = $SCHEMA->resultset( 'Product')->search(
    {},
    {
      where =>
      {
        product_subcategory_id => $product->product_subcategory_id,
        'me.id'                => { '!=' => $product->id },
      },
      rows => 5,
      prefetch =>
      [
        'images',
      ],
    },
  );

  my @breadcrumbs = (
                      { name => $product->product_subcategory->product_category->category,
                        link => sprintf( '/products/%s', $product->product_subcategory->product_category->shorthand ) },
                      { name => $product->product_subcategory->subcategory,
                        link => sprintf( '/products/%s/%s', $product->product_subcategory->product_category->shorthand, $product->product_subcategory->id ) },
                      { name => $product->name, current => 1 },
                    );

  template 'product', {
                        data =>
                          {
                            product              => $product,
                            review_count         => ( $product->reviews->count // 0 ),
                            average_review_score => $product->average_rating_score(),
                            related_products     => \@related_products,
                          },
                        breadcrumbs => \@breadcrumbs,
                      };

};


=head2 POST C</product/:product_id/review/create>

Route for saving of a user's product review. Requires the user be logged in and Confirmed.

=cut

post '/product/:product_id/review/create' => require_role Confirmed => sub
{
  my $product_id = route_parameters->get( 'product_id' );
  my $user = logged_in_user;

  my $form_input = body_parameters->as_hashref;
  my $form_results = $DATA_FORM_VALIDATOR->check( $form_input, 'product_review_form' );

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

    deferred( error => sprintf( "Errors have occurred in your product review.<br>%s", join( '<br>', @errors ) ) );
    redirect sprintf( '/product/%s', $product_id );
  }

  my $rules = IMGames::Util->get_allowed_html_rules;
  my $hr    = HTML::Restrict->new( rules => $rules );

  my $new_review = $SCHEMA->resultset( 'ProductReview' )->create(
    {
      product_id => $product_id,
      user_id    => $user->{id},
      title      => $hr->process( body_parameters->get( 'title' ) ),
      rating     => body_parameters->get( 'rating' ),
      content    => $hr->process( body_parameters->get( 'content' ) ),
      timestamp  => DateTime->now( time_zone => 'UTC' ),
    }
  );

  deferred success => 'Your review has been successfully posted! Thank you for your feedback!';

  redirect sprintf( '/product/%s', $product_id );
};


#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# ADMIN ROUTES BELOW HERE
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-


=head1 ADMIN ROUTES


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
                                                                          'images',
                                                                        ],
                                                          }
                                                        );
  my @product_types = $SCHEMA->resultset( 'ProductType' )->search( undef,
                                                                    { order_by => { -asc => 'id' } }
                                                                 );
  my @product_subcategories = $SCHEMA->resultset( 'ProductSubcategory' )->search( undef,
                                                                    { order_by => { -asc => 'id' } }
                                                                 );

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

  info sprintf( 'Created new product >%s<, ID: >%s<, on %s', body_parameters->get( 'name' ), $new_product->id, $now );

  deferred success => sprintf( 'Successfully created Product &quot;<strong>%s</strong>&quot;!', body_parameters->get( 'name' ) );

  redirect '/admin/manage_products';
};


=head2 GET C</admin/manage_products/:product_id/edit>

Route for presenting the edit product form. Requires the user be logged in and an Admin.

=cut

get '/admin/manage_products/:product_id/edit' => require_role Admin => sub
{
  my $product_id = route_parameters->get( 'product_id' );

  my $product = $SCHEMA->resultset( 'Product' )->find( $product_id,
                                                       {
                                                        prefetch =>
                                                        [
                                                          'images',
                                                        ],
                                                       },
  );

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
          endpoint              => sprintf( '/admin/manage_products/%s/upload', $product_id ),
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

  deferred success => sprintf( 'Successfully updated Product &quot;<strong>%s</strong>&quot;!', $product->name );
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


=head2 POST C</admin/manage_products/:product_id/upload>

Route for uploading product images and associating them to the indicated product. Require the user is an Admin.

=cut

post '/admin/manage_products/:product_id/upload' => require_role Admin => sub
{
  my $product_id  = route_parameters->get( 'product_id' );
  my $upload_data = request->upload( 'qqfile' );    # upload object

  # Save file to product image directory.
  my $product_dir = path( config->{ appdir }, sprintf( 'public/images/products/%s/', $product_id ) );
  mkdir $product_dir if not -e $product_dir;

  my $filepath = $product_dir . '/' . $upload_data->basename;
  my $copied = $upload_data->copy_to( $filepath );

  if ( ! $copied )
  {
    return to_json( { success => 0, error => 'Could not save file to the filesystem.', preventRetry => 1 } );
  }

  # Create Thumbnails - Small: max 250px w, Med: max 400px w, Large: max 650px w
  my @thumbs_config = (
    { max => 250, prefix => 's', rules => { square => 'crop' } },
    { max => 400, prefix => 'm', rules => { square => 'crop' } },
    { max => 650, prefix => 'l', rules => { square => 'crop', dimension_constraint => 1 } },
  );

  foreach my $thumb ( @thumbs_config )
  {
    my $thumbnail = GD::Thumbnail->new( %{$thumb->{rules}} );
    my $raw       = $thumbnail->create( $product_dir . '/' . $upload_data->basename, $thumb->{max}, undef );
    my $mime      = $thumbnail->mime;
    open    IMG, sprintf( '>%s/%s-%s', $product_dir, $thumb->{prefix}, $upload_data->basename );
    binmode IMG;
    print   IMG $raw;
    close   IMG;
  }

  # Save new database record of image associated to product.
  my $new_image = $SCHEMA->resultset( 'ProductImage' )->create(
    {
      product_id => $product_id,
      filename   => $upload_data->basename,
      highlight  => 0,
      created_on => DateTime->now( time_zone => 'UTC' ),
    },
  );

  return to_json( { success => 1 } );
};


=head2 POST C</admin/manage_products/:product_id/images/update>

Route for updating the highlighted image on a product. Requires Admin user.

=cut

post '/admin/manage_products/:product_id/images/update' => require_role Admin => sub
{
  my $product_id = route_parameters->get( 'product_id' );
  my $new_highlight_id = body_parameters->get( 'highlight' );

  if ( ! $new_highlight_id )
  {
    deferred notify => 'No highlighted image selected.';
    redirect sprintf( '/admin/manage_products/%s/edit', $product_id );
  }

  my $now = DateTime->now( time_zone => 'UTC' );

  my $highlighted_image = $SCHEMA->resultset( 'ProductImage' )->find( { product_id => $product_id, highlight => 1 } );
  if
  (
    defined $highlighted_image
    and
    ref( $highlighted_image ) eq 'IMGames::Schema::Result::ProductImage'
  )
  {
    if ( $highlighted_image->id == $new_highlight_id )
    {
      deferred notify => 'Highlighted image unchanged.';
      redirect sprintf( '/admin/manage_products/%s/edit', $product_id );
    }
    else
    {
      $highlighted_image->highlight( 0 );
      $highlighted_image->updated_on( $now );
      $highlighted_image->update;
    }
  }

  my $new_highlight = $SCHEMA->resultset( 'ProductImage' )->find( $new_highlight_id );
  $new_highlight->highlight( 1 );
  $highlighted_image->updated_on( $now );
  $new_highlight->update;

  deferred success => sprintf( 'Highlighted Image set to <strong>%s</strong>.', $new_highlight->filename );
  redirect sprintf( '/admin/manage_products/%s/edit', $product_id );
};


=head2 GET C</admin/manage_product_categories>

Route to manage product categories and subcategories. Requires user to be logged in and an Admin.

=cut

get '/admin/manage_product_categories' => require_role Admin => sub
{
  my @product_categories = $SCHEMA->resultset( 'ProductCategory' )->search( undef,
                                                                            { order_by => { -asc => 'category' } }
                                                                          );
  my @product_subcategories = $SCHEMA->resultset( 'ProductSubcategory' )->search( undef,
                                                                                  { order_by => { -asc => 'subcategory' } }
                                                                                );
  template 'admin_manage_product_categories',
      {
        data =>
        {
          product_categories    => \@product_categories,
          product_subcategories => \@product_subcategories,
        },
        breadcrumbs =>
        [
          { name => 'Admin', link => '/admin' },
          { name => 'Manage Product Categories and Subcategories', current => 1 },
        ],
      };
};


=head2 POST C</admin/manage_product_categories/add>

Route for adding a new product category. Requires user is logged in and an Admin.

=cut

post '/admin/manage_product_categories/add' => require_role Admin => sub
{
  my $form_input = body_parameters->as_hashref;

  my $form_results = $DATA_FORM_VALIDATOR->check( $form_input, 'admin_new_product_category_form' );

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

    deferred( error => sprintf( "Errors have occurred in your product category information.<br>%s", join( '<br>', @errors ) ) );
    redirect '/admin/manage_product_categories';
  }

  my $category_exists  = $SCHEMA->resultset( 'ProductCategory' )->count( { category  => body_parameters->get( 'category' ) } );
  my $shorthand_exists = $SCHEMA->resultset( 'ProductCategory' )->count( { shorthand => body_parameters->get( 'shorthand' ) } );

  if ( $category_exists )
  {
    deferred error => sprintf( 'A category called &quot;<strong>%s</strong>&quot; already exists.', body_parameters->get( 'category' ) );
    redirect '/admin/manage_product_categories';
  }

  if ( $shorthand_exists )
  {
    deferred error => sprintf( 'A category with shorthand &quot;<strong>%s</strong>&quot; already exists.', body_parameters->get( 'shorthand' ) );
    redirect '/admin/manage_product_categories';
  }

  my $now = DateTime->now( time_zone => 'UTC' );
  my $new_product_category = $SCHEMA->resultset( 'ProductCategory' )->create(
    {
      category   => body_parameters->get( 'category' ),
      shorthand  => body_parameters->get( 'shorthand' ),
      created_on => $now,
    }
  );

  if
  (
    not defined $new_product_category
    or
    ref( $new_product_category ) ne 'IMGames::Schema::Result::ProductCategory'
  )
  {
    deferred error => sprintf( 'Something went wrong. Could not save Product Category &quot;<strong>%s</strong>&quot;.', body_parameters->get( 'category' ) );
    redirect '/admin/manage_product_categories';
  }

  info sprintf( 'Created new product category >%s<, ID: >%s<, on %s', body_parameters->get( 'category' ), $new_product_category->id, $now );

  deferred success => sprintf( 'Successfully created Product Category &quot;<strong>%s</strong>&quot;!', body_parameters->get( 'category' ) );

  redirect '/admin/manage_product_categories';
};


=head2 GET C</admin/manage_product_categories/:product_category_id/delete>

Route to delete a product category. Requires the user to be logged in and an Admin.

=cut

get '/admin/manage_product_categories/:product_category_id/delete' => require_role Admin => sub
{
  my $product_category_id = route_parameters->get( 'product_category_id' );

  my $product_category = $SCHEMA->resultset( 'ProductCategory' )->find( $product_category_id );

  if
  (
    not defined $product_category
    or
    ref( $product_category ) ne 'IMGames::Schema::Result::ProductCategory'
  )
  {
    deferred error => sprintf( 'Unknown or invalid product category.' );
    redirect '/admin/manage_product_categories';
  }

  my @subcategories = $product_category->product_subcategories;
  if ( scalar( @subcategories ) > 0 )
  {
    deferred error => sprintf( 'Unable to delete product category &quot;<strong>%s</strong>&quot;. It still has associated subcategories.<br>Remove or reassign those subcategories, first.',
                                $product_category->category );
    redirect '/admin/manage_product_categories';
  }

  my $category = $product_category->category;

  my $deleted = $product_category->delete();
  if ( defined $deleted and $deleted < 1 )
  {
    deferred error => sprintf( 'Unabled to delete product category &quot;<strong>%s</strong>&quot;.', $product_category->category );
    redirect '/admin/manage_product_categories';
  }

  deferred success => sprintf( 'Successfully deleted product category &quot;<strong>%s</strong>&quot;.', $category );

  info sprintf( 'Deleted product category >%s<, ID: >%s<, on %s', $category, $product_category_id, DateTime->now( time_zone => 'UTC' ) );

  redirect '/admin/manage_product_categories';
};


=head2 GET C</admin/manage_product_categories/:product_category_id/edit>

Route to the product category edit form. Requires a logged in user with Admin role.

=cut

get '/admin/manage_product_categories/:product_category_id/edit' => require_role Admin => sub
{
  my $product_category_id = route_parameters->get( 'product_category_id' );

  my $product_category = $SCHEMA->resultset( 'ProductCategory' )->find( $product_category_id );

  if
  (
    not defined $product_category
    or
    ref( $product_category ) ne 'IMGames::Schema::Result::ProductCategory'
  )
  {
    deferred error => sprintf( 'Unknown or invalid product category.' );
    redirect '/admin/manage_product_categories';
  }

  template 'admin_manage_product_categories_edit.tt',
    {
      data =>
      {
        product_category => $product_category,
      },
      breadcrumbs =>
      [
        { name => 'Admin', link => '/admin' },
        { name => 'Manage Product Categories and Subcategories', link => '/admin/manage_product_categories' },
        { name => sprintf( 'Edit Product Category (%s)', $product_category->category ), current => 1 },
      ],
    };
};


=head2 POST C</admin/manage_product_categories/:product_category_id/update>

Route to save updated product category information. Requires logged in user to be Admin.

=cut

post '/admin/manage_product_categories/:product_category_id/update' => require_role Admin => sub
{
  my $product_category_id = route_parameters->get( 'product_category_id' );

  my $form_input = body_parameters->as_hashref;
  my $form_results = $DATA_FORM_VALIDATOR->check( $form_input, 'admin_edit_product_category_form' );

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

    deferred( error => sprintf( "Errors have occurred in your product category information.<br>%s", join( '<br>', @errors ) ) );
    redirect '/admin/manage_product_categories';
  }

  my $category_exists  = $SCHEMA->resultset( 'ProductCategory' )->count(
    {
      category  => body_parameters->get( 'category' )
    },
    {
      where =>
      {
        id => { '!=' => $product_category_id },
      },
    },
  );
  my $shorthand_exists = $SCHEMA->resultset( 'ProductCategory' )->count(
    {
      shorthand => body_parameters->get( 'shorthand' ),
    },
    {
      where =>
      {
        id => { '!=' => $product_category_id },
      },
    },
  );

  if ( $category_exists )
  {
    deferred error => sprintf( 'A category called &quot;<strong>%s</strong>&quot; already exists.', body_parameters->get( 'category' ) );
    redirect '/admin/manage_product_categories';
  }

  if ( $shorthand_exists )
  {
    deferred error => sprintf( 'A category with shorthand &quot;<strong>%s</strong>&quot; already exists.', body_parameters->get( 'shorthand' ) );
    redirect '/admin/manage_product_categories';
  }

  my $product_category = $SCHEMA->resultset( 'ProductCategory' )->find( $product_category_id );

  my $now = DateTime->now( time_zone => 'UTC' );
  $product_category->category( body_parameters->get( 'category' ) );
  $product_category->shorthand( body_parameters->get( 'shorthand' ) );
  $product_category->updated_on( $now );

  $product_category->update;

  deferred success => sprintf( 'Successfully updated product category &quot;<strong>%s</strong>&quot;.', $product_category->category );

  info sprintf( 'Updated product category >%s<, ID: >%s<, on %s', $product_category->category, $product_category_id, $now );

  redirect '/admin/manage_product_categories';
};


=head2 POST C</admin/manage_product_categories/subcategory/add>

Route for adding a new product subcategory. Requires user is logged in and an Admin.

=cut

post '/admin/manage_product_categories/subcategory/add' => require_role Admin => sub
{
  my $form_input = body_parameters->as_hashref;

  my $form_results = $DATA_FORM_VALIDATOR->check( $form_input, 'admin_new_product_subcategory_form' );

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

    deferred( error => sprintf( "Errors have occurred in your product subcategory information.<br>%s", join( '<br>', @errors ) ) );
    redirect '/admin/manage_product_categories';
  }

  my $subcategory_exists  = $SCHEMA->resultset( 'ProductSubcategory' )->count( { subcategory  => body_parameters->get( 'subcategory' ) } );

  if ( $subcategory_exists )
  {
    deferred error => sprintf( 'A subcategory called &quot;<strong>%s</strong>&quot; already exists.', body_parameters->get( 'subcategory' ) );
    redirect '/admin/manage_product_categories';
  }

  my $now = DateTime->now( time_zone => 'UTC' );
  my $new_product_subcategory = $SCHEMA->resultset( 'ProductSubcategory' )->create(
    {
      subcategory => body_parameters->get( 'subcategory' ),
      category_id => body_parameters->get( 'category_id' ),
      created_on  => $now,
    }
  );

  if
  (
    not defined $new_product_subcategory
    or
    ref( $new_product_subcategory ) ne 'IMGames::Schema::Result::ProductSubcategory'
  )
  {
    deferred error => sprintf( 'Something went wrong. Could not save Product Subcategory &quot;<strong>%s</strong>&quot;.', body_parameters->get( 'subcategory' ) );
    redirect '/admin/manage_product_categories';
  }

  info sprintf( 'Created new product subcategory >%s<, ID: >%s<, on %s', body_parameters->get( 'subcategory' ), $new_product_subcategory->id, $now );

  deferred success => sprintf( 'Successfully created Product Subcategory &quot;<strong>%s</strong>&quot;!', body_parameters->get( 'subcategory' ) );

  redirect '/admin/manage_product_categories';
};


=head2 GET C</admin/manage_product_categories/subcategory/:product_subcategory_id/delete>

Route to delete a product subcategory. Requires the user to be logged in and an Admin.

=cut

get '/admin/manage_product_categories/subcategory/:product_subcategory_id/delete' => require_role Admin => sub
{
  my $product_subcategory_id = route_parameters->get( 'product_subcategory_id' );

  my $product_subcategory = $SCHEMA->resultset( 'ProductSubcategory' )->find( $product_subcategory_id );

  if
  (
    not defined $product_subcategory
    or
    ref( $product_subcategory ) ne 'IMGames::Schema::Result::ProductSubcategory'
  )
  {
    deferred error => sprintf( 'Unknown or invalid product subcategory.' );
    redirect '/admin/manage_product_categories';
  }

  my @products = $product_subcategory->products;
  if ( scalar( @products ) > 0 )
  {
    deferred error => sprintf( 'Unable to delete product subcategory &quot;<strong>%s</strong>&quot;. It still has associated products.<br>Remove or reassign those products, first.',
                                $product_subcategory->subcategory );
    redirect '/admin/manage_product_categories';
  }

  my $subcategory = $product_subcategory->subcategory;

  my $deleted = $product_subcategory->delete();
  if ( defined $deleted and $deleted < 1 )
  {
    deferred error => sprintf( 'Unabled to delete product subcategory &quot;<strong>%s</strong>&quot;.', $product_subcategory->subcategory );
    redirect '/admin/manage_product_categories';
  }

  deferred success => sprintf( 'Successfully deleted product subcategory &quot;<strong>%s</strong>&quot;.', $subcategory );

  info sprintf( 'Deleted product subcategory >%s<, ID: >%s<, on %s', $subcategory, $product_subcategory_id, DateTime->now( time_zone => 'UTC' ) );

  redirect '/admin/manage_product_categories';
};


=head2 GET C</admin/manage_product_categories/subcategory/:product_subcategory_id/edit>

Route to the product subcategory edit form. Requires a logged in user with Admin role.

=cut

get '/admin/manage_product_categories/subcategory/:product_subcategory_id/edit' => require_role Admin => sub
{
  my $product_subcategory_id = route_parameters->get( 'product_subcategory_id' );

  my $product_subcategory = $SCHEMA->resultset( 'ProductSubcategory' )->find( $product_subcategory_id );

  if
  (
    not defined $product_subcategory
    or
    ref( $product_subcategory ) ne 'IMGames::Schema::Result::ProductSubcategory'
  )
  {
    deferred error => sprintf( 'Unknown or invalid product subcategory.' );
    redirect '/admin/manage_product_categories';
  }

  my @product_categories = $SCHEMA->resultset( 'ProductCategory' )->search( undef,
                                                                            { order_by => { -asc => 'category' } }
                                                                          );

  template 'admin_manage_product_subcategories_edit.tt',
    {
      data =>
      {
        product_categories  => \@product_categories,
        product_subcategory => $product_subcategory,
      },
      breadcrumbs =>
      [
        { name => 'Admin', link => '/admin' },
        { name => 'Manage Product Categories and Subcategories', link => '/admin/manage_product_categories' },
        { name => sprintf( 'Edit Product Subcategory (%s)', $product_subcategory->subcategory ), current => 1 },
      ],
    };
};


=head2 POST C</admin/manage_product_categories/subcategory/:product_subcategory_id/update>

Route to save updated product subcategory information. Requires logged in user to be Admin.

=cut

post '/admin/manage_product_categories/subcategory/:product_subcategory_id/update' => require_role Admin => sub
{
  my $product_subcategory_id = route_parameters->get( 'product_subcategory_id' );

  my $form_input = body_parameters->as_hashref;
  my $form_results = $DATA_FORM_VALIDATOR->check( $form_input, 'admin_edit_product_subcategory_form' );

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

    deferred( error => sprintf( "Errors have occurred in your product subcategory information.<br>%s", join( '<br>', @errors ) ) );
    redirect '/admin/manage_product_categories';
  }

  my $subcategory_exists  = $SCHEMA->resultset( 'ProductSubcategory' )->count(
    {
      subcategory  => body_parameters->get( 'subcategory' )
    },
    {
      where =>
      {
        id => { '!=' => $product_subcategory_id },
      },
    },
  );

  if ( $subcategory_exists )
  {
    deferred error => sprintf( 'A subcategory called &quot;<strong>%s</strong>&quot; already exists.', body_parameters->get( 'subcategory' ) );
    redirect '/admin/manage_product_categories';
  }

  my $product_subcategory = $SCHEMA->resultset( 'ProductSubcategory' )->find( $product_subcategory_id );

  my $now = DateTime->now( time_zone => 'UTC' );
  $product_subcategory->subcategory( body_parameters->get( 'subcategory' ) );
  $product_subcategory->category_id( body_parameters->get( 'category_id' ) );
  $product_subcategory->updated_on( $now );

  $product_subcategory->update;

  deferred success => sprintf( 'Successfully updated product subcategory &quot;<strong>%s</strong>&quot;.', $product_subcategory->subcategory );

  info sprintf( 'Updated product category >%s<, ID: >%s<, on %s', $product_subcategory->subcategory, $product_subcategory_id, $now );

  redirect '/admin/manage_product_categories';
};


=head2 GET C</admin/manage_featured_products>

Route to manage which Products are featured for each subcategory. Requires Admin.

=cut

get '/admin/manage_featured_products' => require_role Admin => sub
{
  my @products = $SCHEMA->resultset( 'Product' )->search( {},
    {
      order_by => [ 'product_category.category', 'product_subcategory.subcategory', 'me.name' ],
      prefetch =>
      [
        { 'product_subcategory' => 'product_category' },
        'featured_product',
      ],
    },
  );

  template 'admin_manage_featured_products',
  {
    data =>
    {
      products => \@products,
    },
    breadcrumbs =>
    [
      { name => 'Admin', link => '/admin' },
      { name => 'Manage Featured Products', current => 1 },
    ],
  };
};

=head2 POST C</admin/manage_product_categories/update>

Route to update all featured product entries. Requires Admin access.

=cut

post '/admin/manage_featured_products/update' => require_role Admin => sub
{
  my $form_input = body_parameters->as_hashref;

  my @updated = ();
  foreach my $key ( sort keys %{$form_input} )
  {
    if ( $key =~ m/^(featured_)(\d+)_old$/ )
    {
      if
      (
        $form_input->{$1.$2} ne $form_input->{$key}
        or
        $form_input->{'expires_on_' . $2} ne $form_input->{'expires_on_' . $2 . '_old'}
      )
      {
        # If featured_n = 1, update or create it. Otherwise, delete it.
        if ( $form_input->{$1.$2} == 1 )
        {
          my $featured_product = $SCHEMA->resultset( 'FeaturedProduct' )->update_or_create(
            {
              product_id             => $2,
              product_subcategory_id => $form_input->{'product_subcategory_id_' . $2},
              expires_on             => ( $form_input->{'expires_on_' . $2} ) ? $form_input->{'expires_on_' . $2} : undef,
              created_on             => ( $form_input->{'created_on_' . $2} ) ? $form_input->{'created_on_' . $2}
                                                                              : DateTime->today( time_zone => 'UTC' ),
            },
            { key => 'productid_subcategoryid' },
          );

          push( @updated, sprintf( 'Featuring &quot;<strong>%s</strong>&quot;', $featured_product->product->name ) );
        }
        else
        {
          my $featured_product = $SCHEMA->resultset( 'FeaturedProduct' )->find(
            {
              product_id             => $2,
              product_subcategory_id => $form_input->{'product_subcategory_id_' . $2},
            }
          );

          push( @updated, sprintf( 'Unfeatured &quot;<strong>%s</strong>&quot;', $featured_product->product->name ) );

          $featured_product->delete;
        }
      }
    }
  }

  deferred success => join( '<br>', @updated );

  redirect '/admin/manage_featured_products';
};


=head2 GET C</admin/manage_news>

Route to managing news items.  Requires Admin user.

=cut

get '/admin/manage_news' => require_role Admin => sub
{
  my @news = $SCHEMA->resultset( 'News' )->search(
    {},
    {
      order_by => [ 'created_on' ],
    },
  );

  template 'admin_manage_news.tt',
    {
      data =>
      {
        news => \@news,
      },
      breadcrumbs =>
      [
        { name => 'Admin', link => '/admin' },
        { name => 'Manage News', current => 1 },
      ],
    }
};


=head2 GET C</admin/manage_news/add>

Route for add new news item form. Requires Admin user.

=cut

get '/admin/manage_news/add' => require_role Admin => sub
{
  template 'admin_manage_news_add_form.tt',
    {
      breadcrumbs =>
      [
        { name => 'Admin',       link => '/admin' },
        { name => 'Manage News', link => '/admin/manage_news' },
        { name => 'Add New News Item', current => 1 },
      ],
    },
};


=head2 POST C</admin/manage_news/create>

Route to save new news item to the database. Requires Admin.

=cut

post '/admin/manage_news/create' => require_role Admin => sub
{
  my $form_input     = body_parameters->as_hashref;

  # TODO: Server-side form validation here.

  my $now = DateTime->now( time_zone => 'UTC' );
  my $new_news = $SCHEMA->resultset( 'News' )->create(
    {
      title      => body_parameters->get( 'title' ),
      content    => body_parameters->get( 'content' ),
      user_id    => logged_in_user->{ id },
      views      => 0,
      created_on => $now,
    },
  );

  if
  (
    ! defined $new_news
    or
    ref( $new_news ) ne 'IMGames::Schema::Result::News'
  )
  {
    deferred error => 'An error occurred and the news item could not be saved.';
    redirect '/admin/manage_news';
  };

  deferred success => sprintf( 'Your new news item &quot;<strong>%s</strong>&quot; was saved.',
                                body_parameters->get( 'title' ) );

  redirect '/admin/manage_news';
};


=head2 GET C</admin/manage_news/:item_id/edit>

Route to edit a news item. Requires Admin.

=cut

get '/admin/manage_news/:item_id/edit' => require_role Admin => sub
{
  my $item_id = route_parameters->get( 'item_id' );

  my $item = $SCHEMA->resultset( 'News' )->find( $item_id );

  if
  (
    not defined $item
    or
    ref( $item ) ne 'IMGames::Schema::Result::News'
  )
  {
    deferred error => 'Invalid or unknown news item to edit.';
    redirect '/admin/manage_news';
  }

  template 'admin_manage_news_edit_form',
    {
      data =>
      {
        item => $item,
      },
      breadcrumbs =>
      [
        { name => 'Admin', link => '/admin' },
        { name => 'Manage News', link => '/admin/manage_news' },
        { name => 'Edit News Item', current => 1 },
      ],
    };
};


=head2 POST C</admin/manage_news/:item_id/update>

Route to update a news item record. Requires Admin access.

=cut

post '/admin/manage_news/:item_id/update' => require_role Admin => sub
{
  my $item_id    = route_parameters->get( 'item_id' );
  my $form_input = body_parameters->as_hashref;

  # TODO: Add server-side form validation.

  my $item = $SCHEMA->resultset( 'News' )->find( $item_id );

  if
  (
    not defined $item
    or
    ref( $item ) ne 'IMGames::Schema::Result::News'
  )
  {
    deferred error => 'Error: Cannot update news item - Invalid or unknown ID.';
    redirect '/admin/manage_news';
  }

  my $now = DateTime->now( time_zone => 'UTC' );
  $item->title( body_parameters->get( 'title' ) );
  $item->content( body_parameters->get( 'content' ) );
  $item->updated_on( $now );

  $item->update();

  deferred success => sprintf( 'Successfully updated news item &quot;<strong>%s</strong>&quot;.',
                                body_parameters->get( 'title' ) );
  redirect '/admin/manage_news';
};


=head2 POST C</admin/manage_news/:item_id/delete>

Route to delete a news item record. Requires Admin access.

=cut

get '/admin/manage_news/:item_id/delete' => require_role Admin => sub
{
  my $item_id    = route_parameters->get( 'item_id' );

  my $item = $SCHEMA->resultset( 'News' )->find( $item_id );

  if
  (
    not defined $item
    or
    ref( $item ) ne 'IMGames::Schema::Result::News'
  )
  {
    deferred error => 'Error: Cannot delete news item - Invalid or unknown ID.';
    redirect '/admin/manage_news';
  }

  my $title = $item->title;
  $item->delete;

  deferred success => sprintf( 'Successfully deleted news item &quot;<strong>%s</strong>&quot;.', $title );
  redirect '/admin/manage_news';
};


=head1 COPYRIGHT & LICENSE

Copyright 2016, Infinite Monkeys Games L<http://www.infinitemonkeysgames.com>
All rights reserved.

=cut

true;
