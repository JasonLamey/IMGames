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
use version; our $VERSION = qv( 'v0.2.0' );

use DBIx::Class::Schema;
use DBICx::Sugar;
use Const::Fast;
use DateTime;
use Date::Calc;
use Data::FormValidator;
use Data::FormValidator::Constraints;
use Data::Dumper;
use HTML::Restrict;
use GD::Thumbnail;
use Clone;

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

=cut

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# SITE-SPECIFIC RELATED ROUTES BELOW HERE
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-


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

  my @news = $SCHEMA->resultset( 'News' )->search(
    {},
    {
      order_by => { -desc => [ 'created_on' ] },
      rows     => 3,
    }
  );

  template 'index',
    {
      data =>
      {
        featured_products => \@featured_products,
        products          => \@products,
        news              => \@news,
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
      subtitle => 'News',
    };
};


=head2 GET C</news/:item_id/:modal>

Route to display a particular news item in full. Displays in a modal, called by AJAX.

=cut

get '/news/:item_id/?:modal?' => sub
{
  my $item_id = route_parameters->get( 'item_id' );
  my $modal   = route_parameters->get( 'modal' );

  my $item = $SCHEMA->resultset( 'News' )->find( $item_id );
  $item->views( $item->views + 1 );
  $item->update();

  my $layout = ( $modal ) ? 'modal' : 'main';

  return template 'news_modal',
    {
      data =>
      {
        item => $item,
      },
    },
    { layout => $layout };
};


=head2 GET C</events>

Route to display the events calendar.

=cut

get '/events' => sub
{
  template 'events',
  {
    breadcrumbs =>
    [
      { name => 'Events Calendar', current => 1 },
    ],
    subtitle => 'Events Calendar',
  };
};


=head2 GET C</events/events.json>

Route to return a JSON formatted event list.

=cut

get '/events/events.json' => sub
{
  # Get a start date as the beginning of the month, three months prior to today.
  my $today = DateTime->now( time_zone => 'UTC' );
  my $start_date = DateTime->last_day_of_month( year => $today->year(), month => $today->subtract( months => 1 )->month )
                           ->add( days => 1 )
                           ->subtract( months => 3 );

  my @events = $SCHEMA->resultset( 'Event' )->search(
    { start_date => { '>=' => $start_date->ymd } },
    {
      order_by => [ 'start_date', 'start_time' ],
    }
  );

  my $events = { monthly => [] };
  foreach my $event ( @events )
  {
    push @{ $events->{'monthly'} },
      {
        id        => $event->id,
        name      => $event->name,
        startdate => $event->start_date,
        enddate   => $event->end_date,
        starttime => $event->start_time,
        endtime   => $event->end_time,
        color     => $event->color,
        url       => $event->url,
      };
  }

  return to_json( $events );
};


=head2 GET C</about>

Route to the About Us page.

=cut

get '/about' => sub
{
  template 'about',
  {
    breadcrumbs =>
    [
      { name => 'About IMG', current => 1 },
    ],
    subtitle => 'About Us',
  };
};


=head2 GET C</contact>

Route to the Contact Us page.

=cut

get '/contact' => sub
{
  template 'contact',
  {
    breadcrumbs =>
    [
      { name => 'Contact Us', current => 1 },
    ],
    subtitle => 'Contact Us',
  };
};


=head2 POST C</contact>

Route to save a contact us message in the DB, and e-mail out the message.

=cut

post '/contact' => sub
{
  my $form_input = body_parameters->as_hashref;

  my $form_results = $DATA_FORM_VALIDATOR->check( $form_input, 'contact_us_form' );

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

    deferred( error => sprintf( "Errors have occurred in your contact us information.<br>%s", join( '<br>', @errors ) ) );
    redirect '/';
  }

  my $now = DateTime->now( time_zone => 'UTC' );
  my $contact_msg = $SCHEMA->resultset( 'Contact' )->create(
    {
      name       => body_parameters->get( 'name' ),
      email      => body_parameters->get( 'email' ),
      reason     => body_parameters->get( 'reason' ),
      message    => body_parameters->get( 'message' ),
      created_on => $now,
    },
  );

  my $email_sent = IMGames::Mail::send_contact_us_notification(
      name       => body_parameters->get( 'name' ),
      email      => body_parameters->get( 'email' ),
      reason     => body_parameters->get( 'reason' ),
      message    => body_parameters->get( 'message' ),
      created_on => $now,
  );

  if ( ! $email_sent->{'success'} )
  {
    warn sprintf( 'Could not send notification to admins about Contact Us message created at %s: %s',
                  $now, $email_sent->{'error'} );
  }

  deferred success => sprintf( 'Thank you for your message, %s. Someone will get back to you soon.', body_parameters->get( 'name' ) );
  redirect '/contact';
};


=head2 GET C</community>

Route to the community section of the web site.

=cut

get '/community' => sub
{
  template 'community',
    {
      breadcrumbs =>
      [
        { name => 'Community', current => 1 },
      ],
      subtitle => 'Community',
    };
};

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# LOGIN/SIGN UP RELATED ROUTES BELOW HERE
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-


=head2 GET C</login_reset_password>

Route to reset a user's password.

=cut

get '/login_reset_password' => sub
{
  template 'reset_password_form',
    {
      breadcrumbs =>
      [
        { name => 'Login', link => '/login' },
        { name => 'Reset Password', current => 1 },
      ],
    };
};


=head2 POST C</reset_password>

Route for posting a username to the system to reset the password, and send out a reset code to the user.

=cut

post '/reset_password' => sub
{
  my $username = body_parameters->get( 'username' );

  my $sent = password_reset_send( username => $username, realm => $DPAE_REALM );

  if ( not defined $sent )
  {
    warn sprintf( 'Username >%s< found, but password reset email was not sent for some reason during resest_password.', $username );
  }
  elsif ( $sent == 0 )
  {
    warn sprintf( 'No record found for user >%s< during reset_password.', $username );
  }
  else
  {
    info sprintf( 'Successfully sent password_reset email to account >%s<.', $username );
  }

  deferred notify => 'A password reset email was sent to the email address associated with that account, if it exists.';
  my $logged = IMGames::Log->user_log
  (
    user        => 'Unknown',
    ip_address  => join( ' - ', request->remote_address, request->remote_host ),
    log_level   => 'Info',
    log_message => sprintf( 'Password Reset request for &quot;%s&quot;', $username ),
  );

  redirect '/login';
};


=head2 GET C</reset_my_password/:code>

Route to submit password reset request code and confirm the request.

=cut

get '/reset_my_password/?:code?' => sub
{
  my $code = route_parameters->get( 'code' ) // undef;

  if ( not defined $code )
  {
    return template '/reset_my_password_form',
      {
        breadcrumbs =>
        [
          { name => 'Reset My Password', current => 1 },
        ],
      };
  }

  my $username = user_password( code => $code );

  if ( not defined $username )
  {
    warning sprintf( 'Password Reset Code >%s< resulted in no user found.', $code );
    deferred error => 'Could not find your reset code. Password reset request was not fulfilled.';
    redirect '/reset_my_password';
  }

  my $new_temp_pw = IMGames::Util->generate_random_string( string_length => 8 );

  user_password( code => $code, new_password => $new_temp_pw );

  forward '/login',
    {
      username   => $username,
      password   => $new_temp_pw,
      return_url => '/user/change_password/' . $new_temp_pw,
    },
    { method => 'POST' };
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
                                                          user_id => $new_user->id,
                                                          role_id => $unconfirmed_role->id,
                                                        }
                                                       );
  $SCHEMA->txn_do(
                  sub
                  {
                    $user_role->insert;
                  }
  );

  info sprintf( 'Created new user >%s<, ID: >%s<, on %s', body_parameters->get( 'username' ), $new_user->id, $now );

  # Email confirmation message to the user.

  deferred( success => sprintf("Thanks for signing up, %s! You have been logged in.", body_parameters->get( 'username' ) ) );
  my $logged = IMGames::Log->user_log
  (
    user        => sprintf( '%s (ID:%s)', $new_user->username, $new_user->id ),
    ip_address  => join( ' - ', request->remote_address, request->remote_host ),
    log_level   => 'Info',
    log_message => 'New User Sign Up',
  );

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

  my $user = $SCHEMA->resultset( 'User' )->find( { username => logged_in_user->username } );

  if ( ref( $user ) ne 'IMGames::Schema::Result::User' )
  {
    warning sprintf( 'A user (%s) attempted to reach /signed_up, but the account could not be confirmed to exist.', session( 'user' ) );
    deferred error => 'You need to be logged in to access that page.';
    redirect '/login';
  }

  template 'signed_up_success',
    {
      data =>
      {
        user         => $user,
        from_address => config->{mailer_address},
      },
      subtitle => 'Thanks for Signing Up!',
    };
};


=head2 GET C</resend_confirmation>

Route for a User to request that their confirmation e-mail be resent to them.

=cut

get '/resend_confirmation' => sub
{
  # If the user is logged in, use that information and redirect.
  if ( defined logged_in_user )
  {
    my $sent = IMGames::Mail::send_welcome_email
    (
      undef,
      user  => { username => logged_in_user->username }, # Expects a hashref for the user. Only needs username
      email => logged_in_user->email,
    );
    if ( $sent->{'success'} )
    {
      deferred success => sprintf( 'We have resent the confirmation email to your account at &quot;<strong>%s</strong>&quot;.', logged_in_user->email );
      info sprintf( "Resent confirmation email at user's request to >%s<.", logged_in_user->email );
      my $logged = IMGames::Log->user_log
      (
        user        => sprintf( '%s (ID:%s)', logged_in_user->username, logged_in_user->id ),
        ip_address  => join( ' - ', request->remote_address, request->remote_host ),
        log_level   => 'Info',
        log_message => 'Resent confirmation email.',
      );
      redirect '/user';
    }
    else
    {
      deferred error => 'An error has occurred and we could not resend the confirmation email. Please try again in a few minutes.';
      error sprintf( "Error occurred when trying to resend the confirmation code to >%s<: %s", logged_in_user->email, $sent->{'error'} );
      my $logged = IMGames::Log->user_log
      (
        user        => sprintf( '%s (ID:%s)', logged_in_user->username, logged_in_user->id ),
        ip_address  => join( ' - ', request->remote_address, request->remote_host ),
        log_level   => 'Error',
        log_message => sprintf( 'Confirmation Email Resend failed to &gt;%s&lt;: %s', logged_in_user->email, $sent->{'error'} ),
      );
      redirect '/user';
    }
  }

  # If the user is not logged in, request an e-mail address and username.
  template 'resend_confirmation',
    {
      breadcrumbs =>
      [
        { name => 'Sign Up', link => '/login' },
        { name => 'Resend Confirmation Email', current => 1 },
      ],
    };
};


=head2 POST C</resend_confirmation>

Route to submit credentials for resending confirmation e-mails.

=cut

post '/resend_confirmation' => sub
{
  my $username = body_parameters->get( 'username ' ) // undef;
  my $email    = body_parameters->get( 'email ' )    // undef;

  if
  (
    not defined $username
    or
    not defined $email
  )
  {
    deferred error => 'Both your username and your email address are required.';
    redirect '/resend_confirmation';
  }

  my $user = $SCHEMA->resultset( 'User' )->find
  (
    {
      username => $username,
      email    => $email,
    }
  );

  if
  (
    not defined $user
    or
    ref( $user ) ne 'IMGames::Schema::Result::User'
  )
  {
    error sprintf( 'Invalid user credentials on resend confirmation: user - >%s< / email - >%s<', $username, $email );
    deferred error => 'An error occurred in trying to locate your account.<br>Some or all of the information you have provided is incorrect.';
    my $logged = IMGames::Log->user_log
    (
      user        => 'Unknown',
      ip_address  => join( ' - ', request->remote_address, request->remote_host ),
      log_level   => 'Error',
      log_message => sprintf( 'Resend Confirmation Failed: Invalid credentials - &gt;%s&lt; &gt;%s&lt;', $username, $email ),
    );
    redirect '/resend_confirmation';
  }

  my $sent = IMGames::Mail::send_welcome_email
  (
    user  => $user->username,
    email => $user->email,
  );
  if ( $sent->{'success'} )
  {
    deferred success => sprintf( 'We have resent the confirmation email to your account at &quot;<strong>%s</strong>%quot;.', $user->email );
    info sprintf( "Resent confirmation email at user's request to >%s<.", $user->email );
    my $logged = IMGames::Log->user_log
    (
      user        => 'Unknown',
      ip_address  => join( ' - ', request->remote_address, request->remote_host ),
      log_level   => 'Info',
      log_message => sprintf( 'Confirmation Email Resent: &gt;%s&lt;', $user->email ),
    );
    redirect '/';
  }
  else
  {
    deferred error => 'An error has occurred and we could not resend the confirmation email. Please try again in a few minutes.';
    error sprintf( "Error occurred when trying to resend the confirmation code to >%s<: %s", $user->email, $sent->{'error'} );
    my $logged = IMGames::Log->user_log
    (
      user        => 'Unknown',
      ip_address  => join( ' - ', request->remote_address, request->remote_host ),
      log_level   => 'Error',
      log_message => sprintf( 'Resend Confirmation Failed: Email send failed - &gt;%s&lt;: &gt;%s&lt;', $user->email, $sent->{'error'} ),
    );
    redirect '/resend_confirmation';
  }
};


=head2 GET C</login>

Login page for redirection, login errors, reattempt, etc.

=cut

get '/login/?:modal?' => sub
{
  my $layout = ( route_parameters->get( 'modal' ) ) ? 'modal' : 'main';
  my $return_url = query_parameters->get( 'return_url' );

  if ( defined logged_in_user )
  {
    redirect '/user';
  }

  template 'login',
    {
      data =>
      {
        return_url => $return_url
      },
      subtitle => 'Login',
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
    my $logged = IMGames::Log->user_log
    (
      user        => 'Unknown',
      ip_address  => join( ' - ', request->remote_address, request->remote_host ),
      log_level   => 'Warning',
      log_message => sprintf( 'Invalid login attempt: UN: &gt;%s&lt;, Password: &gt;%s&lt;',
                               body_parameters->get( 'username' ), body_parameters->get( 'password' ) ),
    );
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
  my $logged = IMGames::Log->user_log
  (
    user        => sprintf( '%s (ID:%s)', logged_in_user->username, logged_in_user->id ),
    ip_address  => join( ' - ', request->remote_address, request->remote_host ),
    log_level   => 'Info',
    log_message => 'Successful login.',
  );

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
  info sprintf( 'User >%s< successfully confirmed.', $user->username );
  my $logged = IMGames::Log->user_log
  (
    user        => sprintf( '%s (ID:%s)', $user->username, $user->id ),
    ip_address  => join( ' - ', request->remote_address, request->remote_host ),
    log_level   => 'Info',
    log_message => 'Successful account confirmation.',
  );

  template 'account_confirmation',
    {
      data =>
      {
        success => 1,
        user    => $user,
      },
      subtitle => 'Account Confirmation',
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


#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# PRODUCT RELATED ROUTES BELOW HERE
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-


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

  template 'product_listing',
    {
      data =>
      {
        categories            => \@categories,
        num_featured_products => $num_featured_products,
        featured_products     => \@featured_products,
        display_mode          => $display_mode,
      },
      breadcrumbs => \@breadcrumbs,
      subtitle => 'Products',
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
  $product->views( $product->views + 1 );
  $product->update;

  my $delta = '';
  if ( $product->status eq 'Out of Stock' )
  {
    my $now = DateTime->now( time_zone => 'UTC' );
    my ( $now_week, $now_year ) = Date::Calc::Week_of_Year( $now->year, $now->month, $now->day );
    my ( $bis_week, $bis_year ) = Date::Calc::Week_of_Year( split( '-', $product->back_in_stock_date ) );

    if ( $now_year == $bis_year)
    {
      $delta = ( $bis_week - $now_week );
    }
    else
    {
      $delta = ( ( ( Date::Calc::Weeks_in_Year( $now->year ) ) - $now_week ) + $bis_week );
    }
  }

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

  template 'product',
    {
      data =>
      {
        product              => $product,
        review_count         => ( $product->reviews->count // 0 ),
        average_review_score => $product->average_rating_score(),
        related_products     => \@related_products,
        delta                => $delta,
      },
      breadcrumbs => \@breadcrumbs,
      subtitle => $product->name,
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


=head2 POST C</product/:product_id/notify>

Route to add an email address to a product notification list.

=cut

post '/product/:product_id/notify' => sub
{
  my $product_id = route_parameters->get( 'product_id' );
  my $email      = body_parameters->get( 'email' );

  my $now = DateTime->now( time_zone => 'UTC' )->datetime;
  my $new_notify = $SCHEMA->resultset( 'ProductNotify' )->create
  (
    {
      product_id => $product_id,
      email      => $email,
      created_on => $now,
    }
  );

  if
  (
    ! defined $new_notify
    or
    ref( $new_notify ) ne 'IMGames::Schema::Result::ProductNotify'
  )
  {
    deferred error => 'An error occurred. We could not add your email address to the registry.<br>Please try again in a few minutes.';
  }
  else
  {
    deferred success => 'Your email address has been saved.<br>You will be notified when this product becomes available.';
  }

  redirect '/product/' . $product_id;
};


#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# LOGGED IN USER ROUTES BELOW HERE
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-


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
      subtitle => 'Your Dashboard',
    };
};


=head2 GET C</user/account>

Route to user account edit page. Requires logged in user.

=cut

get '/user/account' => require_login sub
{
  my $user = $SCHEMA->resultset( 'User' )->find( logged_in_user->id );

  if
  (
    not defined $user
    or
    ref( $user ) ne 'IMGames::Schema::Result::User'
  )
  {
    deferred error => 'ERROR: Could not look up User data for your account.';
    redirect '/user';
  }

  template 'user_account.tt',
  {
    data =>
    {
      user => $user,
    },
    breadcrumbs =>
    [
      { name => 'User Dashboard', link => '/user' },
      { name => 'Account', current => 1 },
    ],
    subtitle => 'Your Account',
  };
};


=head2 POST C</user/account/update>

Route to update user account info. Requires user be logged in. Birthday and username are not editable.

=cut

post '/user/account/update' => require_login sub
{
  my $user = $SCHEMA->resultset( 'User' )->find( logged_in_user->id );

  if
  (
    not defined $user
    or
    ref( $user ) ne 'IMGames::Schema::Result::User'
  )
  {
    deferred error => 'ERROR: Could not look up User data for your account.';
    redirect '/user';
  }

  my $orig_user = Clone::clone( $user );

  my $now = DateTime->now( time_zone => 'UTC' );
  $user->first_name( body_parameters->get( 'first_name' ) );
  $user->last_name( body_parameters->get( 'last_name' ) );
  $user->email( body_parameters->get( 'email' ) );
  $user->updated_on( $now );

  $user->update();

  info sprintf( 'User %s successfully logged in.', body_parameters->get( 'username' ) );
  deferred success => 'Your account has been updated!';

  my $old =
  {
    first_name => $orig_user->first_name,
    last_name  => $orig_user->last_name,
    email      => $orig_user->email,
  };

  my $new =
  {
    first_name => body_parameters->get( 'first_name' ),
    last_name  => body_parameters->get( 'last_name' ),
    email      => body_parameters->get( 'email' ),
  };

  my $diffs = IMGames::Log->find_changes_in_data( old_data => $old, new_data => $new );

  my $logged = IMGames::Log->user_log
  (
    user        => sprintf( '%s (ID:%s)', logged_in_user->username, logged_in_user->id ),
    ip_address  => join( ' - ', request->remote_address, request->remote_host ),
    log_level   => 'Info',
    log_message => sprintf( 'Successful account update: %s.', join( ', ', @{ $diffs } ) ),
  );

  redirect '/user/account';
};


=head2 GET C</user/change_password/:temp_pw>

Route for user to change their password. Requires user to be logged in.

=cut

get '/user/change_password/?:temp_pw?' => require_login sub
{
  my $temp_pw = route_parameters->get( 'temp_pw' ) // undef;

  template 'change_password',
    {
      data =>
      {
        temp_pw => $temp_pw,
      },
      breadcrumbs =>
      [
        { name => 'User Dashboard', link => '/user' },
        { name => 'Change Password', current => 1 },
      ],
    };
};


=head2 POST C</user/change_password/update>

Route for checking and saving a new password. Requires a logged in user.

=cut

post '/user/change_password/update' => require_login sub
{
  my $logged_in_user = logged_in_user;

  if
  (
    ! defined user_password(
        username => $logged_in_user->username,
        password => body_parameters->get( 'current_password' ),
        realm    => $DPAE_REALM,
    )
  )
  {
    deferred error => 'The Current Password you supplied was incorrect.';
    redirect '/user/change_password';
  }

  user_password
  (
    username     => $logged_in_user->username,
    realm        => $DPAE_REALM,
    password     => body_parameters->get( 'current_password' ),
    new_password => body_parameters->get( 'new_password' ),
  );

  info sprintf( 'User >%s< changed their password. IP: %s',
                $logged_in_user->username,
                join( ' - ', request->remote_address, request->remote_host ) );

  deferred success => 'Your password has been changed.';

  my $logged = IMGames::Log->user_log
  (
    user        => sprintf( '%s (ID:%s)', logged_in_user->username, logged_in_user->id ),
    ip_address  => join( ' - ', request->remote_address, request->remote_host ),
    log_level   => 'Info',
    log_message => 'User changed their password.',
  );

  redirect '/user/change_password';
};


=head2 GET C</user/profile>

Route to view and edit a user's profile. Requires being logged in.

=cut

get '/user/profile' => require_login sub
{
  template 'user_profile_edit_form',
    {
      breadcrumbs =>
      [
        { name => 'User Dashboard', link => '/user' },
        { name => 'Your Profile', current => 1 },
      ],
    };
};


=head2 GET C</user/wishlist>

Route to view and edit a user's profile. Requires being logged in.

=cut

get '/user/wishlist' => require_login sub
{
  template 'user_wishlist',
    {
      breadcrumbs =>
      [
        { name => 'User Dashboard', link => '/user' },
        { name => 'Your Wishlist', current => 1 },
      ],
    };
};


=head2 GET C</user/orders>

Route to view a user's order history. Requires being logged in.

=cut

get '/user/orders' => require_login sub
{
  template 'user_order_history',
    {
      breadcrumbs =>
      [
        { name => 'User Dashboard', link => '/user' },
        { name => 'Your Order History', current => 1 },
      ],
    };
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
      subtitle => 'Admin Dashboard',
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
        subtitle => 'Add Product',
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
      status                 => body_parameters->get( 'status' ),
      back_in_stock_date     => ( body_parameters->get( 'back_in_stock_date' ) ne '' ) ? body_parameters->get( 'back_in_stock_date' ) : undef,
      sku                    => body_parameters->get( 'sku' ),
      intro                  => body_parameters->get( 'intro' ),
      description            => body_parameters->get( 'description' ),
      created_on             => $now,
    }
  );

  my $fields = body_parameters->as_hashref;
  my @fields = ();
  foreach my $key ( sort keys %{ $fields } )
  {
    push @fields, sprintf( '%s: %s', $key, $fields->{$key} );
  }

  info sprintf( 'Created new product >%s<, ID: >%s<, on %s', body_parameters->get( 'name' ), $new_product->id, $now );

  deferred success => sprintf( 'Successfully created Product &quot;<strong>%s</strong>&quot;!', body_parameters->get( 'name' ) );
  my $logged = IMGames::Log->admin_log
  (
    admin       => sprintf( '%s (ID:%s)', logged_in_user->username, logged_in_user->id ),
    ip_address  => join( ' - ', request->remote_address, request->remote_host ),
    log_level   => 'Info',
    log_message => sprintf( 'Created new product:<br>%s', join( '<br>', @fields ) ),
  );

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
        subtitle => 'Edit Product',
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

  my $orig_product = Clone::clone( $product );

  my $now = DateTime->now( time_zone => 'UTC' );
  $product->name( body_parameters->get( 'name' ) );
  $product->product_type_id( body_parameters->get( 'product_type_id' ) );
  $product->product_subcategory_id( body_parameters->get( 'product_subcategory_id' ) );
  $product->base_price( body_parameters->get( 'base_price' ) );
  $product->status( body_parameters->get( 'status' ) ),
  $product->back_in_stock_date( ( body_parameters->get( 'back_in_stock_date' ) ne '' ) ? body_parameters->get( 'back_in_stock_date' ) : undef ),
  $product->sku( body_parameters->get( 'sku' ) );
  $product->intro( body_parameters->get( 'intro' ) );
  $product->description( body_parameters->get( 'description' ) );
  $product->updated_on( $now );

  $product->update;

  deferred success => sprintf( 'Successfully updated Product &quot;<strong>%s</strong>&quot;!', $product->name );
  info sprintf( 'Product >%s< updated by %s on %s.', $product->name, logged_in_user->username, $now );

  my $old =
  {
    name                   => $orig_product->name,
    product_type_id        => $orig_product->product_type_id,
    product_subcategory_id => $orig_product->product_subcategory_id,
    base_price             => $orig_product->base_price,
    status                 => $orig_product->status,
    back_in_stock_date     => $orig_product->back_in_stock_date,
    sku                    => $orig_product->sku,
    intro                  => $orig_product->intro,
    description            => $orig_product->description,
  };
  my $new =
  {
    name                   => body_parameters->get( 'name' ),
    product_type_id        => body_parameters->get( 'product_type_id' ),
    product_subcategory_id => body_parameters->get( 'product_subcategory_id' ),
    base_price             => body_parameters->get( 'base_price' ),
    status                 => body_parameters->get( 'status' ),
    back_in_stock_date     => body_parameters->get( 'back_in_stock_date' ),
    sku                    => body_parameters->get( 'sku' ),
    intro                  => body_parameters->get( 'intro' ),
    description            => body_parameters->get( 'description' ),
  };

  my $diffs = IMGames::Log->find_changes_in_data( old_data => $old, new_data => $new );

  my $logged = IMGames::Log->admin_log
  (
    admin       => sprintf( '%s (ID:%s)', logged_in_user->username, logged_in_user->id ),
    ip_address  => join( ' - ', request->remote_address, request->remote_host ),
    log_level   => 'Info',
    log_message => sprintf( 'Product modified:<br>%s', join( ', ', @{ $diffs } ) ),
  );

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
  my $logged = IMGames::Log->admin_log
  (
    admin       => sprintf( '%s (ID:%s)', logged_in_user->username, logged_in_user->id ),
    ip_address  => join( ' - ', request->remote_address, request->remote_host ),
    log_level   => 'Info',
    log_message => sprintf( 'Product &quot;%s&quot; deleted', $product_name ),
  );
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
  $new_highlight->updated_on( $now );
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
        subtitle => 'Manage Product Categories and Subcategories',
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
  my $logged = IMGames::Log->admin_log
  (
    admin       => sprintf( '%s (ID:%s)', logged_in_user->username, logged_in_user->id ),
    ip_address  => join( ' - ', request->remote_address, request->remote_host ),
    log_level   => 'Info',
    log_message => sprintf( 'Product Category &quot;%s&quot; created', body_parameters->get( 'category' ) ),
  );

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
  my $logged = IMGames::Log->admin_log
  (
    admin       => sprintf( '%s (ID:%s)', logged_in_user->username, logged_in_user->id ),
    ip_address  => join( ' - ', request->remote_address, request->remote_host ),
    log_level   => 'Info',
    log_message => sprintf( 'Product Category &quot;%s&quot; deleted', $category ),
  );

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
      subtitle => 'Edit Product Category',
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

  my $orig_product_category = Clone::clone( $product_category );

  my $now = DateTime->now( time_zone => 'UTC' );
  $product_category->category( body_parameters->get( 'category' ) );
  $product_category->shorthand( body_parameters->get( 'shorthand' ) );
  $product_category->updated_on( $now );

  $product_category->update;

  deferred success => sprintf( 'Successfully updated product category &quot;<strong>%s</strong>&quot;.', $product_category->category );

  info sprintf( 'Updated product category >%s<, ID: >%s<, on %s', $product_category->category, $product_category_id, $now );

  my $new =
  {
    category  => body_parameters->get( 'category' ),
    shorthand => body_parameters->get( 'shorthand' )
  };
  my $old =
  {
    category  => $orig_product_category->category,
    shorthand => $orig_product_category->shorthand
  };

  my $diffs = IMGames::Log->find_changes_in_data( old_data => $old, new_data => $new );

  my $logged = IMGames::Log->admin_log
  (
    admin       => sprintf( '%s (ID:%s)', logged_in_user->username, logged_in_user->id ),
    ip_address  => join( ' - ', request->remote_address, request->remote_host ),
    log_level   => 'Info',
    log_message => sprintf( 'Product Category updated: %s', join( ', ', @{ $diffs } ) ),
  );

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

  my $subcategory_exists  = $SCHEMA->resultset( 'ProductSubcategory' )->count
  (
    {
      subcategory  => body_parameters->get( 'subcategory' ),
      category_id  => body_parameters->get( 'category_id' )
    }
  );

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

  my $logged = IMGames::Log->admin_log
  (
    admin       => sprintf( '%s (ID:%s)', logged_in_user->username, logged_in_user->id ),
    ip_address  => join( ' - ', request->remote_address, request->remote_host ),
    log_level   => 'Info',
    log_message => sprintf( 'Product Subcategory &quot;%s&quot; (%s) created', body_parameters->get( 'subcategory' ), $new_product_subcategory->id ),
  );

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
  my $logged = IMGames::Log->admin_log
  (
    admin       => sprintf( '%s (ID:%s)', logged_in_user->username, logged_in_user->id ),
    ip_address  => join( ' - ', request->remote_address, request->remote_host ),
    log_level   => 'Info',
    log_message => sprintf( 'Product Subcategory &quot;%s&quot; (%s) deleted.', $subcategory, $product_subcategory_id ),
  );

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
      subtitle => 'Manage Product Subcategories',
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
  my $orig_product_subcategory = Clone::clone( $product_subcategory );

  my $now = DateTime->now( time_zone => 'UTC' );
  $product_subcategory->subcategory( body_parameters->get( 'subcategory' ) );
  $product_subcategory->category_id( body_parameters->get( 'category_id' ) );
  $product_subcategory->updated_on( $now );

  $product_subcategory->update;

  deferred success => sprintf( 'Successfully updated product subcategory &quot;<strong>%s</strong>&quot;.', $product_subcategory->subcategory );

  info sprintf( 'Updated product category >%s<, ID: >%s<, on %s', $product_subcategory->subcategory, $product_subcategory_id, $now );

  my $new =
  {
    subcategory => body_parameters->get( 'subcategory' ),
    category_id => body_parameters->get( 'category_id' )
  };
  my $old =
  {
    subcategory => $orig_product_subcategory->subcategory,
    category_id => $orig_product_subcategory->category_id
  };

  my $diffs = IMGames::Log->find_changes_in_data( old_data => $old, new_data => $new );

  my $logged = IMGames::Log->admin_log
  (
    admin       => sprintf( '%s (ID:%s)', logged_in_user->username, logged_in_user->id ),
    ip_address  => join( ' - ', request->remote_address, request->remote_host ),
    log_level   => 'Info',
    log_message => sprintf( 'Product Subcategory updated: %s', join( ', ', @{ $diffs } ) ),
  );

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
    subtitle => 'Manage Featured Products',
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
      subtitle => 'Manage News',
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
      subtitle => 'Add News',
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
      user_id    => logged_in_user->id,
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
      subtitle => 'Edit News',
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


=head2 GET C</admin/manage_events>

Route to manage calendar events. Requires Admin access.

=cut

get '/admin/manage_events' => require_role Admin => sub
{
  my @events = $SCHEMA->resultset( 'Event' )->search(
    {},
    {
      order_by => { -desc => [ 'start_date' ] },
    }
  );

  template 'admin_manage_events',
    {
      data =>
      {
        events => \@events,
      },
      breadcrumbs =>
      [
        { name => 'Admin', link => '/admin' },
        { name => 'Manage Events', current => 1 },
      ],
      subtitle => 'Manage Events',
    };
};


=head2 GET C</admin/manage_events/add>

Route to get the form for creating a new calendar event. Admin access required.

=cut

get '/admin/manage_events/add' => require_role Admin => sub
{
  template 'admin_manage_events_add_form',
    {
      breadcrumbs =>
      [
        { name => 'Admin', link => '/admin' },
        { name => 'Manage Events', link => '/admin/manage_events' },
        { name => 'Add New Calendar Event', current => 1 },
      ],
      subtitle => 'Add Event',
    };
};


=head2 POST C</admin/manage_events/create>

Route to save new event. Requires Admin access.

=cut

post '/admin/manage_events/create' => require_role Admin => sub
{
  my $form_input = body_parameters->as_hashref;

  # TODO: SERVER-SIDE VALIDATION HERE.

  my $now = DateTime->now( time_zone => 'UTC' );
  my $new_event = $SCHEMA->resultset( 'Event' )->create
  (
    {
      name       => body_parameters->get( 'name' ),
      start_date => body_parameters->get( 'start_date' ),
      end_date   => ( body_parameters->get( 'end_date' ) ) ? body_parameters->get( 'end_date' ) : body_parameters->get( 'start_date' ),
      start_time => body_parameters->get( 'start_time' ),
      end_time   => body_parameters->get( 'end_time' ),
      color      => body_parameters->get( 'color' ),
      url        => body_parameters->get( 'url' ),
      created_on => $now,
    }
  );

  deferred success => sprintf( 'Calendar Event &quot;<strong>%s</strong>&quot; was successfully created.', body_parameters->get( 'name' ) );
  redirect '/admin/manage_events';
};


=head2 GET C</admin/manage_events/:event_id/edit>

Route to edit the content of a calendar event. Requires Admin.

=cut

get '/admin/manage_events/:event_id/edit' => require_role Admin => sub
{
  my $event_id = route_parameters->get( 'event_id' );

  my $event = $SCHEMA->resultset( 'Event' )->find( $event_id );

  if
  (
    ! defined $event
    or
    ref( $event ) ne 'IMGames::Schema::Result::Event'
  )
  {
    deferred error => 'Could not find the requested calendar event. Invalid or undefined event ID.';
    redirect '/admin/manage_events';
  }

  template 'admin_manage_events_edit_form',
    {
      data =>
      {
        event => $event,
      },
      breadcrumbs =>
      [
        { name => 'Admin', link => '/admin' },
        { name => 'Manage Events', link => '/admin/manage_events' },
        { name => 'Edit Calendar Event', current => 1 },
      ],
    };
};


=head2 POST C</admin/manage_events/:event_id/update>

Route to save changes made to a calendar Event. Admin access required.

=cut

post '/admin/manage_events/:event_id/update' => require_role Admin => sub
{
  my $form_input = body_parameters->as_hashref;

  # TODO: SERVER SIDE VALIDATION HERE

  my $event_id = route_parameters->get( 'event_id' );

  my $event = $SCHEMA->resultset( 'Event' )->find( $event_id );

  if
  (
    ! defined $event
    or
    ref( $event ) ne 'IMGames::Schema::Result::Event'
  )
  {
    deferred error => 'Could not find the requested calendar event. Invalid or undefined event ID.';
    redirect '/admin/manage_events';
  }

  my $now = DateTime->now( time_zone => 'UTC' );
  $event->name( body_parameters->get( 'name' ) );
  $event->start_date( body_parameters->get( 'start_date' ) );
  $event->end_date( ( body_parameters->get( 'end_date' ) ) ? body_parameters->get( 'end_date' ) : body_parameters->get( 'start_date' ) );
  $event->start_time( body_parameters->get( 'start_time' ) );
  $event->end_time( body_parameters->get( 'end_time' ) );
  $event->color( body_parameters->get( 'color' ) );
  $event->url( body_parameters->get( 'url' ) );
  $event->updated_on( $now );
  $event->update;

  deferred success => sprintf( 'Calendar Event &quot;<strong>%s</strong>&quot; has been successfully updated.', body_parameters->get( 'name' ) );
  redirect '/admin/manage_events';

};


=head2 GET C</admin/manage_events/:event_id/delete>

Route to delete a calendar event. Admin access required.

=cut

get '/admin/manage_events/:event_id/delete' => require_role Admin => sub
{
  my $event_id = route_parameters->get( 'event_id' );

  my $event = $SCHEMA->resultset( 'Event' )->find( $event_id );

  if
  (
    ! defined $event
    or
    ref( $event ) ne 'IMGames::Schema::Result::Event'
  )
  {
    deferred error => 'Could not find the requested calendar event. Invalid or undefined event ID.';
    redirect '/admin/manage_events';
  }

  my $event_name = $event->name;
  $event->delete;

  deferred success => sprintf( 'Calendar Event &quot;<strong>%s</strong>&quot; has been successfully deleted.', $event_name );

  redirect '/admin/manage_events';
};


=head2 GET C</admin/admin_logs>

Route to view admin logs.

=cut

get '/admin/admin_logs' => require_role Admin => sub
{
  my @logs = $SCHEMA->resultset( 'AdminLog' )->search(
    undef,
    {
      order_by => [ 'created_on' ],
    },
  );

  template 'admin_logs',
    {
      data =>
      {
        logs => \@logs,
      },
      breadcrumbs =>
      [
        { name => 'Admin', link => '/admin' },
        { name => 'Admin Logs', current => 1 },
      ],
    };
};


=head2 GET C</admin/user_logs>

Route to view user logs.

=cut

get '/admin/user_logs' => require_role Admin => sub
{
  my @logs = $SCHEMA->resultset( 'UserLog' )->search(
    undef,
    {
      order_by => [ 'created_on' ],
    },
  );

  template 'user_logs',
    {
      data =>
      {
        logs => \@logs,
      },
      breadcrumbs =>
      [
        { name => 'Admin', link => '/admin' },
        { name => 'User Logs', current => 1 },
      ],
    };
};


=head1 COPYRIGHT & LICENSE

Copyright 2016, Infinite Monkeys Games L<http://www.infinitemonkeysgames.com>
All rights reserved.

=cut

true;
