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
has 'pod_server' => ( is => 'rw', default => 'http://localhost:5000/pod/' );
has 'search_prefix' => ( is => 'rw', isa => 'Str', default => 'DBIx::Class' );
has 'dist_search_prefix' =>
    ( is => 'rw', isa => 'Str', default => 'DBIx-Class' );
has 'limit'       => ( is => 'rw', isa => 'Int', default => 100000 );
has 'scroll_size' => ( is => 'rw', isa => 'Int', default => 500 );
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
        root_dir => '/tmp/icpan'
    );

    my $mech = WWW::Mechanize::Cached->new( autocheck => 0, cache => $cache );

    #my $mech = WWW::Mechanize( autocheck => 0 );
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
        say @hits . ' results so far';

        last if scalar @hits > $limit;

    }

    return \@hits;
}

sub insert_authors {

    my $self = shift;
    my $rs   = $self->schema->resultset( 'Zauthor' );
    $rs->delete;

    my $scroller = $self->es->scrolled_search(
        index  => $self->index,
        type   => 'author',
        query  => { match_all => {}, },
        scroll => '5m',
        size   => 10000,
    );

    my $hits = $self->scroll( $scroller, 10000 );
    my @authors = ();

    say "found " . scalar @{$hits} . " hits";
    my $ent = $self->get_ent( 'Author' );

    foreach my $src ( @{$hits} ) {

        #say dump $src;
        push @authors,
            {
            z_ent    => $ent->z_ent,
            z_opt    => 1,
            zpauseid => $src->{pauseid},
            zname    => ( ref $src->{name} ) ? undef : $src->{name},
            zemail   => shift @{ $src->{email} },
            };
    }

    $rs->populate( \@authors );
    $self->update_ent( $rs, $ent );
    return;

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
        filter => { prefix => { distribution => $self->dist_search_prefix } },
        fields => [
            'author', 'distribution', 'abstract', 'version_numified',
            'name',   'date'
        ],
        scroll  => '5m',
        size    => 5000,
        explain => 0,
    );

    my $hits = $self->scroll( $scroller, $self->limit );
    my @rows = ();

    say "found " . scalar @{$hits} . " hits";

    my $ent = $self->get_ent( 'Distribution' );

    foreach my $src ( @{$hits} ) {

        #say dump $src;

        my $author = $self->schema->resultset( 'Zauthor' )
            ->find( { zpauseid => $src->{author} } );
        if ( !$author ) {
            say "cannot find $src->{author}. skipping!!!";
            next;
        }

        push @rows,
            {
            z_ent         => $ent->z_ent,
            z_opt         => 1,
            zabstract     => $src->{abstract},
            zauthor       => $author->z_pk,
            zrelease_date => $src->{date},
            zversion      => $src->{version_numified},
            zname         => $src->{distribution},
            };
    }

    $rs->populate( \@rows );
    $self->update_ent( $rs, $ent );
    return;

}

sub insert_modules {

    my $self = shift;
    my $rs   = $self->schema->resultset( 'Zmodule' );
    $rs->delete;

    my $scroller = $self->es->scrolled_search(
        index => $self->index,
        type  => ['file'],

        query => { "match_all" => {} },

        filter => {
            and => [
                { exists => { field         => "file.documentation" } },
                { term   => { "file.status" => "latest" } },
                {   not => {
                        filter => { term => { 'file.authorized' => \0 }, },
                    },
                },

     #                {   "prefix" =>
     #                        { "file.documentation" => $self->search_prefix }
     #                },
            ]
        },

        sort => [ { "date" => "desc" } ],
        fields  => [ "abstract.analyzed", "documentation", "distribution", "date" ],
        scroll  => '5m',
        size    => $self->scroll_size,
        explain => 0,
    );

    my $ent = $self->get_ent( 'Module' );

    my @rows = ();
    while ( my $result = $scroller->next ) {

        my $src = $self->extract_hit( $result );
        next if !$src;
        say dump $src;

        # exclude .pl, .t and other stuff that doesn't look to be a module
        next if $src->{documentation} =~ m{\.};

        # if the doc name looks nothing like the dist name, forget it
        next
            if (
            substr( $src->{documentation}, 0, 1 ) ne
            substr( $src->{distribution}, 0, 1 ) );

        my $pod_url = $self->pod_server . $src->{documentation};
        say scalar @rows . " GETting: $pod_url";

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
            z_ent         => $ent->z_ent,
            z_opt         => 1,
            zabstract     => $src->{'abstract.analyzed'},
            zdistribution => $dist->z_pk,
            zname         => $src->{documentation},
            zpod          => $pod,
            };

        if ( scalar @rows >= 50 ) {
            say "inserting " . scalar @rows . " rows";
            $rs->populate( \@rows );
            $self->update_ent( $rs, $ent );
            @rows = ();
        }
    }

    say dump \@rows;

    $rs->populate( \@rows ) if scalar @rows;
    $self->update_ent( $rs, $ent );

    return;

}

sub extract_hit {

    my $self   = shift;
    my $result = shift;

    return exists $result->{'_source'}
        ? $result->{'_source'}
        : $result->{fields};

}

sub get_ent {

    my $self  = shift;
    my $table = shift;

    return $self->schema->resultset( 'ZPrimarykey' )
        ->find( { z_name => $table } );

}

sub update_ent {

    my ( $self, $rs, $ent ) = @_;
    my $last = $rs->search( {}, { order_by => 'z_pk DESC' } )->first;
    $ent->z_max( $last->id );
    $ent->update;

}

1;
