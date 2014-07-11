#!/usr/bin/env perl
#
#
use strict;
use warnings;
use feature 'unicode_strings';
use open ':encoding(utf8)';

use File::Basename;
use File::Glob;
use File::Slurp;
use File::Spec;
use File::Temp;
use Pod::Tidy qw(  tidy_filehandle );
use XML::BareX;

use lib '/opt/perl/locallib/';
use JS::Perl::Tidy;

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

    $out->printf( "\n=head3 %s\n\n", $info->{name} );

    # extract documentation and output
    my $doc = $chunk->{'xs:annotation'}{'xs:documentation'};
    $doc =~ tr/\001-\176/ /cs;
    $doc =~ s/^\s{6,}//mg;
    $doc =~ s/\s+$//mg;
    $doc =~ s/^\s{,2}(?=\w)//mg;
    $doc =~ s/\s+(?=The\s+response\s+is)/\n\n/mg;
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

    # build fixed parameters
    my $count = 0;
    my @param_set = map { '$x' . $count++ } @{ $info->{fixed_parameters} };

    # add generics if needed
    push( @param_set, '@params' ) if ( $info->{need_generic_params} );

    # output method header with parameters
    $out->printf( "method %s\n(%s)\n{\n", $info->{name}, join( ', ', @param_set ) );

    # output command call
    $out->printf( "return \$self->send_%s('%s'", ( $info->{is_command} ? 'command' : 'query' ), $info->{name} );

    # output fixed parameters
    $count = 0;
    map { $out->printf( ", %s => \$x%d", $_, $count++ ); } @{ $info->{fixed_parameters} };

    # output generics if needed
    $out->print(", \@params") if ( $info->{need_generic_params} );

    # output tail
    $out->print(");\n}\n");
    $out->print("# ----------------------------------------------------------------------\n");
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
    return 0 unless ( $whatami and ( $whatami eq 'core:OCIRequest' ) );
    my $info = parse_params($chunk);
    build_pod_entry( $chunk, $pod, $info );
    build_sub_entry( $chunk, $code, $info );
    return 1;
}

# ----------------------------------------------------------------------
sub process_schema_set {
    my $tree = shift;
    my $code = shift;
    my $pod  = shift;

    my $count  = 0;
    my @chunks = list( $tree->{'xs:schema'}{'xs:complexType'} );
    while ( my $chunk = shift @chunks ) {
        process_schema_chunk( $chunk, $code, $pod ) and $count++;
    }
    return $count;
}

# ----------------------------------------------------------------------
sub generate_code_header {
    my $fh              = shift;
    my $class_base_name = shift;

    $fh->printf( "package Broadworks::OCIP::%s;\n", $class_base_name );
    $fh->print("\n");
    $fh->print("use strict;\n");
    $fh->print("use warnings;\n");
    $fh->print("use namespace::autoclean;\n");
    $fh->print("use Method::Signatures;\n");
    $fh->print("use Moose;\n");
    $fh->print("#  This file will be too big for perl critic to work well\n");
    $fh->print("## no critic\n");
    $fh->print("# ----------------------------------------------------------------------\n");
    $fh->print("\n");
}

# ----------------------------------------------------------------------
sub generate_code_trailer {
    my $fh              = shift;
    my $class_base_name = shift;

    $fh->print("\n");
    $fh->print("__PACKAGE__->meta->make_immutable;\n");
    $fh->print("1;\n");
}

# ----------------------------------------------------------------------
sub do_output {
    my $class_base_name = shift;
    my $code            = shift;
    my $pod             = shift;

    $code->flush;
    $code->seek( 0, 0 );    # back to the start
    $pod->flush;
    $pod->seek( 0, 0 );     # back to the start

    my $fn = join( '.', $class_base_name, 'pm' );
    my $out_code_str = '';
    warn "Tidying\n";
    {                       # keep this stuff in own context
        my $code_str = read_file($code);
        JS::Perl::Tidy::perltidy( source => \$code_str, destination => \$out_code_str );
    }

    my $podstr = read_file($pod);
    warn "Writing\n";
    write_file( $fn, $out_code_str, "\n__END__\n", $podstr );
}

# ----------------------------------------------------------------------
sub get_class_name {
    my $fn = shift;

    my ( $volume, $directories, $file ) = File::Spec->splitpath($fn);
    my $class = $file;
    $class =~ s/\..*$//;        # remove extension
    $class =~ s/OCISchema//;    # remove basename

    return $class;
}

# ----------------------------------------------------------------------
sub process_file {
    my $fn   = shift;
    my $code = shift;
    my $pod  = shift;

    my $class_base_name = get_class_name($fn);
    warn("- $class_base_name\n");
    $code->printf("##\n## $class_base_name\n##\n");
    my $npod = File::Temp->new();
    $npod->printf("=head2 $class_base_name\n\n");

    my $xml = XML::BareX->new( file => $fn );
    my $tree = $xml->simple;

    process_schema_set( $tree, $code, $npod ) or return;

    # do pod tidy a file at a time - otherwise the time used gets massive
    my $tfn = $npod->filename;
    $npod->close;
    Pod::Tidy::tidy_files( files => [$tfn], inplace => 1, nobackup => 1 );
    my $podstr = read_file($tfn);
    $pod->print($podstr);
}

# ----------------------------------------------------------------------

my $code = File::Temp->new();
my $pod  = File::Temp->new();
generate_code_header( $code, 'Methods' );

while ( my $fn = shift ) {
    process_file( $fn, $code, $pod );
}

generate_code_trailer($code);
do_output( 'Methods', $code, $pod );