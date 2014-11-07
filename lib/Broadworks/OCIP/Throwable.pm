package Broadworks::OCIP::Throwable;

# ABSTRACT: Exception throwing for Broadworks::OCIP

use strict;
use warnings;
use utf8;
use namespace::autoclean;

our $VERSION = '0.04'; # VERSION
our $AUTHORITY = 'cpan:NIGELM'; # AUTHORITY

use Moose;
extends 'Throwable::Error';


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


around _build_stack_trace_args => sub {
    my ( $orig, $self, @rest ) = @_;
    my $args_array = $self->$orig(@rest);
    push( @{$args_array}, no_refs => 1 );
    return $args_array;
};

# ------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable;
1;

__END__

=pod

=for test_synopsis 1;
__END__

=for stopwords NIGELM 

=for Pod::Coverage mvp_multivalue_args

=head1 NAME

Broadworks::OCIP::Throwable - Exception throwing for Broadworks::OCIP

=head1 VERSION

version 0.04

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

=head3 _build_stack_trace_args

Modifies the stack trace to have no_refs set, otherwise the Devel::StackTrace
objects leak, causing a build up of unreclaimable memory.

Taken from a post by Bill Moseley at
L<http://www.nntp.perl.org/group/perl.moose/2013/02/msg2574.html>

=head1 AUTHOR

Nigel Metheringham <Nigel.Metheringham@redcentricplc.com>

=head1 COPYRIGHT

Copyright 2014 Recentric Solutions Limited. All rights reserved.

=head1 INSTALLATION

See perlmodinstall for information and options on installing Perl modules.

=head1 BUGS AND LIMITATIONS

You can make new bug reports, and view existing ones, through the
web interface at L<http://rt.cpan.org/Public/Dist/Display.html?Name=Broadworks-OCIP>.

=head1 AVAILABILITY

The project homepage is L<https://metacpan.org/release/Broadworks-OCIP>.

The latest version of this module is available from the Comprehensive Perl
Archive Network (CPAN). Visit L<http://www.perl.com/CPAN/> to find a CPAN
site near you, or see L<https://metacpan.org/module/Broadworks::OCIP/>.

=head1 AUTHOR

Nigel Metheringham <nigelm@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Nigel Metheringham.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
