package iCPAN;

use Data::Dump qw( dump );
use ElasticSearch;
use Modern::Perl;
use Moose;

with 'iCPAN::Role::DB';
with 'iCPAN::Role::Common';

use iCPAN::Schema;

has 'es' => ( is => 'rw', isa => 'ElasticSearch', lazy_build => 1 );

sub _build_es {

    return ElasticSearch->new(
        servers      => 'localhost:9201',
        transport    => 'httplite',
        max_requests => 0,                  # default 10_000
        trace_calls  => 'log_file',
        no_refresh   => 1,
    );

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
        
        #last if scalar @hits > 100;

    }

    return \@hits;
}

sub insert_authors {

    my $self = shift;
    my $author_rs = $self->schema->resultset( 'Zauthor' );
    $author_rs->delete;
    
    my $result = $self->es->search(
        index => 'cpan',
        type  => 'author',
        query => {
            #term    => { pauseid => 'OALDERS' },
            match_all => {},
        },
        scroll => '5m',
        size   => 500,
    );
    
    my $hits    = $self->scroll( $result );
    my @authors = ();
    
    say "found " . scalar @{$hits} . " hits";
    
    foreach my $src ( @{$hits} ) {
        say dump $src;
        push @authors,
            {
            zpauseid => $src->{pauseid},
            zname    => (!reftype $src->{name}) ? $src->{name} : undef,
            zemail   => shift @{ $src->{email} },
            };
    }
    
    return $author_rs->populate( \@authors );
    
}


sub insert_modules {

    my $self = shift;
    my $rs = $self->schema->resultset( 'Zmodule' );
    $rs->delete;
    
    my $result = $self->es->search(
        index => 'cpan',
        type  => ['release'],
        query => {
            term    => { status => 'latest' },
            #match_all => {},
        },
        scroll => '5m',
        size   => 10,
        explain => 0,
    );
    
    my $hits    = $self->scroll( $result );
    my @rows = ();
    
    say "found " . scalar @{$hits} . " hits";
    
    foreach my $src ( @{$hits} ) {
        say dump $src;
        return;
        push @rows,
            {
            zpauseid => $src->{pauseid},
            zname    => (!reftype $src->{name}) ? $src->{name} : undef,
            zemail   => shift @{ $src->{email} },
            };
    }
    
    return $rs->populate( \@rows );
    
}

1;
