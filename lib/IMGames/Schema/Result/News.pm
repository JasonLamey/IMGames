package IMGames::Schema::Result::News;

use Dancer2 appname => 'IMGames';

use strict;
use warnings;

# Third Party modules
use base 'DBIx::Class::Core';
use DateTime;
our $VERSION = '1.0';


=head1 NAME

IMGames::Schema::Result::News


=head1 AUTHOR

Jason Lamey L<email:jasonlamey@gmail.com>


=head1 SYNOPSIS AND USAGE

This module represents the News article object in the web app, as well as the interface to the C<news> table in the database.

=cut

__PACKAGE__->table( 'news' );
__PACKAGE__->add_columns(
                          id =>
                            {
                              accessor          => 'news',
                              data_type         => 'integer',
                              size              => 20,
                              is_nullable       => 0,
                              is_auto_increment => 1,
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
                          user_id =>
                            {
                              data_type         => 'integer',
                              size              => 20,
                              is_nullable       => 0,
                            },
                          views =>
                            {
                              data_type         => 'integer',
                              is_nullable       => 0,
                              default_value     => 0,
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

__PACKAGE__->belongs_to( 'user' => 'IMGames::Schema::Result::User', 'user_id' );


=head1 METHODS


=head2 average_rating_score()

This method returns the average Product Rating score for the product.

=over 4

=item Input: Product object.

=item Output: The average rating score value. Defaults to 0.

=back

  $avg_score = $product->average_rating_score;

=cut

sub average_rating_score
{
  my ( $self ) = @_;

  my $avg_rs = $self->reviews->search( {},
                                    {
                                      columns =>
                                      {
                                        rounded_score =>
                                        {
                                          ROUND =>
                                          [
                                            {
                                              AVG => 'rating'
                                            },
                                            2
                                          ],
                                        },
                                      },
                                    }
  );

  my $average_score = $avg_rs->single->get_column( 'rounded_score' );

  return ( defined $average_score and $average_score > 0 ) ? $average_score : 0;
}


=head1 COPYRIGHT & LICENSE

Copyright 2016, Infinite Monkeys Games L<http://www.infinitemonkeysgames.com>
All rights reserved.

=cut

1;
