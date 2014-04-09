# vim:ts=4 sw=4 expandtab smarttab smartindent autoindent cindent
package Nour::Script; use strict; use warnings;
# ABSTRACT: script bootstrap

use Moose::Role; with 'Nour::Base';
use namespace::autoclean;
use String::CamelCase qw/decamelize/;
use Getopt::Long qw/:config pass_through/;
use Pod::Usage;

use Nour::Logger;
use Nour::Config;
use Nour::Database;
use String::CamelCase qw/camelize decamelize/;

has _logger => (
    is => 'rw'
    , isa => 'Nour::Logger'
    , handles => [ qw/debug error fatal info log warn/ ]
    , required => 1
    , lazy => 1
    , default => sub {
        return new Nour::Logger;
    }
);

has _config => (
    is => 'rw'
    , isa => 'Nour::Config'
    , handles => [ qw/config/ ]
    , required => 1
    , lazy => 1
    , default => sub {
        my $self = shift;
        my $conf = new Nour::Config ( -base => $self->_config_path );
        case_exception: {
            if ( -e $self->_config_path_auto .'.yml' and not -d $self->_config_path_auto ) {
                my $name = pop @{ [ split /\//, $self->_config_path_auto ] };
                my %conf = %{ delete $conf->config->{ $name } };
                delete $conf->config->{ $_ } for keys %{ scalar $conf->config };
                $conf->config( \%conf );
            }
        };
        return $conf;
    }
);
sub _config_path_auto {
    my $self = shift;
    my $path = $self->path( qw/config/, map { decamelize $_ } split /::/, ref $self );
       $path =~ s/\/$//;
    return $path;
}
has _config_path => (
    is => 'rw'
    , isa => 'Str'
    , lazy => 1
    , required => 1
    , default => sub {
        my $self = shift;
        my $path =  $self->_config_path_auto;
        return $path if -d $path; # use ./config/whatever/package as the base if that exists
        my @path = split /\//, $path;
        my $file = pop( @path ) .'.yml';
           $path = join '/', @path;
        return $path if -d $path and -e "$path/$file"; # or use ./config/whatever/ as the base if ./config/whatever/package.yml exists
        return $self->path( 'config' ); # otherwise use ./config/ as the base
    }
);
has option => (
    is => 'rw'
    , isa => 'HashRef'
    , required => 1
    , lazy => 1
    , default => sub {
        my ( $self, %opts, %conf ) = @_;

        %conf = %{ $self->config->{option} } if exists $self->config->{option};
        $self->merge_hash( \%opts, $conf{default} ) if $conf{default};

        GetOptions( \%opts
            , qw/
                mode=s
                verbose+
                help|?
            /
            , silent => sub {
                $opts{verbose} = 0;
                $opts{silent}  = 1;
            }
            , $conf{getopts} ? @{ $conf{getopts} } : ()
        ) or pod2usage( 1 );

        pod2usage( 1 ) if $opts{help};

        return \%opts;
    }
);

do {
    my $method = $_;
    around $method => sub {
        my ( $next, $self, @args ) = @_;
        return $self->$next( @args ) unless $self->option->{silent};
        return $self->$next( @args ) if $method eq 'log' and not @args;
        return;
    };
} for qw/debug info log/;


has _database => (
    is => 'rw'
    , isa => 'Nour::Database'
    , handles => [ qw/db/ ]
    , lazy => 1
    , required => 1
    , default => sub {
        my $self = shift;
        my %conf = $self->config->{database} ? %{ $self->config->{database} } : (
            # default options here
        );
        $conf{ '-opts' }{database} = $self->option->{mode} if $self->option->{mode} and not grep {
            $_ eq '--database' # --database will get processed by nour::database
        } @ARGV;
        $conf{ '-opts' }{log} = $self->log->mojo unless $self->option->{silent}; #_logger->_logger;
        return new Nour::Database ( %conf );
    }
);

before run => sub {
    my $self = shift;
    $self->info( ref $self );
    if ( -e $self->_config_path_auto .'.yml' ) {
        $self->debug( 'config found in '. $self->_config_path_auto .'.yml', $self->config );
    }
    elsif ( -d $self->_config_path and keys %{ scalar $self->config } ) {
        $self->debug( 'config found in '. $self->_config_path, $self->config );
    }
    else {
        $self->debug( 'config not found; if you want to decouple config from code, you should place your YAML configuration in one of these places:' );
        $self->debug( '- '. $self->_config_path_auto .'.yml' );
        $self->debug( '- '. $self->_config_path_auto .'/' );
        $self->debug( '- '. $self->path( 'config' ) .'/' );
    }
    $self->debug( 'options', $self->option ) if keys %{ $self->option };
};

after run => sub {
    my $self = shift;
    $self->info( ref( $self ) .' finished' );
};

1;
__END__

=head1 NAME

Nour::Script

=head1 SYNOPSIS

Here's the quickest example:

    #!/usr/bin/env perl

    {
        package Script::Generate;
        use Moose; with 'Nour::Script';

        sub run {
            my ( $self ) = @_;
            $self->debug( 'testing' );
        }

        1;
    }

    Script::Generate->new->run;

=head1 USAGE

=head2 Configuration setup

No documentation here yet, uses L<Nour::Config>.

=head2 Command-line options

In your script configuration, include an 'option' hash with two properties:
- getopts: an array of defined options (using L<Getopt::Long> syntax)
- default: a hash of default values for the defined options

here's an example:

    ---
    other: configuration
    stuff: bananas
    option:
        getopts:
            - source=s
            - target:s
            - width:i
            - bigger+
            - crop
            - force!
        default:
            force: 1

Configuration goes in either ./config/your/package/name/ or ./config/your/package/name.yml (scripts have to be defined as packages for this extension because it's written as a Moose::Role mix-in).
See L<Nour::Script/"Configuration setup"> for details.

By default, these options are configured:
- verbose+
- silent
- help|?
- mode=s

The mode option is used in conjunction with L<database|Nour::Script/"Database utility"> configuration (if you set that up).

=head2 Database utility

No documentation here yet, uses L<Nour::Database>.

=head2 Using the logger

No documentation here yet, uses L<Nour::Logger>.

=cut
