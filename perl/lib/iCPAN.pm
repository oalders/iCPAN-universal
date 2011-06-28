package iCPAN;

use CHI;
use Data::Dump qw( dump );
use ElasticSearch;
use Modern::Perl;
use Moose;
use Parallel::ForkManager;
use WWW::Mechanize;
use WWW::Mechanize::Cached;

with 'iCPAN::Role::DB';
with 'iCPAN::Role::Common';

use iCPAN::Schema;

# ssh -L 9201:localhost:9200 metacpan@api.beta.metacpan.org -p222 -N

has 'es'       => ( is => 'rw', isa => 'ElasticSearch', lazy_build => 1 );
has 'children' => ( is => 'rw', isa => 'Int',           default    => 2 );
has 'index' => ( is => 'rw', default => 'v0' );
has 'mech' =>
    ( is => 'rw', isa => 'WWW::Mechanize::Cached', lazy_build => 1 );
has 'pod_server' =>
    ( is => 'rw', default => 'http://localhost:5000/podpath/' );
has 'search_prefix' => ( is => 'rw', isa => 'Str', default => 'DBIx::Class' );
has 'dist_search_prefix' =>
    ( is => 'rw', isa => 'Str', default => 'DBIx-Class' );
has 'limit'       => ( is => 'rw', isa => 'Int', default => 100000 );
has 'purge'       => ( is => 'rw', isa => 'Int', default => 0 );
has 'scroll_size' => ( is => 'rw', isa => 'Int', default => 1000 );
has 'server' => ( is => 'rw', default => 'api.beta.metacpan.org:80' );

my @ROGUE_DISTRIBUTIONS
    = qw(kurila perl_debug perl-5.005_02+apache1.3.3+modperl pod2texi perlbench spodcxx);

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

    my $self = shift;

    my $folder = "$ENV{HOME}/tmp/iCPAN";
    my $cache  = CHI->new(
        driver     => 'FastMmap',
        root_dir   => $folder,
        cache_size => '800m'
    );

    my $mech = WWW::Mechanize::Cached->new( autocheck => 0, cache => $cache );

    #my $mech = WWW::Mechanize->new( autocheck => 0 );
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

        #say dump $hits[-1];
        #say @hits . ' results so far';

        last if scalar @hits > $limit;

    }

    return \@hits;
}

sub insert_authors {

    my $self = shift;
    my $rs   = $self->schema->resultset( 'Zauthor' );
    if ( $self->purge ) {
        $rs->delete;
        $self->schema->storage->dbh->do( "VACUUM" );
    }

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
    $rs->delete if $self->purge;

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
        scroll  => '30m',
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

    $rs->populate( \@rows ) if @rows;
    $self->update_ent( $rs, $ent );
    return;

}

sub insert_modules {

    my $self = shift;
    my $rs   = $self->init_rs( 'Zmodule' );

    my $scroller = $self->module_scroller;

    my $ent = $self->get_ent( 'Module' );

    my $pm   = new Parallel::ForkManager( $self->children );
    my @hits = ();
    my @rows = ();
    while ( my $result = $scroller->next ) {

        push @rows, $result;

        if ( scalar @rows >= 100 ) {
            my @todo = @rows;
            @rows = ();
            $pm->start and next;    # fork
            $self->module_hits( \@todo, $ent, $rs );
            $pm->finish;
        }

    }

    $pm->wait_all_children;

    if ( scalar @rows > 0 ) {
        $self->module_hits( \@rows, $ent, $rs );
    }

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

sub module_hits {

    my $self = shift;
    my $hits = shift;
    my $ent  = shift;
    my $rs   = shift;

    my @rows = ();

    foreach my $result ( @{$hits} ) {

        my $src = $self->extract_hit( $result );
        next if !$src;

        #say dump $src;
        say sprintf( "%s: %s (%s)",
            $src->{distribution}, $src->{documentation}, $src->{date} );

        my $pod_url = $self->pod_server
            . join( "/", $src->{author}, $src->{release}, $src->{path} );

        say "GETting: $pod_url";

        my $pod
            = $self->mech->get( $pod_url )->is_success
            ? $self->mech->content
            : undef;

        if ( !$pod ) {
            say "no pod found.  skipping!!!";
            next;
        }

        # TODO why are there multiple dists with the same name in this table. 
        my $dist = $self->schema->resultset( 'Zdistribution' )
            ->search( { zname => $src->{distribution} } )->first;

        # doing a find_or_create for each row would be too many extra selects
        if ( !$dist ) {
            $dist = $self->schema->resultset( 'Zdistribution' )->create(
                {   zauthor       => $src->{author},
                    zrelease_date => $src->{date},
                    zname         => $src->{distribution},
                    zversion      => $src->{version_numified},
                    zabstract     => $src->{abstract}
                }
            );
        }

        my $insert = {
            z_ent         => $ent->z_ent,
            z_opt         => 1,
            zabstract     => $src->{'abstract.analyzed'},
            zdistribution => $dist->z_pk,
            zname         => $src->{documentation},
            zpod          => $pod,
        };
        push @rows, $insert;

    }

    $rs->populate( \@rows ) if @rows;
    say "inserted " . @rows . " modules";
    say "total inserts: " . $rs->search( {} )->count;

    return;

}

sub module_scroller {

    my $self = shift;
    return $self->es->scrolled_search(
        index => $self->index,
        type  => ['file'],

        query => { "match_all" => {} },

        filter => {
            and => [
                {   not => {
                        filter => {
                            or => [
                                map {
                                    { term => { 'file.distribution' => $_ } }
                                    } @ROGUE_DISTRIBUTIONS
                            ]
                        }
                    }
                },
                { term => { status => 'latest' } },
                {   or => [

                        # we are looking for files that have no authorized
                        # property (e.g. .pod files) and files that are
                        # authorized
                        { missing => { field => 'file.authorized' } },
                        { term => { 'file.authorized' => \1 } },
                    ]
                },
                {   or => [
                        {   and => [
                                { exists => { field => 'file.module.name' } },
                                { term => { 'file.module.indexed' => \1 } }
                            ]
                        },
                        {   and => [
                                { exists => { field => 'documentation' } },
                                { term => { 'file.indexed' => \1 } }
                            ]
                        }
                    ]
                }
            ]
        },

        sort   => [ { "date" => "desc" } ],
        fields => [
            "abstract.analyzed", "documentation",
            "distribution",      "date",
            "author",            "release",
            "path"
        ],
        scroll  => '15m',
        size    => $self->scroll_size,
        explain => 0,
    );

}

sub init_rs {

    my $self = shift;
    my $name = shift;
    my $rs   = $self->schema->resultset( $name );

    if ( $self->purge ) {
        $rs->delete;
        $self->schema->storage->dbh->do( "VACUUM" );
    }

    return $rs;
}

1;

=pod

=head2 init_rs( $dbic_table_name )

Truncates table if required.  Returns a resultset for the table.

=cut
