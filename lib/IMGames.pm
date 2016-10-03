package IMGames;

# Dancer2 modules
use Dancer2;

use strict;
use warnings;

# IMGames modules
use IMGames::Schema;

# Third Party modules
use version; our $VERSION = qv( 'v0.1.0' );

use DBIx::Class::Schema;
use Const::Fast;

const my $SCHEMA                    => IMGames::Schema->get_schema_connection();
const my $COUNTRY_CODE_SET          => 'LOCALE_CODE_ALPHA_2';
const my $USER_SESSION_EXPIRE_TIME  => 172800; # 48 hours in seconds.
const my $ADMIN_SESSION_EXPIRE_TIME => 600;    # 10 minutes in seconds.

$SCHEMA->storage->debug(1);


=head1 NAME

IMGames


=head1 SYNOPSIS AND USAGE

Primary web application library, providing all routes and data calls.


=head1 ROUTES

=cut

get '/' => sub {
    template 'index';
};

true;
