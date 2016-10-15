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

#debug sprintf( 'DBICx::Sugar %s configured.', DBICx::Sugar::get_config ? 'IS' : 'IS NOT' );
#debug Data::Dumper::Dumper( DBICx::Sugar::get_config );

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

  my $logged_in_user = logged_in_user;
  my $user = $SCHEMA->resultset( 'User' )->find( { username => $logged_in_user->{'username'} } );

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

get '/login' => sub
{
  template 'login';
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


=head1 COPYRIGHT & LICENSE

Copyright 2016, Infinite Monkeys Games L<http://www.infinitemonkeysgames.com>
All rights reserved.

=cut

true;
