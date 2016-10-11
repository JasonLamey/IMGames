package IMGames;

# Dancer2 modules
use Dancer2;
use Dancer2::Session::Cookie;
use Dancer2::Plugin::Deferred;

use strict;
use warnings;

# IMGames modules
use IMGames::Schema;

# Third Party modules
use version; our $VERSION = qv( 'v0.1.0' );

use DBIx::Class::Schema;
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

$SCHEMA->storage->debug(1);


=head1 NAME

IMGames - The Infinite Monkeys Games website.


=head1 AUTHOR

Jason Lamey L<email:jasonlamey@gmail.com>


=head1 SYNOPSIS AND USAGE

Primary web application library, providing all routes and data calls.


=head1 ROUTES


=head2 GET C</>

Returns the site index.

=cut

get '/' => sub {
  template 'index';
};


=head2 POST C</signup>

Process sign-up information, and error-check.

=cut

post '/signup' => sub {
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
  my $new_user = $SCHEMA->resultset( 'User' )->new(
                                                    {
                                                      username   => body_parameters->get( 'username' ),
                                                      password   => body_parameters->get( 'password' ),
                                                      email      => body_parameters->get( 'email' ),
                                                      birthdate  => body_parameters->get( 'birthdate' ),
                                                      confirmed  => 0,
                                                      created_on => $now,
                                                    }
                                                  );
  $SCHEMA->txn_do(
                  sub
                  {
                    $new_user->insert;
                  }
  );

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

  info sprintf( 'Created new user >%s<, ID: >%s<, on %s', $new_user->username, $new_user->id, $now );

  # Email confirmation message to the user.

  deferred( success => sprintf("Thanks for signing up, %s!", body_parameters->get( 'username' ) ) );
  session 'user'      => body_parameters->get( 'username' );
  session 'logged_in' => 1;
  session->expires( $USER_SESSION_EXPIRE_TIME );
  redirect '/signed_up';
};


=head2 GET C</signed_up>

Successful sign-up page, with next-step instructions for account confirmation.

=cut

get '/signed_up' => sub {

  if ( ! session( 'logged_in' ) )
  {
    info 'An anonymous (not logged in) user attempted to access /signed_up.';
    deferred error => 'You need to be logged in to access that page.';
    redirect '/login';
  }

  my $username = session( 'user' );
  my $user = $SCHEMA->resultset( 'User' )->find( { username => $username } );

  if ( ref( $user ) ne 'IMGames::Schema::Result::User' )
  {
    warning sprintf( 'A user (%s) attempted to reach /signed_up, but the account could not be confirmed to exist.', session( 'user' ) );
    deferred error => 'You need to be logged in to access that page.';
    redirect '/login';
  }

  template 'signed_up_success', {
                                  data => {
                                            user => $user,
                                          },
                                };
};


=head2 GET C</login>

Login page for redirection, login errors, reattempt, etc.

=cut

get '/login' => sub {
  template 'login';
};


=head2 ANY C</logout>

Logout route, for killing user sessions, and redirecting to the index page.

=cut

any '/logout' => sub {
  app->destroy_session;
  template 'logout';
};


=head1 COPYRIGHT & LICENSE

Copyright 2016, Infinite Monkeys Games L<http://www.infinitemonkeysgames.com>
All rights reserved.

=cut

true;
