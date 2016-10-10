package IMGames::Schema::Result::UserRole;

use Dancer2 appname => 'IMGames';

use strict;
use warnings;

# IMGames modules
use IMGames::Schema::Result::UserRole;

# Third Party modules
use version; our $VERSION = qv( 'v0.1.0' );

const my $SCHEMA                    => IMGames::Schema->get_schema_connection();


=head1 NAME

IMGames::PackageName


=head1 AUTHOR

Jason Lamey L<email:jasonlamey@gmail.com>


=head1 SYNOPSIS AND USAGE

This library represents the User/Role relationships.

=cut

__PACKAGE__->table( 'user_roles' );
__PACKAGE__->add_columns(
                          user_id =>
                            {
                              data_type         => 'integer',
                              size              => 20,
                              is_nullable       => 0,
                            },
                          role_id =>
                            {
                              data_type         => 'integer',
                              size              => 20,
                              is_nullable       => 0,
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

__PACKAGE__->set_primary_key( 'user_id', 'role_id' );

#__PACKAGE__->has_many( 'bookmarks', 'IMGames::Schema::Result::UserBookmark', 'user_id' );
__PACKAGE__->belongs_to( 'user' => 'IMGames::Schema::Result::User', 'user_id' );
__PACKAGE__->belongs_to( 'role' => 'IMGames::Schema::Result::Role', 'role_id' );


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
