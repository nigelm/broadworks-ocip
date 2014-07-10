#!/usr/bin/env perl
#
#
use strict;
use warnings;
use feature 'unicode_strings';
use open ':encoding(utf8)';

#
use Data::Dump;
use File::Basename;
use File::Glob;
use File::Slurp;
use File::Spec;
use File::Temp;
use Perl::Tidy;
use Pod::Tidy qw(  tidy_filehandle );
use XML::BareX;

# ------------------------------------------------------------------------
sub list {
    return () unless ( defined( $_[0] ) );
    return @{ $_[0] } if ( ref( $_[0] ) eq 'ARRAY' );
    return $_[0];
}

# ----------------------------------------------------------------------
sub build_pod_entry {
    my $chunk = shift;
    my $out   = shift;
    my $info  = shift;

    #$out->print("\n# ----------------------------------------------------------------------\n");
    $out->printf( "\n=head3 %s\n\n", $info->{name} );

    # extract documentation and output
    my $doc = $chunk->{'xs:annotation'}{'xs:documentation'};
    $doc =~ tr/\001-\176/ /cs;
    $doc =~ s/^\s{6,}//mg;
    $doc =~ s/\b(\w+[A-Z][a-z]\w+)\b/C<$1>/g;
    $out->print($doc);

    # output fixed parameter info
    if ( scalar( @{ $info->{fixed_parameters} } ) ) {
        $out->print("\nFixed parameters are:-\n");
        $out->print("\n=over 4\n");
        $out->print("\n=item $_\n") foreach ( @{ $info->{fixed_parameters} } );
        $out->print("\n=back\n");
    }

    # and any additionals
    $out->print("\nAdditionally there are generic tagged parameters.\n");

    # end
    ##$out->print("\n=cut\n\n");
}

# ----------------------------------------------------------------------
sub build_sub_entry {
    my $chunk = shift;
    my $out   = shift;
    my $info  = shift;

    # output header
    $out->printf( "sub %s { my \$self = shift;\n", $info->{name} );

    # output fixed parameter pickup
    map { $out->printf( "my \$%s = shift;\n", $_ ); } @{ $info->{fixed_parameters} };

    # and generics if needed
    $out->print("my \@params  = \@_;\n") if ( $info->{need_generic_params} );

    # output command call
    $out->printf( "\nreturn \$self->_send_%s('%s'", ( $info->{is_command} ? 'command' : 'query' ), $info->{name} );

    # output fixed parameters
    map { $out->printf( ", %s => \$%s", $_, $_ ); } @{ $info->{fixed_parameters} };

    # output generics if needed
    $out->print(", \@params") if ( $info->{need_generic_params} );

    # output tail
    $out->print(");\n}\n");
}

# ----------------------------------------------------------------------
sub parse_params {
    my $chunk = shift;

    my $is_command = ( $chunk->{'xs:annotation'}{'xs:documentation'} =~ /SuccessResponse/ ) ? 1 : 0;

    # see if there are any mandatory parameters
    my $need_generic_params = 1;
    my @fixed_params;
    my $content = $chunk->{'xs:complexContent'}{'xs:extension'}{'xs:sequence'};
    if (defined($content)
        and ( ref($content) eq 'HASH' )
        ## and ( scalar( keys( %{$content} ) ) == 1 )
        and defined( $content->{'xs:element'} )
        ) {
        my @elements = list( $content->{'xs:element'} );
        if ( scalar(@elements) > 0 ) {
            $need_generic_params = 0;
            while ( my $ele = shift @elements ) {
                if ( exists( $ele->{minOccurs} ) ) { $need_generic_params = 1; last; }
                else {
                    push( @fixed_params, $ele->{name} );
                }
            }
        }
    }

    return {
        name                => $chunk->{name},
        is_command          => $is_command,
        fixed_parameters    => \@fixed_params,
        need_generic_params => $need_generic_params
    };
}

# ----------------------------------------------------------------------
sub process_schema_chunk {
    my $chunk = shift;
    my $code  = shift;
    my $pod   = shift;

    # we only care about requests
    my $whatami = $chunk->{'xs:complexContent'}{'xs:extension'}{'base'};
    return unless ( $whatami and ( $whatami eq 'core:OCIRequest' ) );
    my $info = parse_params($chunk);
    build_pod_entry( $chunk, $pod, $info );
    build_sub_entry( $chunk, $code, $info );
}

# ----------------------------------------------------------------------
sub process_schema_set {
    my $tree = shift;
    my $code = shift;
    my $pod  = shift;

    my @chunks = list( $tree->{'xs:schema'}{'xs:complexType'} );
    while ( my $chunk = shift @chunks ) {
        process_schema_chunk( $chunk, $code, $pod );
    }
}

# ----------------------------------------------------------------------
sub process_file {
    my $fn   = shift;
    my $code = shift;
    my $pod  = shift;

    my $xml = XML::BareX->new( file => $fn );
    my $tree = $xml->simple;

    process_schema_set( $tree, $code, $pod );
}

# ----------------------------------------------------------------------
my $codefh = File::Temp->new();
my $podfh  = File::Temp->new();

$codefh->print("package Broadworks::OCIP::Methods;\n");
$codefh->print("use strict;\n");
$codefh->print("use warnings;\n");

while ( my $fn = shift ) {
    process_file( $fn, $codefh, $podfh );
}
$codefh->print("1;\n");

warn "Processed - now tidying\n";
$codefh->flush;
$codefh->seek( 0, 0 );    # back to the start
my $code = read_file($codefh);
Perl::Tidy::perltidy( source => \$code );

print("\n__END__\n");
warn "Perl tidied - now tidying POD\n";
$podfh->flush;
$podfh->seek( 0, 0 );     # back to the start
Pod::Tidy::tidy_filehandle($podfh);

