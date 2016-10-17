package IMGames::Schema::Result::Product;

use Dancer2 appname => 'IMGames';

use strict;
use warnings;

# Third Party modules
use base 'DBIx::Class::Core';
use DateTime;
our $VERSION = '1.0';


=head1 NAME

IMGames::Schema::Result::Product


=head1 AUTHOR

Jason Lamey L<email:jasonlamey@gmail.com>


=head1 SYNOPSIS AND USAGE

This module represents the Product object in the web app, as well as the interface to the C<products> table in the database.

=cut

__PACKAGE__->table( 'products' );
__PACKAGE__->add_columns(
                          id =>
                            {
                              accessor          => 'product',
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
                          product_subcategory_id =>
                            {
                              data_type         => 'integer',
                              size              => 20,
                              is_nullable       => 0,
                            },
                          intro =>
                            {
                              data_type         => 'text',
                              is_nullable       => 0,
                            },
                          description =>
                            {
                              data_type         => 'text',
                              is_nullable       => 0,
                            },
                          product_type_id =>
                            {
                              data_type         => 'integer',
                              size              => 20,
                              is_nullable       => 0,
                            },
                          base_price =>
                            {
                              data_type         => 'decimal',
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

__PACKAGE__->belongs_to( 'product_subcategory' => 'IMGames::Schema::Result::ProductSubcategory', 'product_subcategory_id' );
__PACKAGE__->belongs_to( 'product_type' => 'IMGames::Schema::Result::ProductType', 'product_type_id' );


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
