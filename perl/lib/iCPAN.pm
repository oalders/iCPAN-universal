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

sub _build_es {

    return ElasticSearch->new(
        servers      => 'api.beta.metacpan.org:80',
        transport    => 'httplite',
        max_requests => 0,                            # default 10_000
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

    my $self   = shift;
    my $result = shift;
    my @hits   = ();

    while ( 1 ) {

        my $hits = $result->{hits}{hits};

        last unless @$hits;    # if no hits, we're finished

        say "found " . scalar @{$hits} . " hits";

        foreach my $hit ( @{$hits} ) {
            push @hits, $hit->{'_source'};
        }

        $result = $self->es->scroll(
            scroll_id => $result->{_scroll_id},
            scroll    => '5m'
        );

        last if scalar @hits > 10;

    }

    return \@hits;
}

sub insert_authors {

    my $self      = shift;
    my $author_rs = $self->schema->resultset( 'Zauthor' );
    $author_rs->delete;

    my $result = $self->es->search(
        index  => $self->index,
        type   => 'author',
        query  => { match_all => {}, },
        scroll => '5m',
        size   => 10,
    );

    my $hits    = $self->scroll( $result );
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

    my $result = $self->es->search(
        index => $self->index,
        type  => ['release'],
        query => {
            term => { status => 'latest' },

            #match_all => {},
        },
        scroll  => '5m',
        size    => 100,
        explain => 0,
    );

    my $hits = $self->scroll( $result );
    my @rows = ();

    say "found " . scalar @{$hits} . " hits";

    foreach my $src ( @{$hits} ) {
        say dump $src;

        #return;
        push @rows,
            {
            zabstract => $src->{abstract},
            zversion  => $src->{version_numified},
            zname     => $src->{name},
            };
    }

    return $rs->populate( \@rows );

}

sub insert_modules {

    my $self = shift;
    my $rs   = $self->schema->resultset( 'Zmodule' );
    $rs->delete;

    my $result = $self->es->search(
        index => $self->index,
        type  => ['file'],

        query    => { "match_all" => {} },
        "filter" => {
            "and" => [
                { "exists" => { "field"       => "file.documentation" } },
                { "term"   => { "file.status" => "latest" } }
            ]
        },

        #"fields" => [ "documentation", "author", "release", "distribution" ],
        scroll  => '5m',
        size    => 10,
        explain => 0,
    );

    my $hits = $self->scroll( $result );
    my @rows = ();

    say "found " . scalar @{$hits} . " hits";

    foreach my $src ( @{$hits} ) {
        say dump $src;

        #return;
        #exit;
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

        push @rows,
            {
            zabstract => $src->{abstract},
            zname     => $src->{documentation},
            zpod      => $pod,
            distribution => $src->{distribution},
            };

        say "dumping last row: " . dump $rows[-1];
    }

    say dump( \@rows );

    #return $rs->populate( \@rows );
    return \@rows;
}

1;
