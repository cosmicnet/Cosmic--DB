use strict;
use warnings;
use ExtUtils::MakeMaker qw( WriteMakefile prompt );

# define database list
my %db_list = (
    'mysql'     => 'MySQL',
    'postgres'  => 'Postgres',
    'oracle'    => 'Oracle',
    'sqlserver' => 'SQL Server',
);


# load old db connection info, prompt for new info
my $answer;
my %DBINFO;
if ( -e 't/dbinfo' ) {
    print "--Current test DB info--\n";
    open( INF, 't/dbinfo' );
        while ( <INF> ) {
            print $_;
            chomp( $_ );
            my ( $key, $value ) = split( /=/, $_, 2 );
            $DBINFO{$key} = $value;
        }#while
    close( INF );
    $answer = prompt( 'Do you want to change the current test DB info?', 'no' );
}#if
else {
    print "The tests require information for each database you want to run them against.\n";
    $answer = prompt( 'Do you want to enter test DB info?', 'no' );
}#else

# request new info from user
if ( $answer =~ /^y/i ) {
    while ( my ( $db, $name ) = each( %db_list ) ) {
        $answer = prompt( "Enter $name test DB info?", 'no' );
        if ( $answer =~ /^y/i ) {
            $DBINFO{"${db}_host"} = prompt( "Enter $name test DB host", $DBINFO{"${db}_host"} || 'localhost' );
            $DBINFO{"${db}_db"} = prompt( "Enter $name test DB name", $DBINFO{"${db}_db"} || 'test' );
            $DBINFO{"${db}_user"} = prompt( "Enter $name test DB user", $DBINFO{"${db}_user"} || 'test' );
            $DBINFO{"${db}_pass"} = prompt( "Enter $name test DB pass", $DBINFO{"${db}_pass"} || '' );

            # Oracle hack, users are almost always uppercase
            $DBINFO{"${db}_user"} = uc( $DBINFO{"${db}_user"} );
        }#if
    }#foreach
    # write out changes
    open( OUTF, '>t/dbinfo' );
        foreach my $key ( sort keys %DBINFO ) {
            print OUTF "$key=$DBINFO{$key}\n";
        }#foreach
    close( INF );
}#if

WriteMakefile(
    NAME         => 'Cosmic::DB',
    VERSION_FROM => 'lib/Cosmic/DB.pm', # finds \$VERSION
    AUTHOR       => 'Lyle Hopkins (cosmicnet@cpan.org)',
    ABSTRACT     => 'Lightweight SQL generation, portable across Oracle, MySQL, Postgres & SQL Server',
    PREREQ_PM    => {
        'Test::Simple'  => 0.44,
        'DBI'           => 0,
		'Test::More'	=> 0,
		'Test::Deep'	=> 0,
    },
);
