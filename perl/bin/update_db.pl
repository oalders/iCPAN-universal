#!/usr/bin/env perl

use Data::Dump qw( dump );
use ElasticSearch;
use Find::Lib '../lib';
use Getopt::Long::Descriptive;
use Modern::Perl;
use Scalar::Util qw( reftype );
use iCPAN;

my ( $opt, $usage ) = describe_options(
    'update_db %o <some-arg>',
    [ 'table=s', "table name (authors|modules|distributions)" ],
    [ 'debug',        "print debugging info" ],

    [],
    [ 'help', "print usage message and exit" ],
);

print($usage->text), exit if $opt->help;

my $icpan = iCPAN->new;
$icpan->db_file( '../iCPAN.sqlite' );
$icpan->search_prefix("");
$icpan->dist_search_prefix("");
$icpan->purge(1);
my $schema = $icpan->schema;

if ( $opt->{debug} ) {
    say dump( $schema );    
}


my $method =  'insert_' . $opt->{table};
if ( $opt->{table} eq 'authors' ) {
#    $icpan->server('hostingmirror1.wundersolutions.com:9200');
#    $icpan->index('cpan');    
}

$icpan->$method;
