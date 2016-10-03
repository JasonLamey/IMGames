#cpanfile
requires "Dancer2" => "0.165000";

recommends "YAML"             => "0";
recommends "URL::Encode::XS"  => "0";
recommends "CGI::Deurl::XS"   => "0";
recommends "HTTP::Parser::XS" => "0";

requires 'Dancer2::Session::YAML'      => '0.165000';
requires 'Dancer2::Plugin::Passphrase' => '3.2.2';
requires 'Dancer2::Plugin::DBIC'       => '0.0011';
requires 'Dancer2::Plugin::Emailesque' => '0.03';
requires 'Dancer2::Plugin::Deferred'   => '0.007016';
requires 'DBI'                         => '1.636';
requires 'DBIx::Class'                 => '0.082840';
requires 'DBI::DBD'                    => '12.015129';
requires 'DBD::mysql'                  => '4.036';
requires 'DBIx::Class::Migration'      => '0.058';
requires 'Const::Fast'                 => '0.014';
requires 'version'                     => '0.9917';

on "test" => sub {
    requires "Test::More"              => "0";
    requires "HTTP::Request::Common"   => "0";
    requires "Plack::Test";
    requires 'Data::Faker';
    requires 'DBIx::Class::Fixtures';
};
