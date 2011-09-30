# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use Test::More tests => 6;

BEGIN {
    use_ok( 'Cosmic::DB', 'Loading Cosmic::DB' );
    use_ok( 'Cosmic::DB::SQL', 'Loading Cosmic::DB::SQL' );
    use_ok( 'Cosmic::DB::Schema', 'Loading Cosmic::DB::Schema' );
}

my $object = Cosmic::DB->new ();
isa_ok ($object, 'Cosmic::DB', 'Cosmic::DB Object created');
$object = Cosmic::DB::SQL->new ( bless {}, 'DBI::db' ); # Fake dbh
isa_ok ($object, 'Cosmic::DB::SQL', 'Cosmic::DB::SQL Object created');
$object = Cosmic::DB::Schema->new ( bless {}, 'DBI::db' ); # Fake dbh
isa_ok ($object, 'Cosmic::DB::Schema', 'Cosmic::DB::Schema Object created');
