# vim: ts=4 sw=4 expandtab smarttab smartindent autoindent cindent
package Nour::Logger;
# ABSTRACT: a mixin module for logging, mostly just wraps Mojo::Log

use Moose;
use namespace::autoclean;
use Mojo::Log;
use Data::Dumper qw//;
use Carp; $Carp::Verbose = 1;
use feature ':5.10';

with 'Nour::Base';

=head1 NAME

Nour::Logger

=cut

has _logger => (
    is => 'rw'
    , isa => 'Mojo::Log'
    , handles => [ qw/debug error fatal info log warn/ ]
    , default => sub {
        my $log = new Mojo::Log ( level => 'debug' );
        $log->unsubscribe( 'message' );
        $log->on( message => sub {
            my ( $log, $level, @line, $tstamp ) = @_;
            $tstamp = time;
            say "[$tstamp] [$level] ", join ' ', @line;
        } );
        return $log;
    }
);

sub mojo { return shift->_logger } # return the Mojo::Log object

do {
    my $method = $_;
    around $method => sub {
        my ( $next, $self, @args ) = @_;

        return $self if $method eq 'log' and not @args; # return the Nour::Logger object
        my $dumped = $self->_dumper( pop @args ) if ref $args[ -1 ];
        push @args, $dumped if $dumped;

        return $self->$next( @args );
    };
} for qw/debug error fatal info log warn/;

after fatal => sub {
    my ( $self, @args ) = @_;
    croak @args;
};

sub _dumper {
    my $self = shift;
    my $dump = Data::Dumper->new( [ @_ ] )->Indent( 1 )->Sortkeys( 1 )->Terse( 1 )->Dump;
    $dump =~ s/(?:[\r\n\s]+$)//g;
    return $dump;
}

__PACKAGE__->meta->make_immutable;

1;
__END__
