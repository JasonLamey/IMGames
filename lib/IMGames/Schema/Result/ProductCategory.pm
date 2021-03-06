package IMGames::Schema::Result::ProductCategory;

use Dancer2 appname => 'IMGames';

use strict;
use warnings;

# Third Party modules
use base 'DBIx::Class::Core';
use DateTime;
our $VERSION = '1.0';


=head1 NAME

IMGames::Schema::Result::ProductCategory


=head1 AUTHOR

Jason Lamey L<email:jasonlamey@gmail.com>


=head1 SYNOPSIS AND USAGE

This module represents the ProductCategory object in the web app, as well as the interface to the C<product_categories> table in the database.

=cut

__PACKAGE__->table( 'product_categories' );
__PACKAGE__->add_columns(
                          id =>
                            {
                              accessor          => 'product_category',
                              data_type         => 'integer',
                              size              => 20,
                              is_nullable       => 0,
                              is_auto_increment => 1,
                            },
                          category =>
                            {
                              data_type         => 'varchar',
                              size              => 255,
                              is_nullable       => 0,
                            },
                          shorthand =>
                            {
                              data_type         => 'varchar',
                              size              => 255,
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

__PACKAGE__->set_primary_key( 'id' );

__PACKAGE__->has_many( 'product_subcategories' => 'IMGames::Schema::Result::ProductSubcategory', 'category_id' );


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
