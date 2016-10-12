package IMGames::Schema;
use base qw/DBIx::Class::Schema/;

use strict;
use warnings;

use Const::Fast;
our $VERSION = "1.0";


=head1 NAME

IMGames::Schema


=head1 AUTHOR

Jason Lamey L<email:jasonlamey@gmail.com>


=head1 SYNOPSIS AND USAGE

Database schema for the IMGames app, using DBIx::Class.

=cut

const my $DB_NAME => 'dbi:mysql:imgames';
const my $DB_USER => 'dbmonkey';
const my $DB_PASS => '1DeeBeeMunkeez!';

__PACKAGE__->load_namespaces();


=head1 METHODS


=head2 get_schema_connection()

Returns a DBIx::Class::Schema object for the IMGames DB.

=over 4

=item Input: None

=item Output: DBIx::Class::Schema object.

=back

    my $schema = IMGames::Schema->get_schema_connection();

=cut

sub get_schema_connection
{
  my ( $self ) = @_;

  return __PACKAGE__->connect(
                              $DB_NAME,
                              $DB_USER,
                              $DB_PASS,
                              {
                                  PrintError => 1,
                                  RaiseError => 1,
                                  ChopBlanks => 1,
                                  ShowErrorStatement => 1,
                                  AutoCommit => 1,
                              },
                          );
}


=head1 COPYRIGHT & LICENSE

Copyright 2016, Infinite Monkeys Games L<http://www.infinitemonkeysgames.com>
All rights reserved.

=cut

1;
