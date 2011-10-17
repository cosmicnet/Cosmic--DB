package Cosmic::DB::SQL::MySQL;
use strict;
use warnings;
use Carp;

use base 'Cosmic::DB::SQL::Generic';

sub merge_replace {
    my $self = shift;
    my ( $table, $columns, $values ) = @_;
    croak( 'Missing table from insert' ) unless defined $table;
    croak( 'Missing columns from insert' ) unless ref $columns eq 'ARRAY';
    croak( 'Missing values from insert' ) unless $values;
    # Populate list of placeholders
    if ( $values eq '?' ) {
        $values = [ map { \'?' } @$columns ];
    }#if
    $self->{sql} .= 'REPLACE INTO ' . $self->_quote_table($table) . ' (' . join(',', map { $self->_quote_column($_) } @$columns) . ') ';
    if ( ref $values eq 'ARRAY' ) {
        $self->{sql} .= 'VALUES (' . join(',', map { $self->_quote_value($_) } @$values) . ') ';
    }
    else {
        $self->{sql} .= $values;
    }
    return $self;
}#sub


1;
