package Cosmic::DB;
use strict;
use warnings;
use Carp;
use DBI;

BEGIN {
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    $VERSION     = '0.01';
}#BEGIN


=head1 NAME

Cosmic::DB - Lightweight SQL generation, portable across Oracle, MySQL, Postgres
& SQL Server

=head1 SYNOPSIS

    use Cosmic::DB;


=head1 DESCRIPTION

This module acts as a gateway to L<Cosmic::DB::Schema> and L<Cosmic::DB::SQL>,
providing some additional convenient functionality.

You may well wish to use your current DBI wrapper, such as L<DBIx::Simple>
and instantiate L<Cosmic::DB::Schema> and L<Cosmic::DB::SQL> directly.

=head1 USAGE


=head1 METHODS

=head2 new

Usage

    my $db = new Cosmic::DB( dsn => $DSN, user => $user, pass => $pass, attrs => \%attrs);
    my $dbclone = $db->new();
    my $dbcopy = $db->new( param => value, attrs => \%attrs);

Purpose   : Creates new Cosmic::DB instance, clones an existing instance
Parameters:

=over

    attrs => %attrs - passed to DBI connect, see L<DBI> for details
    debug = 0|1 - turn on debugging warnings
    debug_newline = "\n<br>" - for debugging newline characters
    prefix = STRING - used to prefix table names
    prefix = STRING - used to suffix table names

=back

An instance can be cloned by calling new against it. You can optionally pass new
params and attributes that will overwrite any existing ones for the clone. The
clone will still need to L</connect>

See Also  : L<DBI>

=cut

sub new {
    my $class = shift;
    my %params = @_;
    my %attrs = $params{attrs} ? %{ $params{attrs} } : ( AutoCommit => 1 );
    delete $params{attrs};
    if ( ref ($class) ) {
        %params = (
            %{ $class->{param} },
            %params,
        );
        %attrs = {
            %{ $class->{attrs} },
            %attrs,
        };
    }#if
    my $self = {
        connected => 0,
        param => \%params,
        attrs => \%attrs,
    };
    bless ($self, ref ($class) || $class);
    return $self;
}#new


=head2 connect

Usage

    $db->connect;
    $db->connect( $dbh );

Connects with details sent to new, or can optionally be given a DBH which it's
use instead. Returns true upon connection or croaks.

=cut

sub connect {
    my $self = shift;
    my $dbh = shift;
    # Connect to DB if we aren't already connected
    unless ($self->{connected}) {
        if ( $dbh ) {
            $self->{dbh} = $dbh;
        }#if
        else {
            carp "Connecting to DB with $self->{param}->{dsn}, $self->{param}->{user}, $self->{param}->{pass}$self->{param}->{debug_newline}" if $self->{param}->{debug};
            $self->{dbh} = DBI->connect( $self->{param}->{dsn}, $self->{param}->{user}, $self->{param}->{pass}, { %{ $self->{attrs} } } )
                || croak("Cannot connect to database: $DBI::errstr\n");
            $self->{connected} = 1;
        }#else
        # Create SQL generation object
        $self->{sql} = new JustWork::DB::SQL($self->{dbh});
    }#unless
    return $self->{connected};
}#sub


=head2 disconnect

Usage
    $db->disconnect;

Disconnects the database connection.

=cut

sub disconnect {
    my $self = shift;
    $self->{dbh}->disconnect;
    $self->{connected} = 0;
}#sub

=head2 insert

Usage

    $db->insert( $table, \@columns, \@data );
    $db->insert( $table, \@columns, \%data );
    $db->insert( $table, \%data );
    $db->insert( $table, \@columns, [ \@data, \@data, ... ] );
    $db->insert( $table, \@columns, [ \%data, \%data, ... ] );
    $db->insert( $table, [ \%data, \%data, ... ] );

Purpose   : Inserts \@data into the \@columns of $table
Parameters:

=over

    $table = STRING - name of the table
    \@columns = LIST - array reference to column names
    \@data = LIST - array reference to values
    \%data = HASH - hash reference to values keyed by column names

=back

Uses do for single inserts, or prepare and a loop for multiple. If columns is
ommitted and %data is a hash (or arrary ref of hashes) then the hash keys are
used as the columns. If %data is a hash and columns is passed, then other hash
keys are ignored.

=cut

sub insert {
    my ( $self, $table, $columns, $data ) = @_;
    $self->{success} = 0;
    $table = "$self->{param}->{prefix}$table$self->{param}->{suffix}";

    # See if columns is actually data and columns need to be generated
    if ( ref( $columns ) eq 'HASH' ) {
        $data = $columns;
        $columns = [ keys %$data ];
    }#if
    if ( ref( $columns ) eq 'ARRAY' && ref( $columns->[0] ) eq 'HASH' ) {
        $data = $columns;
        $columns = [ keys %{ $data->[0] } ];
    }#if

    # Create values for insert
    my $values = [];
    if ( ref( $data ) eq 'ARRAY' ) {
        $values = $data;
    }#if
    elsif ( ref( $data ) eq 'HASH' ) {
        foreach my $column (@$columns) {
            push( @$values, $data->{$column} );
        }#foreach
    }#else

    # Check for multiple insert
    if ( ref( $values->[0] ) ) {
        my $sql = $self->{sql}->sql->insert($table, @$columns, '?')->sql;
        my $sth = $self->{dbh}->prepare($sql);
        if ( ref( $values->[0] ) eq 'ARRAY' ) {
            foreach my $values ( @$data ) {
                $sth->execute(@$values) && {$self->{success} = 1} || croak("Cannot insert to $table: SQL = $sql VALUES = @$values\n $DBI::errstr\n");
                carp "SQL $sql VALUES @$values$self->{param}->{debug_newline}" if $self->{param}->{debug};
            }#foreach
        }#if
        elsif ( ref( $data->[0] ) eq 'HASH' ) {
            foreach my $valuehash ( @$data ) {
                my @values;
                foreach my $column (@$columns) {
                    push( @values, $valuehash->{$column} );
                }#foreach
                $sth->execute(@values) && {$self->{success} = 1} || croak("Cannot insert to $table: SQL = $sql VALUES = @values\n $DBI::errstr\n");
                carp "SQL $sql VALUES @$values$self->{param}->{debug_newline}" if $self->{param}->{debug};
            }#foreach
        }#else
        $sth->finish();
    }#if
    else {
        my $sql = $self->{sql}->sql->insert($table, @$columns, @$values)->sql;
        $self->{dbh}->do($sql) && {$self->{success} = 1} || croak("Cannot insert to $table: SQL = $sql\n $DBI::errstr\n");
        carp "SQL $sql $self->{param}->{debug_newline}" if $self->{param}->{debug};
    }#else
    return $self->{success};
}#sub


=head2 delete

Usage

    $db->delete( $table, \%where );
    $db->delete( $table, \%where, \@values );

Purpose   : Deletes rows from $table where %where is true for @values
Parameters:

=over

    $table = STRING - name of the table
    \%where = HASH - a L<Cosmic::DB::SQL/where> where hash
    \@values = LIST - list of values to replace placeholders

=back

Uses do for single deletes, or prepare and a loop for multiple. Values must
contain arrayref of arrayrefs if used.

=cut

sub delete {
    my ( $self, $table, $where, $values ) = @_;
    $self->{success} = 0;
    $table = "$self->{param}->{prefix}$table$self->{param}->{suffix}";
    my $sql = $self->{sql}->sql->delete->from($table)->where( $where )->sql; #$where->{left},$where->{comp},$where->{right} )->sql;
    if ($values) {
        my $sth = $self->{dbh}->prepare($sql);
        if ( ref( $values->[0] ) eq 'ARRAY' ) {
            foreach my $value ( @$values ) {
                $sth->execute(@$value) && {$self->{success} = 1} || croak("Cannot insert to $table: SQL = $sql VALUES = @$value\n $DBI::errstr\n");
                carp "SQL $sql VALUES @$value$self->{param}->{debug_newline}" if $self->{param}->{debug};
            }#foreach
        }#if
    }#if
    else {
        $self->{dbh}->do($sql) && {$self->{success} = 1} || croak("Cannot delete from $table: SQL = $sql\n $DBI::errstr\n");
        carp "SQL $sql$self->{param}->{debug_newline}" if $self->{param}->{debug};
    }#if
    return $self->{success};
}#sub


=head2 update

Usage

    $db->update( $table, \@columns, \@data, \%where );
    $db->update( $table, \@columns, \%data, \%where );
    $db->update( $table, \%data, \%where );
    $db->update( $table, \@columns, [ \@data, \@data, ... ], \%where );
    $db->update( $table, \@columns, [ \%data, \%data, ... ], \%where );
    $db->update( $table, [ \%data, \%data, ... ], \%where );

Purpose   : Updates \@data into the \@columns of $table where %where is true
Parameters:

=over

    $table = STRING - name of the table
    \@columns = LIST - array reference to column names
    \@data = LIST - array reference to values
    \%data = HASH - hash reference to values keyed by column names
    \%where = HASH - a L<Cosmic::DB::SQL/where> where hash

=back

Uses do for single upates, or prepare and a loop for multiple. If columns is
ommitted and %data is a hash (or arrary ref of hashes) then the hash keys are
used as the columns. If %data is a hash and columns is passed, then other hash
keys are ignored.

=cut

sub update {
    my ( $self, $table, $columns, $data, $where ) = @_;
    $self->{success} = 0;
    $table = "$self->{param}->{prefix}$table$self->{param}->{suffix}";
    my $sql = $self->{sql}->sql->update($table);

    # See if columns is actually data and columns need to be generated
    if ( ref( $columns ) eq 'HASH' ) {
        $data = $columns;
        $columns = [ keys %$data ];
    }#if
    if ( ref( $columns ) eq 'ARRAY' && ref( $columns->[0] ) eq 'HASH' ) {
        $data = $columns;
        $columns = [ keys %{ $data->[0] } ];
    }#if

    # Create values for update
    my $values = [];
    if ( ref( $data ) eq 'ARRAY' ) {
        $values = $data;
    }#if
    elsif ( ref( $data ) eq 'HASH' ) {
        foreach my $column (@$columns) {
            push( @$values, $data->{$column} );
        }#foreach
    }#else

    # Check for multiple update
    if ( ref( $values->[0] ) ) {
        $sql = $sql->set( map { $_ => '?' } @$columns )->where( $where )->sql;
        my $sth = $self->{dbh}->prepare($sql);
        if ( ref( $values->[0] ) eq 'ARRAY' ) {
            foreach my $values ( @$data ) {
                $sth->execute(@$values) && {$self->{success} = 1} || croak("Cannot update $table: SQL = $sql VALUES = @$values\n $DBI::errstr\n");
                carp "SQL $sql VALUES @$values$self->{param}->{debug_newline}" if $self->{param}->{debug};
            }#foreach
        }#if
        elsif ( ref( $data->[0] ) eq 'HASH' ) {
            foreach my $valuehash ( @$data ) {
                my @values;
                foreach my $column (@$columns) {
                    push( @values, $valuehash->{$column} );
                }#foreach
                $sth->execute(@values) && {$self->{success} = 1} || croak("Cannot update $table: SQL = $sql VALUES = @values\n $DBI::errstr\n");
                carp "SQL $sql VALUES @$values$self->{param}->{debug_newline}" if $self->{param}->{debug};
            }#foreach
        }#else
        $sth->finish();
    }#if
    else {
        $sql = $sql->set( map { $columns->[$_] => $values->[$_] } 0..$#{$columns} )->where( $where )->sql;
        $self->{dbh}->do($sql) && {$self->{success} = 1} || croak("Cannot update $table: SQL = $sql\n $DBI::errstr\n");
        carp "SQL $sql $self->{param}->{debug_newline}" if $self->{param}->{debug};
    }#else
    return $self->{success};
}#sub


=head1 INTERNAL FUNCTIONS


=head1 BUGS

Use RT, or you'll probably get a better responce on the mailing list.

=head1 SUPPORT

Mailing list coming soon

=head1 AUTHOR

    Lyle Hopkins
    CPAN ID: cosmicnet
    Bristol & Bath Perl Moungers
    cosmicnet@cpan.org
    http://perl.bristolbath.org

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

perl(1).

=cut


1;
