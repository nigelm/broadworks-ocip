package Broadworks::OCIP::Throwable;

# ABSTRACT: Exception throwing for Broadworks::OCIP

use strict;
use warnings;
use utf8;
use namespace::autoclean;

# VERSION
# AUTHORITY

use Moose;
extends 'Throwable::Error';

=begin :prelude

=for test_synopsis
1;
__END__

=for stopwords NIGELM 

=for Pod::Coverage mvp_multivalue_args

=end :prelude

=head1 SYNOPSIS

  use Broadworks::OCIP::Throwable;

  Broadworks::OCIP::Throwable->throw(...);

=head1 DESCRIPTION

Throws an exception.

=head2 Required Parameters

=head3 message

An exception message.

=head3 execution_phase

Text to give an indication of what we were doing.

=head3 error_code

Text to uniquely identify what caused this.

=cut

# ------------------------------------------------------------------------

has execution_phase => (
    is      => 'ro',
    isa     => 'Str',
    default => 'unknown',
);

has error_code => (
    is      => 'ro',
    isa     => 'Str',
    default => 'error',
);

# ------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 AUTHOR

Nigel Metheringham <Nigel.Metheringham@redcentricplc.com>

=head1 COPYRIGHT

Copyright 2014 Recentric Solutions Limited. All rights reserved.

=cut
