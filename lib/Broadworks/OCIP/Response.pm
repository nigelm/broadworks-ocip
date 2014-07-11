package Broadworks::OCIP::Response;

# ABSTRACT: A Broadworks OCI-P Response Message

use strict;
use warnings;
use utf8;
use feature 'unicode_strings';

use Broadworks::OCIP::Throwable;
use Moose;
use Method::Signatures;
use MooseX::StrictConstructor;
use Try::Tiny;
use XML::BareX;

# VERSION
# AUTHORITY

# ------------------------------------------------------------------------

has xml => ( is => 'ro', isa => 'Str', required => 1, );
has expected => ( is => 'ro', isa => 'Str', required => 1, );
has die_on_error => ( is => 'ro', isa => 'Bool', required => 1, default=>1,);
has hash => (is => 'ro', isa => 'HashRef', lazy => 1, builder => '_build_hash');

method _build_hash () {
    my $hash;
    try { $hash = XML::BareX::xmlin( $self->xml ); }
    catch {
        Broadworks::OCIP::Throwable->throw(
            message         => sprintf( "Error on XML unpack %s with %s", $_, $self->xml ),
            execution_phase => 'response',
            error_code      => 'xml_unpack'
        ) if ( $self->die_on_error and not $self->status_ok );
    };
    Broadworks::OCIP::Throwable->throw(
        message         => sprintf( "Nothing returned from parse - received XML was [%s]", $self->xml ),
        execution_phase => 'response',
        error_code      => 'xml_null'
    ) unless ($hash);
    return $hash;
}

has type => (is => 'ro',isa => 'Str',lazy => 1,builder => '_build_type');
method _build_type () { return ( $self->command->{'xsi:type'} ); }

has status_ok => (is => 'ro',isa => 'Bool',lazy => 1,builder => '_build_status_ok');
method _build_status_ok () { return ( ( $self->type eq $self->expected ) ? 1 : 0 ); }

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
method BUILD ($args) {

    # check this object is valid and the right type
    Broadworks::OCIP::Throwable->throw(
        message         => sprintf( "Expecting a response of type %s but got %s", $self->expected, $self->type ),
        execution_phase => 'response',
        error_code      => 'ocip_unexpected'
    ) if ( $self->die_on_error and not $self->status_ok );
}

# ------------------------------------------------------------------------

no Moose;
__PACKAGE__->meta->make_immutable;
1;
