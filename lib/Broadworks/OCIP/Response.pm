package Broadworks::OCIP::Response;

# ABSTRACT: A Broadworks OCI-P Response Message

use strict;
use warnings;
use utf8;
use feature 'unicode_strings';
use Carp;
use Moose;
use Method::Signatures;
use MooseX::StrictConstructor;
use Try::Tiny;
use XML::BareX;

# ------------------------------------------------------------------------

has xml => ( is => 'ro', isa => 'Str', required => 1, );
has expected => ( is => 'ro', isa => 'Str', required => 1, );
has hash => (is => 'ro', isa => 'HashRef', lazy => 1, builder => '_build_hash');

method _build_hash () {
    my $hash;
    try { $hash = XML::BareX::xmlin( $self->xml ); }
    catch { croak sprintf( "%s - received XML was [%s]\n", $_, $self->xml ); };
    croak sprintf( "Nothing returned from parse - received XML was [%s]\n", $self->xml ) unless ($hash);
    return $hash;
}

has status_ok => (is => 'ro',isa => 'Bool',lazy => 1,builder => '_build_status_ok');

method _build_status_ok () {
    return ( ( $self->command->{'xsi:type'} eq $self->expected ) ? 1 : 0 );
}

has command => (is => 'ro', isa => 'HashRef', lazy => 1, builder => '_build_command');
method _build_command () { return $self->hash->{command}; }

has tables => (is => 'ro', isa => 'HashRef', lazy => 1, builder => '_build_hash');
method _build_tables () {
    my $tables = {};
    while ( my ( $k, $v ) = each %{ $self->command } ) {
        if ( $k =~ /Table$/ ) {
            my $table = [];
            $tables->{$k} = $table;
            my @cols = list( $v->{colHeading} );
            foreach my $row ( list( $v->{row} ) ) {
                push( @{$table}, { map { $cols[$_] => $row->{col}->[$_] } 0 .. $#cols } );
            }
        }
    }
}

# ------------------------------------------------------------------------

no Moose;
__PACKAGE__->meta->make_immutable;
1;
