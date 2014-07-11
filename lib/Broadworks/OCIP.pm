package Broadworks::OCIP;

# ABSTRACT: API for communication with Broadworks OCI-P Interface

use strict;
use warnings;
use utf8;
use feature 'unicode_strings';
use namespace::autoclean;
use Broadworks::OCIP::Response;
use Broadworks::OCIP::Throwable;
use Data::UUID;
use Digest::MD5 qw( md5_hex );
use Digest::SHA1 qw( sha1_hex );
use Encode;
use IO::Select;
use IO::Socket::INET;
use Moose;
use Method::Signatures;
use MooseX::StrictConstructor;
use XML::Writer;

extends 'Broadworks::OCIP::Methods';

# VERSION
# AUTHORITY

# ------------------------------------------------------------------------
has version => ( is => 'ro', isa => 'Str', default => '17sp4', );
has character_set => ( is => 'ro', isa => 'Str', default => 'ISO-8859-1', );
has encoder => ( is => 'ro', isa => 'Object', builder => '_build_encoder', );

method _build_encoder () {
    my $character_set = $self->character_set;
    return find_encoding($character_set)
        || Broadworks::OCIP::Throwable->throw(
        message         => "Cannot find encoder for $character_set",
        execution_phase => 'setup',
        error_code      => 'no_encode'
        );
}

has protocol => ( is => 'ro', isa => 'Str', default => 'OCI', );
has port => ( is => 'ro', isa => 'Int', default => 2208, );
has host => ( is => 'ro', isa => 'Str', required => 1, );
has target => ( is => 'ro', isa => 'Str', builder => '_build_target',  lazy=>1  );

method _build_target () {
    return join( ':', $self->host, $self->port );
}

has username => ( is => 'ro', isa => 'Str', required => 1, );
has authhash => ( is => 'ro', isa => 'Str', required => 1,);
has timeout => ( is => 'rw', isa => 'Int', default => 8, );
has socket => ( is => 'ro', isa => 'Object', builder => '_build_socket', lazy => 1, );

method _build_socket () {
    return IO::Socket::INET->new( $self->target )
        || Broadworks::OCIP::Throwable->throw(
        message         => sprintf( "Unable to connect to %s - %s\n", $self->target, $! ),
        execution_phase => 'setup',
        error_code      => 'cant_connect'
        );
}

has select => ( is => 'ro', isa => 'Object', builder => '_build_select', lazy => 1, );

method _build_select () {
    return IO::Select->new( $self->socket )
        || Broadworks::OCIP::Throwable->throw(
        message         => sprintf( "Unable to build select  on socket to %s - %s\n", $self->target, $! ),
        execution_phase => 'setup',
        error_code      => 'no_select'
        );
}

has session => ( is => 'ro', isa => 'Str', builder => '_build_session', lazy => 1, );

method _build_session () { return Data::UUID->new->create_str; }

has is_authenticated => ( is => 'ro', isa => 'Bool', builder => '_build_is_authenticated', lazy => 1, );

method _build_is_authenticated () {

    # send authentication request to get nonce
    $self->send_command_xml( 'AuthenticationRequest', [ userId => $self->username ] );
    my $res = $self->receive( 'AuthenticationResponse', 1 );

    # send login request
    $self->send_command_xml(
        'LoginRequest14sp4',
        [   userId         => $self->username,
            signedPassword => lc( md5_hex( join( ':', $res->command->{nonce}, $self->authhash ) ) )
        ]
    );
    my $res2 = $self->receive( 'LoginResponse14sp4', 1 );

    return 1;
}

has last_sent => ( is => 'rw', isa => 'Str', );
has trace => ( is => 'rw', isa => 'Bool',default=>0 );

# ----------------------------------------------------------------------
around 'BUILDARGS' => sub {
    my ( $orig, $class, %args ) = @_;

    if ( my $password = delete $args{password} ) {
        $args{authhash} = lc( sha1_hex($password) );
    }

    $class->$orig(%args);
};

# ----------------------------------------------------------------------
method send ($string) {

    $self->last_sent($string);
    $self->socket->print($string);
    warn( '>>> ', $string, "\n" ) if ( $self->trace );
}

# ----------------------------------------------------------------------
method receive ($expected,$die_on_error) {

    my $str = '';
    {    # delimit section where we override character handling
        use bytes;
        my $select = $self->select;
        while ( my ($fh) = $select->can_read( $self->{timeout} ) ) {
            Broadworks::OCIP::Throwable->throw(
                message         => "Timeout on receive - $!\n($str)\n",
                execution_phase => 'receive',
                error_code      => 'timeout'
            ) unless ( defined($fh) );

            # read - bail out if EOF
            my $eofs = 0;
            unless ( sysread $fh, $str, 65536, length($str) ) {
                last if ( $eofs++ );
                next;
            }
            last if ( $str =~ /<\/BroadsoftDocument>/ );
        }

        Broadworks::OCIP::Throwable->throw(
            message         => "No Data on receive - $!\n($str)\n",
            execution_phase => 'receive',
            error_code      => 'no_data'
        ) unless ( length($str) );
    }
    warn( '<<< ', $str, "\n" ) if ( $self->trace );

    return ( Broadworks::OCIP::Response->new( xml => $str, expected => $expected, die_on_error => $die_on_error ) );
}

# ----------------------------------------------------------------------
sub _command_xml_parameters {
    my ( $xw, $parampairs ) = @_;

    while ( scalar( @{$parampairs} ) ) {
        my ( $key, $val ) = splice( @{$parampairs}, 0, 2 );
        if ( ref($val) eq 'ARRAY' ) {
            $xw->startTag($key);
            _command_xml_parameters( $xw, $val );
            $xw->endTag($key);
        }
        else {

            # attribs is there to allow correct tagging of empty elements
            my @attribs = ( defined($val) && ( $val eq qq[] ) ) ? ( 'xsi:nil' => 'true' ) : ();
            $xw->dataElement( $key => $val, @attribs );
        }
    }
}

# ----------------------------------------------------------------------
method send_command_xml ($cmd, $parampairs) {

    # start XML build
    my $xw = XML::Writer->new( OUTPUT => 'self' )
        or Broadworks::OCIP::Throwable->throw(
        message         => "Cannot build XML object - $!",
        execution_phase => 'send',
        error_code      => 'xml_fail'
        );
    $xw->xmlDecl( $self->character_set );

    # build document
    $xw->startTag(
        'BroadsoftDocument',
        'protocol'  => $self->protocol,
        'xmlns'     => 'C',
        'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance'
    );
    $xw->dataElement( sessionId => $self->session, xmlns => '' );

    # build command section
    $xw->startTag( 'command', xmlns => '', 'xsi:type' => $cmd );

    # inject command parameters
    _command_xml_parameters( $xw, $parampairs );

    # close up tags
    $xw->endTag('command');
    $xw->endTag('BroadsoftDocument');

    # get XML string
    my $xml_string = $xw->end;

    # send XML string
    $self->send($xml_string);
}

# ------------------------------------------------------------------------
method send_query ($cmd, @parampairs) {

    Broadworks::OCIP::Throwable->throw(
        message         => "Not authenticated",
        execution_phase => 'send_query',
        error_code      => 'no_auth'
    ) unless ( $self->is_authenticated );
    my $response = $cmd;
    $response =~ s/Request/Response/;
    $self->send_command_xml( $cmd, \@parampairs );
    return $self->receive( $response, 1 );
}

# ------------------------------------------------------------------------
method send_command ($cmd, @parampairs) {

    Broadworks::OCIP::Throwable->throw(
        message         => "Not authenticated",
        execution_phase => 'send_command',
        error_code      => 'no_auth'
    ) unless ( $self->is_authenticated );
    $self->send_command_xml( $cmd, \@parampairs );
    return $self->receive( 'SuccessResponse', 0 );
}

# ------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;
1;
