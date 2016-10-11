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
    deferred( error => "Errors have occurred in your sign up information." );
    redirect '/';
  }
  else
  {
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

    debug "About to set role";
    $new_user->set_roles( $unconfirmed_role );
    debug "Just set role";

    info sprintf( 'Created new user >%s<, ID: >%s<, on %s', $new_user->username, $new_user->id, $now );

    deferred( success => sprintf("Thanks for signing up, %s!", body_parameters->get( 'username' ) ) );
    session 'user'      => body_parameters->get( 'username' );
    session 'logged_in' => 1;
    session->expires( $USER_SESSION_EXPIRE_TIME );
    redirect '/signed_up';
  }
};


=head2 GET C</signed_up>

Successful sign-up page, with next-step instructions for account confirmation.

=cut

get '/signed_up' => sub {

  if ( ! session( 'logged_in' ) )
  {
    deferred error => 'You need to be logged in to access that page.';
    redirect '/login';
  }

  my $username = session( 'user' );
  my $user = $SCHEMA->resultset('User')->search( { username => $username } );

  if ( ref( $user ) ne 'IMGames::Schema::Result::User' )
  {
    deferred error => 'You need to be logged in to access that page.';
    redirect '/login';
  }

  template 'signed_up_success', {
                                  data => {
                                            user => $user,
                                          },
                                };
};


=head1 COPYRIGHT & LICENSE

Copyright 2016, Infinite Monkeys Games L<http://www.infinitemonkeysgames.com>
All rights reserved.

=cut

true;
