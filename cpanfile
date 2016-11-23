#cpanfile
requires "Dancer2" => "0.204001";

recommends "YAML"             => "0";
recommends "URL::Encode::XS"  => "0";
recommends "CGI::Deurl::XS"   => "0";
recommends "HTTP::Parser::XS" => "0";

requires 'Plack::Handler::Apache2'     => '1.0042';
requires 'App::Sqitch';
requires 'Dancer2::Session::YAML'      => '0.165000';
requires 'Dancer2::Plugin::Auth::Extensible' => '0.620';
requires 'Dancer2::Plugin::Auth::Extensible::Provider::DBIC' => '0.602';
requires 'Dancer2::Plugin::Passphrase' => '3.3.0';
requires 'Dancer2::Plugin::DBIC'       => '0.0013';
requires 'Dancer2::Plugin::Emailesque' => '0.03';
requires 'Dancer2::Plugin::Deferred'   => '0.007017';
requires 'DBI'                         => '1.636';
requires 'DBIx::Class'                 => '0.082840';
requires 'DBI::DBD'                    => '12.015129';
requires 'DBD::mysql'                  => '4.036';
requires 'DBIx::Class::Helpers'        => '2.033001';
requires 'Const::Fast'                 => '0.014';
requires 'version'                     => '0.9917';
requires 'Data::FormValidator'         => '4.81';
requires 'Mail::Box'                   => '2.120';
requires 'Emailesque'                  => '1.26';
requires 'HTML::Restrict'              => '2.2.3';
requires 'GD'                          => '2.56';
requires 'GD::Thumbnail'               => '1.42';

on "test" => sub {
    requires "Test::More"              => "0";
    requires "HTTP::Request::Common"   => "0";
    requires "Plack::Test";
    requires 'Data::Faker';
    requires 'DBIx::Class::Fixtures';
};
