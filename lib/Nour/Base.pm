# vim: ts=4 sw=4 expandtab smarttab smartindent autoindent cindent
package Nour::Base;
# ABSTRACT: just a base role

use FindBin;
use Moose::Role;
use namespace::autoclean;
use strict; use warnings;

=head1 NAME

Nour::Base

=cut


has base => (
    is => 'rw'
    , required => 1
    , lazy_build => 1
);

sub _build_base {
    my $self = shift;
    my $base = $FindBin::Bin;

    while ( $base and not -e "$base/lib" ) {
        $base =~ s!/[^/]+/?$!!;
    }

    return $base;
}

sub path {
    my ( $self, @path ) = @_;
    my ( $base ) = ( $self->base );
    return $path[0]
        if scalar @path eq 1    # if just one argument
       and $path[0] =~ qr/^\//  # and appears absolute
       and not -e "$base$path[0]" # and relative non-existence from the base
       and -e $path[0]          # and absolute existence
    ;
    @path = map { $_ =~ s/^\///; $_ =~ s/\/$//; $_ } @path;
    $base =~ s/\/$//;
    return join '/', $base, @path;
}

sub merge_hash {
    my $self = shift;
    my ( $ref_1, $ref_2 ) = @_;
    for my $key ( keys %{ $ref_2 } ) {
        if ( defined $ref_1->{ $key } ) {
            if ( ref $ref_1->{ $key } eq 'HASH' and ref $ref_2->{ $key } eq 'HASH' ) {
                $self->merge_hash( $ref_1->{ $key }, $ref_2->{ $key } );
            }
            else {
                $ref_1->{ $key } = $ref_2->{ $key };
            }
        }
        else {
            if ( ref $ref_2->{ $key } eq 'HASH' ) {
                my %ref_2_key = %{ $ref_2->{ $key } };
                $ref_1->{ $key } = \%ref_2_key;
            }
            else {
                $ref_1->{ $key } = $ref_2->{ $key };
            }
        }
    }
}

sub write_yaml {
    my ( $self, $path, $data ) = @_;
    my ( @path, $mkdir );

    $path = $self->path( $path );
    @path = split /\//, $path;
    pop @path;
    $mkdir = join '/', @path;

    system( qw/mkdir -p/, $mkdir );
    system( qw/cp/, $path, "$path.save" ) if -e $path and -s $path;

    DumpFile( $path, $data );
}


sub BUILD {}

1;
