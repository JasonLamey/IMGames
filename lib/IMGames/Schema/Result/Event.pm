package IMGames::Schema::Result::Event;

use Dancer2 appname => 'IMGames';

use strict;
use warnings;

# Third Party modules
use base 'DBIx::Class::Core';
use DateTime;
our $VERSION = '1.0';


=head1 NAME

IMGames::Schema::Result::Event


=head1 AUTHOR

Jason Lamey L<email:jasonlamey@gmail.com>


=head1 SYNOPSIS AND USAGE

This module represents the calendar Event object in the web app, as well as the interface to the C<events> table in the database.

=cut

__PACKAGE__->table( 'events' );
__PACKAGE__->add_columns(
                          id =>
                            {
                              accessor          => 'event',
                              data_type         => 'integer',
                              size              => 20,
                              is_nullable       => 0,
                              is_auto_increment => 1,
                            },
                          name =>
                            {
                              data_type         => 'varchar',
                              size              => 255,
                              is_nullable       => 0,
                            },
                          start_date =>
                            {
                              data_type         => 'date',
                              is_nullable       => 0,
                            },
                          end_date =>
                            {
                              data_type         => 'date',
                              is_nullable       => 1,
                              default_value     => undef,
                            },
                          start_time =>
                            {
                              data_type         => 'time',
                              is_nullable       => 0,
                            },
                          end_time =>
                            {
                              data_type         => 'time',
                              is_nullable       => 0,
                            },
                          color =>
                            {
                              data_type         => 'char',
                              size              => 7,
                              is_nullable       => 1,
                              default_value     => undef,
                            },
                          url =>
                            {
                              data_type         => 'varchar',
                              size              => 255,
                              is_nullable       => 1,
                              default_value     => undef,
                            },
                          created_on =>
                            {
                              data_type         => 'DateTime',
                              is_nullable       => 0,
                              default_value     => DateTime->now( time_zone => 'UTC' )->datetime,
                            },
                          updated_on =>
                            {
                              data_type         => 'Timestamp',
                              is_nullable       => 1,
                              default_value     => undef,
                            },
                        );

__PACKAGE__->set_primary_key( 'id' );


=head1 METHODS


=head2 method_name()

This is a description of the method and what it does.

=over 4

=item Input: A description of what the method expects.

=item Output: A description of what the method returns.

=back

  $var = IMGames::PackageName->method_name();

=cut

sub method_name
{
}


=head1 COPYRIGHT & LICENSE

Copyright 2016, Infinite Monkeys Games L<http://www.infinitemonkeysgames.com>
All rights reserved.

=cut

1;
