#!/usr/bin/env perl

use Data::Dump qw( dump );
use ElasticSearch;
use Find::Lib '../lib';
use Modern::Perl;
use Scalar::Util qw( reftype );
use iCPAN;

my $icpan = iCPAN->new;
$icpan->db_file( 'iCPAN.sqlite' );
my $schema = $icpan->schema;

$icpan->index( 'cpan' );
#$icpan->insert_authors;

#my $inserts = $icpan->insert_distributions;
#say dump( $inserts ) . " distributions inserted";

$icpan->insert_modules;

#say dump $schema;
