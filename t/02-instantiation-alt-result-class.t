#!perl

use strict;
use warnings;

use lib 't/alt-result-class-lib';
use DBICDHAltTest;
use DBIx::Class::DeploymentHandler;
use aliased 'DBIx::Class::DeploymentHandler', 'DH';

use Test::More;
use File::Temp 'tempdir';
use Test::Fatal qw(lives_ok dies_ok);

my $dbh = DBICDHAltTest::dbh();
my @connection = (sub { $dbh }, { ignore_version => 1 });
my $sql_dir = tempdir( CLEANUP => 1 );

VERSION1: {
  use_ok 'DBICVersionAlt_v1';
  my $s = DBICVersionAlt::Schema->connect(@connection);
  $DBICVersionAlt::Schema::VERSION = 1;
  ok($s, 'DBICVersionAlt::Schema 1 instantiates correctly');
  my $handler = DH->new({
    script_directory => $sql_dir,
    schema => $s,
    databases => 'SQLite',
    version_source => 'DBICDHVersionAlt',
    version_class => 'DBICVersionAlt::Version',
    sql_translator_args => { add_drop_table => 0 },
  });

  ok($handler, 'DBIx::Class::DeploymentHandler w/1 instantiates correctly');

  my $version = $s->schema_version;
  $handler->prepare_install;

  dies_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
    })
  } 'schema not deployed';
  $handler->install({ version => 1 });
  dies_ok {
    $handler->install;
  } 'cannot install twice';
  lives_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
    })
  } 'schema is deployed';
}

VERSION2: {
  use_ok 'DBICVersionAlt_v2';
  my $s = DBICVersionAlt::Schema->connect(@connection);
  $DBICVersionAlt::Schema::VERSION = 2;
  subtest 'bug deploying first version' => sub {
    my $dbh = DBICDHAltTest::dbh();
    my @connection = (sub { $dbh }, { ignore_version => 1 });
    my $s = DBICVersionAlt::Schema->connect(@connection);

    my $handler = DH->new({
      script_directory => $sql_dir,
      schema => $s,
      databases => 'SQLite',
      version_source => 'DBICDHVersion',
      version_class => 'DBICVersionAlt::Version',
    });
    $handler->install({ version => 1 });
    is($handler->database_version, 1, 'correctly set version to 1');
  };

  ok($s, 'DBICVersion::Schema 2 instantiates correctly');
  my $handler = DH->new({
    script_directory => $sql_dir,
    schema => $s,
    databases => 'SQLite',
    version_source => 'DBICDHVersion',
    version_class => 'DBICVersionAlt::Version',
  });

  ok($handler, 'DBIx::Class::DeploymentHandler w/2 instantiates correctly');

  my $version = $s->schema_version();
  $handler->prepare_install;
  $handler->prepare_upgrade({ from_version => 1, to_version => $version });
  dies_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
    })
  } 'schema not deployed';
  dies_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
    })
  } 'schema not uppgrayyed';
  $handler->upgrade;
  lives_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
    })
  } 'schema is deployed';
}

VERSION3: {
  use_ok 'DBICVersionAlt_v3';
  my $s = DBICVersionAlt::Schema->connect(@connection);
  $DBICVersionAlt::Schema::VERSION = 3;
  ok($s, 'DBICVersionAlt::Schema 3 instantiates correctly');
  my $handler = DH->new({
    script_directory => $sql_dir,
    schema => $s,
    databases => 'SQLite',
    version_source => 'DBICDHVersion',
    version_class => 'DBICVersionAlt::Version',
  });

  ok($handler, 'DBIx::Class::DeploymentHandler w/3 instantiates correctly');

  my $version = $s->schema_version();
  $handler->prepare_install;
  $handler->prepare_upgrade({ from_version => 2, to_version => $version });
  dies_ok {
    $s->resultset('Foo')->create({
        bar => 'frew',
        baz => 'frew',
        biff => 'frew',
      })
  } 'schema not deployed';
  $handler->upgrade;
  lives_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
      biff => 'frew',
    })
  } 'schema is deployed';
}

DOWN2: {
  use_ok 'DBICVersionAlt_v4';
  my $s = DBICVersionAlt::Schema->connect(@connection);
  $DBICVersionAlt::Schema::VERSION = 2;
  ok($s, 'DBICVersionAlt::Schema 2 instantiates correctly');
  my $handler = DH->new({
    script_directory => $sql_dir,
    schema => $s,
    databases => 'SQLite',
    version_source => 'DBICDHVersionAlt',
    version_class => 'DBICVersionAlt::Version',
  });

  ok($handler, 'DBIx::Class::DeploymentHandler w/2 instantiates correctly');

  my $version = $s->schema_version();
  $handler->prepare_downgrade({ from_version => 3, to_version => $version });
  lives_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
      biff => 'frew',
    })
  } 'schema at version 3';
  $handler->downgrade;
  dies_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
      biff => 'frew',
    })
  } 'schema not at version 3';
  lives_ok {
    $s->resultset('Foo')->create({
      bar => 'frew',
      baz => 'frew',
    })
  } 'schema is at version 2';
}

done_testing;
