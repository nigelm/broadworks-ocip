package Broadworks::OCIP::Throwable;

# ABSTRACT: Exception throwing for Broadworks::OCIP

use strict;
use warnings;
use utf8;
use namespace::autoclean;
use Moose;
extends 'Throwable::Error';

# VERSION
# AUTHORITY

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
