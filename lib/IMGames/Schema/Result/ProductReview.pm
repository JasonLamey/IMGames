package IMGames::Schema::Result::ProductReview;

use Dancer2 appname => 'IMGames';

use strict;
use warnings;

# Third Party modules
use base 'DBIx::Class::Core';
use DateTime;
our $VERSION = '1.0';


=head1 NAME

IMGames::Schema::Result::ProductReview


=head1 AUTHOR

Jason Lamey L<email:jasonlamey@gmail.com>


=head1 SYNOPSIS AND USAGE

This module represents the Product Review object in the web app, as well as the interface to the C<product_reviews> table in the database.

=cut

__PACKAGE__->table( 'product_reviews' );
__PACKAGE__->add_columns(
                          id =>
                            {
                              accessor          => 'product_review',
                              data_type         => 'integer',
                              size              => 20,
                              is_nullable       => 0,
                              is_auto_increment => 1,
                            },
                          product_id =>
                            {
                              data_type         => 'integer',
                              size              => 20,
                              is_nullable       => 0,
                            },
                          user_id =>
                            {
                              data_type         => 'integer',
                              size              => 20,
                              is_nullable       => 0,
                            },
                          title =>
                            {
                              data_type         => 'varchar',
                              size              => 255,
                              is_nullable       => 0,
                            },
                          content =>
                            {
                              data_type         => 'text',
                              is_nullable       => 0,
                            },
                          rating =>
                            {
                              data_type         => 'integer',
                              size              => 1,
                              is_nullable       => 0,
                            },
                          timestamp =>
                            {
                              data_type         => 'DateTime',
                              is_nullable       => 0,
                              default_value     => DateTime->now( time_zone => 'UTC' )->datetime,
                            },
                        );

__PACKAGE__->set_primary_key( 'id' );

__PACKAGE__->belongs_to( 'product' => 'IMGames::Schema::Result::Product', 'product_id' );
__PACKAGE__->belongs_to( 'author'  => 'IMGames::Schema::Result::User',    'user_id' );


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
