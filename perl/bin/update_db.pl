#!/usr/bin/env perl

use Data::Dump qw( dump );
use ElasticSearch;
use Modern::Perl;
use Scalar::Util qw( reftype );
use iCPAN;

my $icpan = iCPAN->new;
$icpan->db_file( 'iCPAN.sqlite' );
my $schema = $icpan->schema;

#$icpan->insert_authors;

$icpan->insert_modules;


#say dump $schema;
