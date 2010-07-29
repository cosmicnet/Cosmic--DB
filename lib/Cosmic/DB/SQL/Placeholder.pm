package Cosmic::DB::SQL::Placeholder;
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self;
}#sub

sub sql {
    return '?';
}#sql


1;
