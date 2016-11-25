package IMGames::Schema::Result::AdminLog;

use Dancer2 appname => 'IMGames';
use base 'DBIx::Class::Core';

use strict;
use warnings;

use version; our $VERSION = qv( "v0.1.0" );


=head1 NAME

IMGames::Schema::Result::AdminLog


=head1 DESCRIPTION AND USAGE

Database object representing AdminLog entries within the web app.

=cut

__PACKAGE__->table( 'admin_logs' );
__PACKAGE__->add_columns(
                            id =>
                                {
                                    accessor          => 'admin_log',
                                    data_type         => 'integer',
                                    size              => 20,
                                    is_nullable       => 0,
                                    is_auto_increment => 1,
                                },
                            admin =>
                                {
                                    data_type         => 'varchar',
                                    size              => 20,
                                    is_nullable       => 0,
                                },
                            ip_address =>
                                {
                                    data_type         => 'varchar',
                                    size              => 255,
                                    is_nullable       => 0,
                                },
                            log_level =>
                                {
                                    data_type         => 'enum',
                                    default_value     => 'Info',
                                    is_nullable       => 0,
                                },
                            log_message =>
                                {
                                    data_type         => 'text',
                                    is_nullable       => 0,
                                },
                            created_on =>
                                {
                                    data_type         => 'DateTime',
                                    is_nullable       => 0,
                                    default_value     => DateTime->now( time_zone => 'UTC' )->datetime,
                                },
                        );

__PACKAGE__->set_primary_key( 'id' );

# IMGames::Admin->has_many( somethings => 'Object::Package' );


=head1 AUTHOR

Jason Lamey E<lt>jasonlamey@gmail.comE<gt>


=head1 COPYRIGHT AND LICENSE

Copyright 2016 by Infinite Monkeys Games

This library is for use by IMGames. It is not intended for redistribution
or use by other parties without express written permission.

=cut

1;
