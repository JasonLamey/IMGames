package IMGames::Schema::ResultSet::Product;

use Dancer2 appname => 'IMGames';

use strict;
use warnings;

# IMGames modules
use IMGames::Schema;

# Third Party modules
use parent 'DBIx::Class::ResultSet';
use version; our $VERSION = qv( 'v0.1.0' );

__PACKAGE__->load_components('Helper::ResultSet::Random');

=head1 NAME

IMGames::Schema::ResultSet::Product


=head1 AUTHOR

Jason Lamey L<email:jasonlamey@gmail.com>


=head1 SYNOPSIS AND USAGE

This module handles ResultSet objects for the Product objects. Primarily, it's here for random ordering.


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
