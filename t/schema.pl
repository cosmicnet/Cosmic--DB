#!/usr/bin/perl -w
use strict;
use warnings;


# Example schema creating table with numeric types
our $schema_numeric = {
    test_numeric => {
        columns => [
            {
                name    => 'col_smallint',
                type    => 'smallint',
            },
            {
                name    => 'col_int',
                type    => 'int',
            },
            {
                name    => 'col_bigint',
                type    => 'bigint',
            },
            {
                name    => 'col_real',
                type    => 'real',
            },
            {
                name    => 'col_double',
                type    => 'double',
            },
        ],
    },
};

# Character types
our $schema_strings = {
    test_strings => {
        columns => [
            {
                name    => 'col_char',
                type    => 'char',
            },
            {
                name    => 'col_minchar',
                type    => 'char',
                size    => 1,
            },
            {
                name    => 'col_maxchar',
                type    => 'char',
                size    => 255,
            },
            {
                name    => 'col_varchar',
                type    => 'varchar',
            },
            {
                name    => 'col_minvarchar',
                type    => 'varchar',
                size    => 1,
            },
            {
                name    => 'col_maxvarchar',
                type    => 'varchar',
                size    => 2000,
            },
            {
                name    => 'col_text',
                type    => 'text',
            },
        ],
    },
};


# Date types
our $schema_dates = {
    test_dates => {
        columns => [
            {
                name    => 'col_date',
                type    => 'date',
            },
            {
                name    => 'col_time',
                type    => 'time',
            },
            {
                name    => 'col_timestamp',
                type    => 'timestamp',
            },
        ],
    },
};


# Misc settings
our $schema_misc = {
    test_misc => {
        columns => [
            {
                name    => 'col_notnull',
                type    => 'int',
                null    => 0,
            },
            {
                name    => 'col_default',
                type    => 'int',
                default => 20,
            },
            {
                name    => 'col_unique',
                type    => 'int',
                unique  => 1,
            },
        ],
    },
};


# Serial
our $schema_serial = {
    test_serial => {
        columns => [
            {
                name    => 'col_serial',
                type    => 'serial',
            },
            {
                name    => 'col_extra',
                type    => 'int',
            },
        ],
    },
};


# Big Serial
our $schema_bigserial = {
    test_bigserial => {
        columns => [
            {
                name    => 'col_bigserial',
                type    => 'bigserial',
            },
            {
                name    => 'col_extra',
                type    => 'int',
            },
        ],
    },
};


# pk
our $schema_pk = {
    test_pk => {
        columns => [
            {
                name    => 'col_pk',
                type    => 'int',
                null    => 0,
            },
            {
                name    => 'col_extra',
                type    => 'int',
            },
        ],
        primary_key => [
            'col_pk',
        ],
    },
};


# pk multi
our $schema_pk_multi = {
    test_pk_multi => {
        columns => [
            {
                name    => 'col_pk1',
                type    => 'int',
                null    => 0,
            },
            {
                name    => 'col_pk2',
                type    => 'char',
                null    => 0,
            },
            {
                name    => 'col_extra',
                type    => 'int',
            },
        ],
        primary_key => [
            'col_pk1',
            'col_pk2',
        ],
    },
};


# index
our $schema_index = {
    test_index => {
        columns => [
            {
                name    => 'col_index',
                type    => 'int',
                null    => 0,
            },
            {
                name    => 'col_extra',
                type    => 'int',
            },
        ],
        indexes => [
            {
                name    => 'index_1',
                unique  => 0,
                columns => [
                    'col_index',
                ],
            },
        ],
    },
};


# index multi
our $schema_index_multi = {
    test_index_multi => {
        columns => [
            {
                name    => 'col_index1',
                type    => 'int',
                null    => 0,
            },
            {
                name    => 'col_index2',
                type    => 'char',
                null    => 0,
            },
            {
                name    => 'col_extra',
                type    => 'int',
            },
        ],
        indexes => [
            {
                name    => 'test_index_multi_index_1',
                unique  => 0,
                columns => [
                    'col_index1',
                ],
            },
            {
                name    => 'test_index_multi_index_2',
                unique  => 1,
                columns => [
                    'col_index1',
                    'col_index2',
                ],
            },
        ],
    },
};


# constraints
our $schema_constraints = {
    test_constraint_a => {
        columns => [
            {
                name    => 'col_serial_a',
                type    => 'serial',
            },
            {
                name    => 'col_extra',
                type    => 'int',
            },
        ],
    },
    test_constraint_b => {
        columns => [
            {
                name    => 'col_serial_b',
                type    => 'serial',
            },
            {
                name    => 'col_extra',
                type    => 'int',
            },
        ],
    },
    test_constraint_c => {
        columns => [
            {
                name    => 'col_serial_a',
                type    => 'int',
            },
            {
                name    => 'col_serial_b',
                type    => 'int',
            },
        ],
        constraints => {
            foreign => [
                {
                    name    => 'constraint_a',
                    columns => [
                        'col_serial_a',
                    ],
                    references => {
                        table => 'test_constraint_a',
                        columns => [
                            'col_serial_a',
                        ],
                    },
                    cascade => 0,
                },
                {
                    name    => 'constraint_b',
                    columns => [
                        'col_serial_b',
                    ],
                    references => {
                        table => 'test_constraint_b',
                        columns => [
                            'col_serial_b',
                        ],
                    },
                    cascade => 1,
                },
            ],
        },
    },
};


## Cosmic::DB::SQL sample schema

# Sample schema with multiple types
our $schema_sample = {
    test_sample => {
        columns => [
            {
                name    => 'col_smallint',
                type    => 'smallint',
            },
            {
                name    => 'col_int',
                type    => 'int',
            },
            {
                name    => 'col_bigint',
                type    => 'bigint',
            },
            {
                name    => 'col_real',
                type    => 'real',
            },
            {
                name    => 'col_double',
                type    => 'double',
            },
            {
                name    => 'col_char',
                type    => 'char',
            },
            {
                name    => 'col_varchar',
                type    => 'varchar',
            },
            {
                name    => 'col_text',
                type    => 'text',
            },
            {
                name    => 'col_date',
                type    => 'date',
            },
            {
                name    => 'col_time',
                type    => 'time',
            },
            {
                name    => 'col_timestamp',
                type    => 'timestamp',
            },
        ],
    },
};



1;
