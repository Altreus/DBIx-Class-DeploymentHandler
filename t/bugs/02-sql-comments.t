#!perl

use strict;
use warnings;
use v5.010;

use Test::More;
use Test::Fatal qw(lives_ok dies_ok);

use lib 't/lib';
use DBICDHTest;
use aliased 'DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator';
use IO::All;
use File::Temp qw(tempfile tempdir);

my $dbh = DBICDHTest::dbh();
my @connection = (sub { $dbh }, { ignore_version => 1 });
my $sql_dir = tempdir( CLEANUP => 1 );

for (io->dir($sql_dir, '_common',  'upgrade', '1-2')) {
   $_->mkpath;
   $_->catfile('001-sql.sql')->print(<<'EOSQL');
INSERT INTO Foo (bar,baz) VALUES (
    'This foo line should be fine',
    'This bar line should be fine'
);
EOSQL
}

for (io->dir($sql_dir, '_common',  'upgrade', '2-3')) {
   $_->mkpath;
   $_->catfile('001-sql.sql')->print(<<'EOSQL');
-- This line should be fine
INSERT INTO Foo (bar,baz) VALUES (
    'This foo line should be fine',
    'This bar line should be fine'
),
(
    '-- This foo line should be fine',
    'This bar line should be fine'
),
(
    'This foo line should be fine',
    'This bar line -- should be fine',
); -- This line should be fine
EOSQL
}

io->dir($sql_dir, 'SQLite', 'initialize', '1')->mkpath;
io->dir($sql_dir, 'SQLite', 'upgrade', $_)->mkpath for '1-2', '2-3';

use_ok 'DBICVersion_v2';
my $s = DBICVersion::Schema->connect(@connection);
my $dm = Translator->new({
  schema            => $s,
  script_directory => $sql_dir,
  databases         => ['SQLite'],
  sql_translator_args          => { add_drop_table => 0 },
  txn_wrap          => 1,
});

$dm->prepare_deploy;
$dm->initialize({ version => '1' });
$dm->deploy;
lives_ok { $dm->upgrade_single_step({ version_set => [1, 2] }) } 'Proving SQL works';
lives_ok { $dm->upgrade_single_step({ version_set => [2, 3] }) } 'comments did not break SQL';
