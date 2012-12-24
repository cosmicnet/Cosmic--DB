# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use strict;
use warnings;
use Test::More qw(no_plan);

use lib 't', '.';

$| = 1;

BEGIN {
    use_ok( 'DBI' );
    use_ok( 'Cosmic::DB::Schema' );
    use_ok( 'Cosmic::DB::SQL' );
}


# Load global sample schemas
require_ok ('schema.pl');

use vars qw(
    $schema_sample
);

# Load test DB info
my %DBINFO;
open( INF, 't/dbinfo' );
    while ( <INF> ) {
        print $_;
        chomp( $_ );
        my ( $key, $value ) = split( /=/, $_, 2 );
        $DBINFO{$key} = $value;
    }#while
close( INF );

# define database list
my %db_list = (
    mysql     => {
        name   => 'MySQL',
        driver => 'mysql',
        dsn    => 'DBI:mysql:database={db};host={host};',
        error  => {
            not_null          => 'cannot be null',
            not_unique        => 'Duplicate entry',
            duplicate_key     => 'Duplicate entry.*for key',
            invalid_reference => 'Cannot add or update a child row',
            is_referenced     => 'Cannot delete or update a parent row',
        },
    },
    postgres  => {
        name   => 'Postgres',
        driver => 'Pg',
        dsn    => 'DBI:Pg:database={db};host={host};',
        error  => {
            not_null          => 'violates not-null',
            not_unique        => 'violates unique',
            duplicate_key     => 'duplicate key value violates',
            invalid_reference => 'violates foreign key constraint .*? is not present',
            is_referenced     => 'violates foreign key constraint .*? is still referenced',
        },
    },
    oracle    => {
        name   => 'Oracle',
        driver => 'Oracle',
        dsn    => 'DBI:Oracle:sid={db};host={host};',
        error  => {
            not_null          => 'cannot insert NULL',
            not_unique        => 'unique constraint .*? violated',
            duplicate_key     => 'unique constraint .*? violated',
            invalid_reference => 'integrity constraint .*? violated - parent key not found',
            is_referenced     => 'integrity constraint .*? violated - child record found',
        },
    },
    sqlserver => {
        name   => 'SQL Server',
        driver => 'ODBC',
        dsn    => 'DBI:ODBC:Driver={SQL Server};Server={host};Database={db};',#$dbh = DBI->connect("dbi:ODBC:Driver={SQL Server};Server=localhost\\SQLEXPRESS;Database=test;UID=test;PWD=test") or croak "$DBI::errstr\n";
        error  => {
            not_null          => 'column does not allow nulls',
            not_unique        => 'Violation of UNIQUE KEY constraint',
            duplicate_key     => 'Cannot insert duplicate key',
            invalid_reference => 'conflicted with the FOREIGN KEY constraint',
            is_referenced     => 'conflicted with the REFERENCE constraint',
        },
    },
);

sub parse_db_variables {
    my ( $db, $sql, $variables ) = @_;
    $variables = {
        (map { $_ =~ /_(\w+)$/; $1 => $DBINFO{$_} } grep { $_ =~ /^${db}_/ } keys %DBINFO),
        %$variables,
    };
    foreach my $key (keys %$variables) {
        $sql =~ s/\{$key\}/$variables->{$key}/g;
#        diag( "s/\{$key\}/$variables->{$key}/g;" );
    }#foreach
    return $sql;
}#sub

# TODO move these to helper methods
sub fixdate {
    my ( $dbh, $date ) = @_;
    if ( $date =~ m#^\d\d\d\d-\d\d-\d\d$# ) {
        return "TO_DATE('$date', 'YYYY-MM-DD')" if ( $dbh->{Driver}->{Name} eq 'Oracle' );
        return "'$date'";
    }#if
    elsif ( $date =~ m#^\d\d:\d\d:\d\d$# ) {
        return "TO_DATE('1000-01-01 $date', 'YYYY-MM-DD HH24:MI:SS')" if ( $dbh->{Driver}->{Name} eq 'Oracle' );
        return "'$date'";
    }#elsif
    elsif ( $date =~ m#^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d$# ) {
        return "TO_DATE('$date', 'YYYY-MM-DD HH24:MI:SS')" if ( $dbh->{Driver}->{Name} eq 'Oracle' );
        return "'$date'";
    }#elsif
    else {
        croak( "Date/time format invalid '$date'" );
    }#else
}#sub

sub fixfloat {
    my ( $dbh, $float ) = @_;
    if ( $float =~ m#E\+([0-9]+)$#i && $1 > 125 ) {
        return "${float}d" if ( $dbh->{Driver}->{Name} eq 'Oracle' );
    }#if
    return $float;
}#sub

sub create_test_schema {
    my ( $dbh, $db_schema, $schema ) = @_;
    $db_schema->load( $schema );
    my @test_schema = $db_schema->create( drop => 1 );
    foreach my $sql ( @test_schema ) {
#        diag( $sql );
        ok( $dbh->do($sql), 'Dropping/Creating tables' );
    }#foreach
}#sub

# Try db connection, skip otherwise
while ( my ( $db, $details ) = each %db_list ) {
    SKIP:
    {
        skip( "No $details->{name} database details", 1 ) unless ( $DBINFO{"${db}_db"} && $DBINFO{"${db}_user"} );

        # Copy dsn, swap in values
        my $dsn = $details->{dsn};
        $dsn =~ s/\{db\}/$DBINFO{"${db}_db"}/;
        $dsn =~ s/\{host\}/$DBINFO{"${db}_host"}/;
        my $dbh = DBI->connect($dsn, $DBINFO{"${db}_user"}, $DBINFO{"${db}_pass"},
            { RaiseError => 0, PrintError => 0, PrintWarn => 0, AutoCommit => 1 });
        isa_ok ($dbh, 'DBI::db', 'DBH Object created');

        unless ( ref $dbh eq 'DBI::db' ) {
            skip( "!!$details->{name} database details are invalid!!", 1 );
        }#unless

        diag( "==Running tests on $details->{name}==");

        # Create schema object
        my $db_schema = Cosmic::DB::Schema->new( $dbh );
        isa_ok ($db_schema, 'Cosmic::DB::Schema', 'Cosmic::DB::Schema Object created');

        # Load sample schema
        create_test_schema( $dbh, $db_schema, $schema_sample );

        # Create SQL object
        my $db_sql = Cosmic::DB::SQL->new( $dbh );

        # Test inserts
        my @columns = ( 'col_smallint', 'col_int', 'col_bigint', 'col_real', 'col_double', 'col_char', 'col_minchar', 'col_maxchar', 'col_varchar', 'col_minvarchar', 'col_maxvarchar', 'col_text', 'col_date', 'col_time', 'col_timestamp' );
        my $sql = $db_sql->sql->insert( 'test_sample', \@columns, '?' )->sql;
        my $sql_expected = "INSERT INTO `test_sample` (`col_smallint`,`col_int`,`col_bigint`,`col_real`,`col_double`,`col_char`,`col_minchar`,`col_maxchar`,`col_varchar`,`col_minvarchar`,`col_maxvarchar`,`col_text`,`col_date`,`col_time`,`col_timestamp`) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) ";
        is( $sql, $sql_expected, 'INSERT sql correct' );
        #diag( $sql );
        #
        #
        #
        #
        #
        ## test ranges
        #my $sql = 'INSERT INTO ' . $dbh->quote_identifier('test_numeric');
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_smallint') . ") VALUES (32767)"), "smallint max" );
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_smallint') . ") VALUES (-32768)"), "smallint min" );
        #
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_int') . ") VALUES (2147483647)"), "int max" );
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_int') . ") VALUES (-2147483648)"), "int min" );
        #
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_bigint') . ") VALUES (9223372036854775807)"), "bigint max" );
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_bigint') . ") VALUES (-9223372036854775808)"), "bigint min" );
        #
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_real') . ") VALUES (3.4E+38)"), "real max" );
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_real') . ") VALUES (-3.4E+38)"), "real min" );
        #
        ## This fails under Oracle 10g XE
        ## SELECT product FROM product_component_version WHERE product LIKE 'Oracle Database%'; RETURNS Oracle Database 10g Express Edition
        ## SELECT version(); - mysql
        #SKIP: {
        #    #if ( $dbh->{Driver}->{Name} eq 'Oracle' ) {
        #    #    my $sth = $dbh->prepare("SELECT product FROM product_component_version WHERE product LIKE 'Oracle Database%'");
        #    #    $sth->execute();
        #    #    my ( $product ) = $sth->fetchrow_array;
        #    #    $sth->finish();
        #    #    skip( "Doubles not supported by Oracle Database 10g Express Edition", 2 ) if $product =~ /Oracle Database 10g Express Edition/;
        #    #}#if
        #    #$dbh->do("$sql (" . $dbh->quote_identifier('col_double') . ") VALUES (1.79E+308)");
        #    #skip( "Doubles not supported by this version of $details->{name}", 2 ) if $dbh->errstr;
        #    ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_double') . ") VALUES (" . fixfloat($dbh,'1.79E+308') . ")"), "double max" );
        #    ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_double') . ") VALUES (" . fixfloat($dbh,'-1.79E+308') . ")"), "double min" );
        #}
        #
        #
        ## test strings
        #create_test_schema( $dbh, $db_schema, $schema_strings );
        #
        ## test ranges
        #$sql = 'INSERT INTO ' . $dbh->quote_identifier('test_strings');
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_minchar') . ") VALUES ('a')"), "char min" );
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_char') . ") VALUES ('a')"), "char" );
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_maxchar') . ") VALUES ('" . 'a' x 255 . "')"), "char max" );
        #
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_minvarchar') . ") VALUES ('a')"), "varchar min" );
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_varchar') . ") VALUES ('" . 'a' x 2000 . "')"), "varchar" );
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_maxvarchar') . ") VALUES ('" . 'a' x 2000 . "')"), "varchar max" );
        #
        ## TODO sensible way to test text field limits?
        ## Oracle wont allow string literals bigger than 4000
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_text') . ") VALUES ('" . 'a' x 4000 . "')"), "text" );
        #
        #
        ## test dates
        #create_test_schema( $dbh, $db_schema, $schema_dates );
        #
        ## Oracle dates need padding out
        #
        ## test ranges
        #$sql = 'INSERT INTO ' . $dbh->quote_identifier('test_dates');
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_date') . ") VALUES (" . fixdate($dbh, '1000-01-01') . ")"), "date min" );
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_date') . ") VALUES (" . fixdate($dbh, '9999-12-31') . ")"), "date max" );
        #
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_time') . ") VALUES (" . fixdate($dbh, '00:00:00') . ")"), "time min" );
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_time') . ") VALUES (" . fixdate($dbh, '23:59:59') . ")"), "time max" );
        #
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_timestamp') . ") VALUES (" . fixdate($dbh, '1000-01-01 00:00:00') . ")"), "timestamp min" );
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_timestamp') . ") VALUES (" . fixdate($dbh, '9999-12-31 23:59:59') . ")"), "timestamp max" );
        #
        ## Other field options
        #create_test_schema( $dbh, $db_schema, $schema_misc );
        #
        #$sql = 'INSERT INTO ' . $dbh->quote_identifier('test_misc');
        ## not null
        #ok( !$dbh->do("$sql (" . $dbh->quote_identifier('col_notnull') . ") VALUES (?)", undef, undef ), "Null insert" );
        #like( $dbh->errstr, qr/$details->{error}->{not_null}/s, "Null insert stopped" );
        #
        ## uniques
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_unique') . ', ' . $dbh->quote_identifier('col_notnull') . ") VALUES (1,1)" ), "Unique insert" );
        #ok( !$dbh->do("$sql (" . $dbh->quote_identifier('col_unique') . ', ' . $dbh->quote_identifier('col_notnull') . ") VALUES (1,1)" ), "Non unique insert" );
        #like( $dbh->errstr, qr/$details->{error}->{not_unique}/s, "Duplicate insert on unique raised error" );
        #
        ## default
        #my $sth = $dbh->prepare( "SELECT " . $dbh->quote_identifier('col_default') .
        #    " FROM " . $dbh->quote_identifier('test_misc') .
        #    " WHERE " . $dbh->quote_identifier('col_unique') . "=1" );
        #$sth->execute();
        #my ( $default_value ) = $sth->fetchrow_array;
        #$sth->finish();
        #is( $default_value, 20, "Default value works" );
        #
        #
        ## Serials
        #create_test_schema( $dbh, $db_schema, $schema_serial );
        #
        #$sql = 'INSERT INTO ' . $dbh->quote_identifier('test_serial');
        ## Implicit
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_extra') . ") VALUES (0)" ), "Implicit serial insert" );
        #$sth = $dbh->prepare( "SELECT " . $dbh->quote_identifier('col_serial') .
        #    " FROM " . $dbh->quote_identifier('test_serial') );
        #$sth->execute();
        #my ( $serial_value ) = $sth->fetchrow_array;
        #$sth->finish();
        #is( $serial_value, 1, "First serial is 1" );
        #
        ## Explicit
        ## TODO move this to helper method
        #$dbh->do("SET IDENTITY_INSERT " . $dbh->quote_identifier('test_serial') . " ON") if $dbh->{Driver}->{Name} eq 'ODBC';
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_serial') . ") VALUES (2147483647)" ), "Explicit max serial insert" );
        #$dbh->do("SET IDENTITY_INSERT " . $dbh->quote_identifier('test_serial') . " OFF") if $dbh->{Driver}->{Name} eq 'ODBC';
        #
        #
        ## bigserial
        #create_test_schema( $dbh, $db_schema, $schema_bigserial );
        #
        #$sql = 'INSERT INTO ' . $dbh->quote_identifier('test_bigserial');
        ## Implicit
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_extra') . ") VALUES (0)" ), "Implicit bigserial insert" );
        #$sth = $dbh->prepare( "SELECT " . $dbh->quote_identifier('col_bigserial') .
        #    " FROM " . $dbh->quote_identifier('test_bigserial') );
        #$sth->execute();
        #( $serial_value ) = $sth->fetchrow_array;
        #$sth->finish();
        #is( $serial_value, 1, "First bigserial is 1" );
        #
        ## Explicit
        ## TODO move this to helper method
        #$dbh->do("SET IDENTITY_INSERT " . $dbh->quote_identifier('test_bigserial') . " ON") if $dbh->{Driver}->{Name} eq 'ODBC';
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_bigserial') . ") VALUES (9223372036854775807)" ), "Explicit max bigserial insert" );
        #$dbh->do("SET IDENTITY_INSERT " . $dbh->quote_identifier('test_bigserial') . " OFF") if $dbh->{Driver}->{Name} eq 'ODBC';
        #
        #
        ## Primary key
        #create_test_schema( $dbh, $db_schema, $schema_pk );
        #
        #$sql = 'INSERT INTO ' . $dbh->quote_identifier('test_pk');
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_pk') . ") VALUES (1)" ), "PK insert" );
        #ok( !$dbh->do("$sql (" . $dbh->quote_identifier('col_pk') . ") VALUES (1)" ), "PK duplicate insert" );
        #like( $dbh->errstr, qr/$details->{error}->{duplicate_key}/is, "Duplicate key raised error" );
        #
        #
        ## Primary key multiple
        #create_test_schema( $dbh, $db_schema, $schema_pk_multi );
        #
        #$sql = 'INSERT INTO ' . $dbh->quote_identifier('test_pk_multi');
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_pk1') . ', ' . $dbh->quote_identifier('col_pk2') . ") VALUES (1,'a')" ), "PK insert" );
        #ok( !$dbh->do("$sql (" . $dbh->quote_identifier('col_pk1') . ', ' . $dbh->quote_identifier('col_pk2') . ") VALUES (1,'a')" ), "PK insert" );
        #like( $dbh->errstr, qr/$details->{error}->{duplicate_key}/is, "Duplicate key raised error" );
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_pk1') . ', ' . $dbh->quote_identifier('col_pk2') . ") VALUES (1,'b')" ), "PK insert 2" );
        #ok( !$dbh->do("$sql (" . $dbh->quote_identifier('col_pk1') . ', ' . $dbh->quote_identifier('col_pk2') . ") VALUES (1,'b')" ), "PK insert 2" );
        #like( $dbh->errstr, qr/$details->{error}->{duplicate_key}/is, "Duplicate key raised error" );
        #
        #
        ## Index
        #create_test_schema( $dbh, $db_schema, $schema_index );
        #
        ## Index multi
        #create_test_schema( $dbh, $db_schema, $schema_index_multi );
        #
        #$sql = 'INSERT INTO ' . $dbh->quote_identifier('test_index_multi');
        #ok( $dbh->do("$sql (" . $dbh->quote_identifier('col_index1') . ', ' . $dbh->quote_identifier('col_index2') . ") VALUES (1,'a')" ), "Index insert" );
        #ok( !$dbh->do("$sql (" . $dbh->quote_identifier('col_index1') . ', ' . $dbh->quote_identifier('col_index2') . ") VALUES (1,'a')" ), "Index insert" );
        #like( $dbh->errstr, qr/$details->{error}->{duplicate_key}/is, "Duplicate key raised error" );
        #
        #
        ## Constraint checks
        #create_test_schema( $dbh, $db_schema, $schema_constraints );
        #
        ## Load tables to create keys
        #my $sql_a = 'INSERT INTO ' . $dbh->quote_identifier('test_constraint_a') . " (" . $dbh->quote_identifier('col_extra') . ") VALUES (?)";
        #ok( $dbh->do( $sql_a, undef, 10 ), "Constraint table a inserts" );
        #ok( $dbh->do( $sql_a, undef, 11 ), "Constraint table a inserts" );
        #my $sql_b = 'INSERT INTO ' . $dbh->quote_identifier('test_constraint_b') . " (" . $dbh->quote_identifier('col_extra') . ") VALUES (?)";
        #ok( $dbh->do( $sql_b, undef, 20 ), "Constraint table b inserts" );
        #ok( $dbh->do( $sql_b, undef, 21 ), "Constraint table b inserts" );
        #
        ## Reference keys
        #my $sql_c = 'INSERT INTO ' . $dbh->quote_identifier('test_constraint_c') . " (" . $dbh->quote_identifier('col_serial_a') . ', ' . $dbh->quote_identifier('col_serial_b') . ") VALUES (?,?)";
        #ok( $dbh->do( $sql_c, undef, 1, 1 ), "Constraint table c inserts" );
        #ok( $dbh->do( $sql_c, undef, 1, 2 ), "Constraint table c inserts" );
        #ok( $dbh->do( $sql_c, undef, 2, 1 ), "Constraint table c inserts" );
        #ok( $dbh->do( $sql_c, undef, 2, 2 ), "Constraint table c inserts" );
        #
        ## Invalid references
        #ok( !$dbh->do( $sql_c, undef, 3, 1 ), "Constraint table c invalid ref a insert" );
        #like( $dbh->errstr, qr/$details->{error}->{invalid_reference}/is, "Invalid reference raised error" );
        #ok( !$dbh->do( $sql_c, undef, 1, 3 ), "Constraint table c invalid ref b insert" );
        #like( $dbh->errstr, qr/$details->{error}->{invalid_reference}/is, "Invalid reference raised error" );
        #ok( !$dbh->do( $sql_c, undef, 3, 3 ), "Constraint table c invalid ref a & b insert" );
        #like( $dbh->errstr, qr/$details->{error}->{invalid_reference}/is, "Invalid reference raised error" );
        #
        ## Delete no cascade
        #$sql = 'DELETE FROM ' . $dbh->quote_identifier('test_constraint_a');
        #ok( !$dbh->do("$sql WHERE " . $dbh->quote_identifier('col_serial_a') . '=' . "1" ), "Constraint table a invalid referenced key removal" );
        #like( $dbh->errstr, qr/$details->{error}->{is_referenced}/is, "Invalid reference removal raised error" );
        #
        ## Delete cascade
        #$sql = 'DELETE FROM ' . $dbh->quote_identifier('test_constraint_b');
        #ok( $dbh->do("$sql WHERE " . $dbh->quote_identifier('col_serial_b') . '=1' ), "Constraint table b cascade key removal" );
        #$sth = $dbh->prepare( "SELECT COUNT(*) FROM " . $dbh->quote_identifier('test_constraint_c') .
        #    " WHERE " . $dbh->quote_identifier('col_serial_b') . '=1' );
        #$sth->execute();
        #my ( $count_value ) = $sth->fetchrow_array;
        #$sth->finish();
        #is( $count_value, 0, "Referencing rows were deleted from table c" );

        # disconnect
        $dbh->disconnect();
    }#skip
}#while

done_testing();
