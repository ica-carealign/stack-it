package StackIt::Bin::Migrator;
use DBI;
use Moose;
use File::Basename qw();
use File::Spec qw();
use File::stat qw();
use IPC::Run qw();
use List::Util qw();
use Term::ANSIColor qw(:constants);
use Time::HiRes qw();
use utf8;

use StackIt::DB::Collection::Stack::Role;

has environment    => (is => 'ro', isa => 'Maybe[Str]');
has database       => (is => 'ro', isa => 'Maybe[Str]');
has username       => (is => 'ro', isa => 'Maybe[Str]');
has password       => (is => 'ro', isa => 'Maybe[Str]');
has host           => (is => 'ro', isa => 'Maybe[Str]');
has port           => (is => 'ro', isa => 'Maybe[Str]');
has wantColor      => (is => 'ro', isa => 'Bool', default => 0);
has dataDirectory  => (is => 'ro', isa => 'Str', required => 1);
has migrationTable => (is => 'ro', isa => 'Str', default => '_migration');
has verbosity      => (is => 'ro', isa => 'Int', default => 1);

has connInfo       => (is => 'ro', isa => 'HashRef', lazy => 1,
                       builder => '_buildConnInfo');

has dbh            => (is => 'ro', isa => 'Object', lazy => 1,
                       builder => '_connect');

has dbConfig       => (is => 'ro', isa => 'Object', lazy => 1,
                       default => sub { StackIt::DB::Config->new });

has _migrations    => (is => 'ro', isa => 'ArrayRef', lazy => 1,
                       builder => '_discoverMigrations');

has _statusFormat  => (is => 'ro', isa => 'Str', lazy => 1,
                       builder => '_buildStatusFormat');

has _migrationsRun => (is => 'ro', isa => 'Int', default => sub { 0 },
                       traits => ['Counter'], handles => { _incMigrationsRun => 'inc' });

{
  package StackIt::Bin::Migrator::Migration;
  use Moose;
  has id       => (is => 'ro', isa => 'Int', required => 1);
  has name     => (is => 'ro', isa => 'Str', required => 1);
  has path     => (is => 'ro', isa => 'Str', required => 1);
  has type     => (is => 'ro', isa => 'Str', required => 1);
  has migrator => (is => 'ro', isa => 'Object', required => 1);

  sub create {
    my $class = shift;
    my $args;
    if (@_ == 1 && ref($_[0]) eq 'HASH') {
      $args = shift;
    }
    elsif (@_ % 2 == 0) {
      $args = { @_ };
    }
    else {
      die "expected either a hashref or even-numbered list";
    }
    my $type = $args->{type} || die "'type' parameter is required";
    my $suffix;
    if ($type eq 'sql') {
      $suffix = 'Sql';
    }
    elsif ($type eq 'pl') {
      $suffix = 'Perl';
    }
    else {
      die "'type' parameter must be 'sql' or 'pl'";
    }
    my $desiredClass = join("::", __PACKAGE__, $suffix);
    return $desiredClass->new($args);
  }
  no Moose;
}

{
  package StackIt::Bin::Migrator::Migration::Sql;
  use Moose;
  extends 'StackIt::Bin::Migrator::Migration';

  sub run {
    my ($self) = @_;
    $self->migrator->notifyStarted($self);
    my $result = $self->migrator->runMysqlFile($self->path);
    $self->migrator->reportResult($self->name, $result);
    if ($result->{ok}) {
      $self->migrator->notifyFinished($self);
    }
    return $result->{ok};
  }

  no Moose;
}

sub _stopwatch(&) {
  my $sub = shift;
  my $t0 = [Time::HiRes::gettimeofday];
  $sub->();
  return Time::HiRes::tv_interval($t0);
}

sub _summarize {
  my ($self,$sub) = @_;
  my $ok;
  my $elapsed = _stopwatch { $ok = $sub->() };
  if ($ok) {
    my $status = sprintf "%d migration%s performed", $self->_migrationsRun,
      $self->_migrationsRun == 1 ? '' : 's';
    $self->info("COMPLETE", $status, $elapsed);
  }
  else {
    my $arrow = ($ENV{LANG}||'') =~ /utf-?8/i ? '↑↑↑' : '^^^';
    $self->error("INCOMPLETE", "$arrow See error details above $arrow", -1); 
  }
  return $ok;
}

sub migrate {
  my ($self) = @_;
  return $self->_summarize(sub { $self->_actualMigrate });
}

sub createSnapshot {
  my $self = shift;
  $self->debug("SNAPSHOT", "", -1);
  return $self->_summarize(sub {
    return unless $self->_actualMigrate(clobber => 1);
    return unless $self->_dumpSchemaSnapshot;
    return unless $self->_dumpSeedSnapshot;
    return 1;
  });
}

sub _actualMigrate {
  my ($self,%opts) = @_;
  my $clobber = $opts{clobber};

  my $dbIsNew = ! $self->_databaseExists;

  if (!$dbIsNew && $clobber) {
    return unless $self->_dropDatabase;
    $dbIsNew = 1;
  }
  if ($dbIsNew) {
    return unless $self->_createDatabase;
  }

  my $hasMigTable = $self->_tableExists($self->migrationTable);
  if (! $hasMigTable) {
    return unless $self->_deployMigrationTable;
    if (! $dbIsNew) {
      # Database was deployed pre-migrations. Assume migrated to baseline.
      my ($baseline) = grep { $_->id =~ /^0+$/ } @{$self->_migrations}
        or die "missing baseline migration";
      $self->notifyStarted($baseline);
      $self->notifyFinished($baseline);
    }
  }

  if ($dbIsNew) {
    return unless $self->_deploySchema;
    return unless $self->_deploySeedData;
  }

  return unless $self->_executeMigrations;
}

sub _makeLineFilter {
  my ($self,$OUT,$sub) = @_;
  my $buf = '';
  return sub {
    my $in = shift;
    if (defined $in) {
      $buf .= $in;
      while ($buf =~ s/\A(.*?\n)//) {
        local $_ = $1;
        $sub->($_);
        print {$OUT} $_;
      }
    }
    else {
      # eof 
      print {$OUT} $buf;
      $buf = '';
      return;
    }
  };
}

sub _dumpWithFilter {
  my ($self,$target,$dumpArgs,$filterSub) = @_;
  my $tmpFile = sprintf "%s.tmp.$$", $target;
  my $stat = File::stat::stat($target);
  open(my $OUT, ">", $tmpFile) || die "can't open '$tmpFile': $!";
  my $sink = $self->_makeLineFilter($OUT, $filterSub);
  my $result = $self->_runMysqlDump($sink, @$dumpArgs);
  $sink->(undef); # signal eof

  if ($result->{ok}) {
    if ($stat) {
      chmod($stat->mode, $tmpFile) || die "can't chmod '$tmpFile': $!";
    }
    rename($tmpFile, $target)
      || die "can't replace rename('$tmpFile','$target'): $!";
  }
  else {
    unlink($tmpFile);
  }

  return $result;
}

sub _dumpSchemaSnapshot {
  my ($self) = @_;
  my $result = $self->_dumpWithFilter(
    $self->_schemaFile,
    [qw(--no-data --default-character-set=utf8)],
    sub {
      $_ = '' if /^-- Host:/;
      $_ = '' if /^-- Dump completed on 2/;
      s/^(\) ENGINE.*)AUTO_INCREMENT=\d+\s*/$1/;
    }
  );
  $self->_reportMysqlDump("schema", $result);
  return $result->{ok};
}

sub _dumpSeedSnapshot {
  my ($self) = @_;
  my $result = $self->_dumpWithFilter(
    $self->_seedFile,
    [qw(--skip-triggers --skip-add-drop-table --no-create-info
        --skip-comments --complete-insert --default-character-set=utf8)],
    sub {
      # add more linefeeds easier git diffing
      s/\) VALUES \(/\) VALUES\n\(/;
      s/\),\(/\),\n\(/g;
    }
  );
  $self->_reportMysqlDump("seed", $result);
  return $result->{ok};
}

our %LevelColor = (
  0 => BOLD.WHITE.ON_RED,
  1 => BOLD.GREEN,
  2 => BOLD.YELLOW,
);

sub _getColors {
  my ($self,$level) = @_;
  return ('','') unless $self->wantColor;
  return ($LevelColor{$level} || $LevelColor{2}, RESET);
}

sub _colorize {
  my ($self,$level,$text) = @_;
  my ($color,$reset) = $self->_getColors($level);
  return join('', $color, $text, $reset);
}

sub status {
  my ($self,$level,$label,$summary,$time,$content) = @_;

  return unless $level <= $self->verbosity;

  $time ||= 0;

  my ($color,$realReset) = $self->_getColors($level);

  my ($reset,$wideReset) = ('','');
  if ($level < 1) {
    $wideReset = $realReset;
  }
  else {
    $reset = $realReset;
  }

  if ($time != -1) {
    $summary = sprintf($self->_statusFormat, $summary, $time);
  }

  printf STDERR "%s[%12.12s]%s %s%s\n", $color, $label, $reset, $summary, $wideReset;
  if (defined($content) && $content =~ /\S/) {
    $content =~ s/\n*$/\n\n/;
    print STDERR "\n", $content;
  }
}

sub error {
  my $self = shift;
  $self->status(0, @_);
}

sub info {
  my $self = shift;
  $self->status(1, @_);
}

sub debug {
  my $self = shift;
  $self->status(2, @_);
}

sub spew {
  my $self = shift;
  $self->status(3, @_);
}

sub _databaseName {
  my $self = shift;
  return $self->connInfo->{database};
}

sub _selectDatabase {
  my $self = shift;
  $self->dbh->do('use ' .  $self->dbh->quote_identifier($self->_databaseName));
}

sub _deployMigrationTable {
  my $self = shift;
  my $quotedTable = $self->dbh->quote_identifier($self->migrationTable);
  my $ddl = "
    CREATE TABLE @{[ $quotedTable ]} (
      id varchar(191) NOT NULL PRIMARY KEY,
      name varchar(191) NOT NULL,
      started datetime NOT NULL,
      finished datetime DEFAULT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
  ";

  my $ok;
  $self->_selectDatabase;
  my $time = _stopwatch { $ok = $self->dbh->do($ddl) };
  $self->info("CREATE TABLE", $self->migrationTable, $time,
    $self->verbosity > 2 ? ($ddl) : ());
  return $ok;
}

sub _completedMigrations {
  my $self = shift;
  my $sql = sprintf qq{SELECT id FROM %s WHERE finished IS NOT NULL},
    $self->dbh->quote_identifier($self->migrationTable);

  $self->_selectDatabase;
  return sort @{ $self->dbh->selectcol_arrayref($sql) };
}

sub _executeMigrations {
  my $self = shift;
  my %completed = map { $_ => 1 } $self->_completedMigrations;
  for my $migration (@{$self->_migrations}) {
    if ($completed{$migration->id}) {
      # print SKIPPING
      $self->debug("SKIP", $migration->name, 0);
    }
    else {
      $self->_selectDatabase;
      $migration->run || return;
      $self->_incMigrationsRun;
    }
  }
  return 1;
}

sub notifyStarted {
  my ($self,$migration) = @_;
  my $sql = qq{
    INSERT INTO %s (id, name, started) VALUES (?, ?, NOW())
    ON DUPLICATE KEY UPDATE started = NOW()
  };
  my $table = $self->dbh->quote_identifier($self->migrationTable);
  $self->dbh->do(sprintf($sql, $table), undef, $migration->id, $migration->name);
}

sub notifyFinished {
  my ($self,$migration) = @_;
  my $sql = qq{
    UPDATE %s SET finished = NOW() WHERE id = ?
  };
  my $table = $self->dbh->quote_identifier($self->migrationTable);
  $self->dbh->do(sprintf($sql, $table), undef, $migration->id);
}

sub _buildStatusFormat {
  my $self = shift;
  my $longestMig = List::Util::max map { length($_->name) } @{$self->_migrations};
  $longestMig = List::Util::max($longestMig, 35); # at least 35
  $longestMig = List::Util::min($longestMig, 55); # at most 55
  return "%-${longestMig}.${longestMig}s (%0.3fs)";
}

sub reportResult {
  my ($self,$name,$mysqlResult) = @_;
  my $shortName = File::Basename::basename($name);
  if ($mysqlResult->{ok}) {
    $self->info("EXECUTE", $shortName, $mysqlResult->{elapsed}, $mysqlResult->{output});
  }
  else {
    my $error = "Error running $name:\n$mysqlResult->{output}";
    $self->error("EXECUTE", $shortName, undef, $error);
  }
}

sub _reportMysqlDump {
  my ($self,$name,$mysqlResult) = @_;
  if ($mysqlResult->{ok}) {
    $self->info("MYSQLDUMP", $name, $mysqlResult->{elapsed}, $mysqlResult->{error});
  }
  else {
    my $error = "Error dumping $name:\n$mysqlResult->{error}";
    $self->error("EXECUTE", $name, undef, $error);
  }
}

sub _deploySchema {
  my ($self) = @_;
  my $result = $self->runMysqlFile($self->_schemaFile);
  $self->reportResult($self->_schemaFile, $result);
  return $result->{ok};
}

sub _deploySeedData {
  my ($self) = @_;
  my $result = $self->runMysqlFile($self->_seedFile);
  $self->reportResult($self->_seedFile, $result);
  return $result->{ok};
}

sub _tableExists {
  my ($self,$table) = @_;
  my $info = $self->connInfo;

  # I don't pass the table name as the third argument because
  # mysql will do LIKE wildcard processing, so "_migration" will match
  # "Xmigration".
  my $sth = $self->dbh->table_info('%', $info->{database}, '%', 'TABLE');

  my $found = List::Util::first { $_->[2] eq $table } @{ $sth->fetchall_arrayref };
  return $found;
}

sub _migrationsDir {
  my $self = shift;
  return File::Spec->catfile($self->dataDirectory, "migrations");
}

sub _discoverMigrations {
  my $self = shift;
  my $dir = $self->_migrationsDir;
  my @migrations;

  opendir(my $DIRH, $dir) || die "can't opendir '$dir': $!";
  while (my $dirent = readdir($DIRH)) {
    next if ($dirent eq '.' || $dirent eq '..');
    if ($dirent =~ /^(\d+)-.*\.(sql|pl)$/) {
      my $migration = StackIt::Bin::Migrator::Migration->create(
        migrator => $self,
        id       => $1,
        name     => $dirent,
        path     => "$dir/$dirent",
        type     => $2,
      );
      push @migrations, $migration;
    }
  }
  close($DIRH);

  return [sort { $a->id cmp $b->id } @migrations];
}

sub _schemaFile {
  my $self = shift;
  return File::Spec->catfile($self->dataDirectory, "schema.sql");
}

sub _seedFile {
  my $self = shift;
  return File::Spec->catfile($self->dataDirectory, "seed.sql");
}

sub _databaseExists {
  my $self = shift;
  my $connInfo = $self->connInfo;

  my $exists;
  eval {
    my @dbs;
    my $time = _stopwatch { @dbs = @{ $self->dbh->selectcol_arrayref("SHOW DATABASES") } };
    ($exists) = grep { $_ eq $connInfo->{database} } sort @dbs;
    $exists ||= '';
    $self->spew("SHOW DB", sprintf("%d found", scalar(@dbs)), $time,
      join(", ", map { $_ eq $exists ? $self->_colorize(1, $_) : $_ } @dbs));
  };
  if ($@) {
    my $err = $@ || 'unknown error';
    $self->error("SHOW DB", "can't determine if database exists: $err");
  }
  $self->debug("DB " . ($exists ? "EXISTS" : "ABSENT"), $self->_databaseName, 0);
  return $exists;
}

sub _createDatabase {
  my $self = shift;
  my $ddl = sprintf("CREATE DATABASE %s DEFAULT CHARSET utf8;", $self->_databaseName);
  my $ok;
  eval {
    my $time = _stopwatch { $ok = $self->dbh->do($ddl) };
    $self->info("CREATE DB", $self->_databaseName, $time,
      $self->verbosity > 2 ? ($ddl) : ());
  };
  if ($@) {
    $self->error("CREATE DB", $self->_databaseName, -1, $@);
  }
  return $ok;
}

sub _dropDatabase {
  my $self = shift;
  my $ddl = sprintf("DROP DATABASE %s;", $self->_databaseName);
  my $ok;
  eval {
    my $time = _stopwatch { $ok = $self->dbh->do($ddl) };
    $self->info("DROP DB", $self->_databaseName, $time,
      $self->verbosity > 2 ? ($ddl) : ());
  };
  if ($@) {
    $self->error("DROP DB", $self->_databaseName, -1, $@);
  }
  return $ok;
}

sub _usingCustomConnection {
  my $self = shift;
  return scalar grep { defined $self->$_ }
    qw(database host port username password);
}

sub _connect {
  my $self = shift;
  my %connInfo = %{ shift || $self->connInfo };

  # Don't connect to a specific database, since it may not exist yet.
  delete $connInfo{database};
  my $dsn = $self->dbConfig->buildDsn(\%connInfo);

  my %attr = (
    %{ $connInfo{attr} || {} },
    RaiseError => 1,
    PrintError => 0,
    AutoCommit => 1,
  );

  my $dbh = DBI->connect($dsn, $connInfo{username}, $connInfo{password}, \%attr);
  if (! $dbh) {
    die "can't connect to the database: $DBI::errstr";
  }
  return $dbh;
}

sub _buildConnInfo {
  my $self = shift;

  my $connInfo;
  if ($self->_usingCustomConnection) {
    $connInfo = {
      driver   => 'mysql',
      database => $self->database,
      host     => $self->host,
      port     => $self->port,
      username => $self->username,
      password => $self->password,
    };
    $connInfo->{dsn} = $self->dbConfig->buildDsn($connInfo);
  }
  else {
    $connInfo = $self->dbConfig->connectionDetails($self->environment);
  }

  return $connInfo;
}

sub runMysqlFile {
  my ($self,$file) = @_;
  my ($ok,$status,$output);
  my @command = ('mysql', $self->_mysqlArgs);
  my $time = _stopwatch {
    $ok = IPC::Run::run \@command, '<', $file, '&>', \$output;
    $status = $?;
  };
  $self->spew('LAUNCH', "@command < $file == $?", -1);
  return {
    ok      => $ok,
    status  => $?,
    output  => $output,
    elapsed => $time,
  };
}

sub loadRoles {
  my ($self,$dir) = @_;
  opendir(my $DIRH, $dir) || die "can't opendir '$dir': $!";
  my $added = 0;
  my $ok = 1;
  my $time = _stopwatch {
    for my $roleEnv (grep { /^\w+$/ } sort readdir($DIRH)) {
      my $num = $self->_loadRoleEnv($dir,$roleEnv) || do {
        $ok = 0;
        return;
      };
      $added += $num;
    }
  };
  if ($ok) {
    $self->info("LOAD ROLES", "$added roles loaded");
  }
}

sub _loadRoleEnv {
  my ($self,$dir,$roleEnv) = @_;
  my $num = 0;
  my $coll = StackIt::DB::Collection::Stack::Role->new(DBH => $self->dbh);
  $coll->Environment($roleEnv);
  $coll->JSONDir("$dir/$roleEnv");

  my $roleTime = _stopwatch {
    eval {
      $coll->populateFromJSON;
      $num = scalar @{ $coll->Collection };
      $coll->save;
    };
  };

  my $err = $@;
  if ($err) {
    $self->error("LOAD ENV", $roleEnv, $roleTime, $err);
    return;
  }
  else {
    $self->debug("LOAD ENV", $roleEnv, $roleTime);
  }
  return $num || '0 but true';
}

sub _runMysqlDump {
  my ($self,$output,@args) = @_;
  my ($ok,$status,$errors);
  my @command = ('mysqldump', $self->_mysqlArgs, @args);
  my $time = _stopwatch {
    $ok = IPC::Run::run \@command, '>', $output, '2>', \$errors;
    $status = $?;
  };
  $self->spew('LAUNCH', "@command == $?", -1);
  return {
    ok      => $ok,
    status  => $?,
    errors  => $errors,
    output  => $output,
    elapsed => $time,
  };
}

sub _mysqlArgs {
  my ($self) = @_;
  my $connInfo = $self->connInfo;
  my @args;
  push @args, "-u$connInfo->{username}" if defined($connInfo->{username});
  push @args, "-p$connInfo->{password}" if defined($connInfo->{password});
  push @args, "-h$connInfo->{host}"     if defined($connInfo->{host});
  push @args, "-P$connInfo->{port}"     if defined($connInfo->{port});
  if ($self->verbosity > 2) {
    push @args, "-v", "-v";
  }
  push @args, $connInfo->{database}
    || die "a database name is required";
  return @args;
}

no Moose;
1;
