package IMGames::Util;

use Dancer2 appname => 'IMGames';
use Dancer2::Plugin::Passphrase;

use strict;
use warnings;

# IMGames modules

# Third Party modules
use version; our $VERSION = qv( 'v0.1.0' );


=head1 NAME

IMGames::Util


=head1 AUTHOR

Jason Lamey L<email:jasonlamey@gmail.com>


=head1 SYNOPSIS AND USAGE

This module provides helper utilities for the IMGames webapp.


=head1 METHODS


=head2 generate_random_string()

Generates a new random string for use with a new account or for a password reset, or as confirmation code tokens.

=over 4

=item Input: none required; can take a hashref of the following for customization: C<string_length> and C<char_set>. String length defines the length of the random password; defaults to 32. Char set defines the particular characters to be used, and is an arrayref, e.g. C<['a'..'z', 'A'..'Z']>, defaults to C<['a'..'z', 'A'..'Z', 0..9]>.

=item Output: A string of randomized chracters

=back

    my $rand_pass = IMGames::Util->generate_random_string();
    my $rand_pass = IMGames::Util->generate_random_string( { string_length => 32, char_set => ['a'..'z', 'A'..'Z'] } );

=cut

sub generate_random_string
{
  my ( $self, %params ) = @_;

  my $string_length = delete $params{'string_length'} // 32;
  my $char_set      = delete $params{'char_set'}      // ['a'..'z', 'A'..'Z', 0..9];

  return passphrase->generate_random( { length => $string_length, charset => $char_set } );
}


=head1 COPYRIGHT & LICENSE

Copyright 2016, Infinite Monkeys Games L<http://www.infinitemonkeysgames.com>
All rights reserved.

=cut

1;
