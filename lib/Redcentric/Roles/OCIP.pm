package Redcentric::Roles::OCIP;

# ABSTRACT: OCI-P access role for Broadworks CLI programs

use strict;
use warnings;
use namespace::autoclean;

# VERSION
# AUTHORITY

use Function::Parameters;
use Moose::Role;    # optional
use MooseX::App::Role;
use Digest::SHA1 qw( sha1_hex );
use Broadworks::OCIP;

=begin :prelude

=for test_synopsis
1;
__END__

=for stopwords NIGELM Broadworks OCI authhash programmes

=for Pod::Coverage mvp_multivalue_args

=end :prelude

# ------------------------------------------------------------------------

=head1 SUMMARY

This is a role for L<MooseX::App> CLI programmes which adds a Broadworks OCI-P
role for access a Broadworks voice platform.

# ------------------------------------------------------------------------

=head3 oci_host

The host that is being connected to - either a host name or an IP address.

=cut

option oci_host => (
    is            => 'ro',
    isa           => 'Str',
    documentation => 'Broadworks host to connect to',
    required      => 1,
);

# ------------------------------------------------------------------------

=head3 oci_port

The port number to connect to - default C<2208>.

=cut

option oci_port => (
    is            => 'ro',
    isa           => 'Int',
    default       => 2208,
    documentation => 'Port to connect to on Broadworks host',
);

# ------------------------------------------------------------------------

=head3 oci_username

The username to authenticate with on the remote system.

=cut

option oci_username => (
    is            => 'ro',
    isa           => 'Str',
    documentation => 'Username for authentication to Broadworks host',
    required      => 1,
);

# ------------------------------------------------------------------------

=head3 oci_password

A password to use for authenticating the username.  This is transformed into an
authhash and the original password cleared.

=cut

option oci_password => (
    is            => 'ro',
    isa           => 'Str',
    clearer       => 'clear_oci_password',
    documentation => 'Password for Broadworks host (or use authhash)',
);

# ------------------------------------------------------------------------

=head3 oci_authhash

An authentication hash to use for authenticating the username.  Alternatively
the oci_password attribute can be set and this is transformed into an
appropriate authhash (and the oci_password deleted).

=cut

option oci_authhash => (
    is            => 'ro',
    isa           => 'Str',
    documentation => 'Hashed authentication token for Broadworks host (can derive from oci_password)',
    builder       => '_build_oci_authhash',
    lazy          => 1,
);

method _build_oci_authhash () {
    my $oci_password = $self->oci_password || die "No oci_password was set";
    my $authhash     = lc( sha1_hex($oci_password) );
    $self->clear_oci_password;
    return $authhash;
}

# ----------------------------------------------------------------------

has oci => (
    is      => 'ro',
    isa     => 'Object',
    clearer => 'clear_oci',
    builder => '_build_oci',
    lazy    => 1,
);

method _build_oci () {
    my $args = {};
    foreach my $arg (qw[username authhash host port]) {
        my $method = 'oci_' . $arg;
        $args->{$arg} = $self->$method;
    }
    $args->{trace} = 1 if ( $self->debug );
    return Broadworks::OCIP->new($args);
}

# ------------------------------------------------------------------------

=head1 AUTHOR

Nigel Metheringham <Nigel.Metheringham@redcentricplc.com>

=head1 COPYRIGHT

Copyright 2014-2020 Recentric Solutions Limited. All rights reserved.

=cut

1;
