package iCPAN;

use CHI;
use Data::Dump qw( dump );
use ElasticSearch;
use Modern::Perl;
use Moose;
use WWW::Mechanize::Cached;

with 'iCPAN::Role::DB';
with 'iCPAN::Role::Common';

use iCPAN::Schema;

# ssh -L 9201:localhost:9200 metacpan@api.beta.metacpan.org -p222 -N

has 'es' => ( is => 'rw', isa => 'ElasticSearch', lazy_build => 1 );
has 'index' => ( is => 'rw', default => 'v0' );
has 'mech' =>
    ( is => 'rw', isa => 'WWW::Mechanize::Cached', lazy_build => 1 );
has 'server' => ( is => 'rw', default => 'api.beta.metacpan.org:80' );

sub _build_es {

    my $self = shift;

    return ElasticSearch->new(
        servers      => $self->server,
        transport    => 'httplite',
        max_requests => 0,               # default 10_000
        trace_calls  => 'log_file',
        no_refresh   => 1,
    );

}

sub _build_mech {

    my $self  = shift;
    my $cache = CHI->new(
        driver   => 'File',
        root_dir => '/tmp/mech-example'
    );

    my $mech = WWW::Mechanize::Cached->new( autocheck => 0, cache => $cache );
    return $mech;

}

sub scroll {

    my $self     = shift;
    my $scroller = shift;
    my $limit    = shift || 100;
    my @hits     = ();

    while ( my $result = $scroller->next ) {

        push @hits, exists $result->{'_source'}
            ? $result->{'_source'}
            : $result->{fields};
        say dump $hits[-1];

        last if scalar @hits > $limit;

    }

    return \@hits;
}

sub insert_authors {

    my $self      = shift;
    my $author_rs = $self->schema->resultset( 'Zauthor' );
    $author_rs->delete;

    my $scroller = $self->es->scrolled_search(
        index  => $self->index,
        type   => 'author',
        query  => { match_all => {}, },
        scroll => '5m',
        size   => 100,
    );

    my $hits = $self->scroll( $scroller, 10000 );
    my @authors = ();

    say "found " . scalar @{$hits} . " hits";

    foreach my $src ( @{$hits} ) {
        say dump $src;
        push @authors,
            {
            zpauseid => $src->{pauseid},
            zname    => ( ref $src->{name} ) ? undef : $src->{name},
            zemail   => shift @{ $src->{email} },
            };
    }

    return $author_rs->populate( \@authors );

}

sub insert_distributions {

    my $self = shift;
    my $rs   = $self->schema->resultset( 'Zdistribution' );
    $rs->delete;

    my $scroller = $self->es->scrolled_search(
        index => $self->index,
        type  => ['release'],
        query => {
            term => { status => 'latest' },

            #match_all => {},
        },
        filter => { prefix => { distribution => "DBIx" } },
        fields => [
            'author', 'distribution', 'abstract', 'version_numified',
            'name',   'date'
        ],
        scroll  => '5m',
        size    => 100,
        explain => 0,
    );

    my $hits = $self->scroll( $scroller, 1000 );
    my @rows = ();

    say "found " . scalar @{$hits} . " hits";

    foreach my $src ( @{$hits} ) {
        say dump $src;

        my $author = $self->schema->resultset( 'Zauthor' )
            ->find( { zpauseid => $src->{author} } );
        if ( !$author ) {
            say "cannot find $src->{author}. skipping!!!";
            next;
        }

        push @rows,
            {
            zabstract     => $src->{abstract},
            zauthor       => $author->z_pk,
            zrelease_date => $src->{date},
            zversion      => $src->{version_numified},
            zname         => $src->{distribution},
            };
    }

    return $rs->populate( \@rows );

}

sub insert_modules {

    my $self = shift;
    my $rs   = $self->schema->resultset( 'Zmodule' );
    $rs->delete;
    
    my $size = 250;

    my $scroller = $self->es->scrolled_search(
        index => $self->index,
        type  => ['file'],

        query => { "match_all" => {} },

        "filter" => {
            "and" => [
                { "exists" => { "field"       => "file.documentation" } },
                { "term"   => { "file.status" => "latest" } },
                { "prefix" => { "file.documentation" => "DBIx::" } },
            ]
        },

        "fields" => [ "abstract.analyzed", "documentation", "distribution" ],
        scroll   => '5m',
        size     => $size,
        explain  => 0,
    );

    my @rows = ( );
    while ( my $result = $scroller->next ) {
        
        my $src = $self->extract_hit( $result );
        next if !$src;
        say dump $src;

        my $pod_url = "http://metacpan.org:5001/pod/" . $src->{documentation};
        say "GETting: $pod_url";

        my $pod
            = $self->mech->get( $pod_url )->is_success
            ? $self->mech->content
            : undef;

        if ( !$pod ) {
            say "no pod found.  skipping!!!";
            next;
        }

        my $dist = $self->schema->resultset( 'Zdistribution' )
            ->find( { zname => $src->{distribution} } );

        if ( !$dist ) {
            say "cannot find $src->{distribution}. skipping!!!";
            next;
        }

        push @rows,
            {
            zabstract     => $src->{'abstract.analyzed'},
            zdistribution => $dist->z_pk,
            zname         => $src->{documentation},
            zpod          => $pod,
            };

        if ( scalar @rows >= $size ) {
            say "inserting "  . scalar @rows . " rows";
            $rs->populate( \@rows );
            @rows = ( );
        }
    }

    say dump \@rows;

    return $rs->populate( \@rows ) if scalar @rows;
    return;

}

sub extract_hit {
    
    my $self = shift;
    my $result = shift;
    
    return exists $result->{'_source'}
            ? $result->{'_source'}
            : $result->{fields};
    
}

1;
