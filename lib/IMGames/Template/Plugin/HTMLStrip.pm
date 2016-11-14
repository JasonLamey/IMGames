package IMGames::Template::Plugin::HTMLStrip;

use base qw( Template::Plugin );
use Template::Plugin;

use HTML::Restrict;

sub load
{
    my ( $class, $context ) = @_;

    return $class;
}

sub new
{
    my ( $class, $context, @params ) = @_;

    bless
    {
        _CONTEXT => $context,
    }, $class;
}

sub strip_html
{
    my ( $self, $text ) = @_;

    my $hr = HTML::Restrict->new();

    my $clean_text = $hr->process( $text );

    return $clean_text;
}

sub strip_html_with_lf
{
    my ( $self, $text ) = @_;

    my $hr = HTML::Restrict->new(
      rules =>
      {
        br => [],
      }
    );

    my $clean_text = $hr->process( $text );

    return $clean_text;
}

1;
