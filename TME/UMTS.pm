package UMTS;
use strict;
use warnings;
use diagnostics;

use TMEcommon;
use LWP::Simple;
use HTML::TableExtract;
use Exporter qw(import);
our @EXPORT_OK = qw(getCells ngetNodeB);

# Input : site code
sub getCells {
    my $sitecode = shift;
    my $cp       = substr( $sitecode, 0, 2 );
    my $code     = substr( $sitecode, 2, 5 );
    my @ret      = ();

    ## Interpretación del contenido
    my $html = get( 'http://10.34.213.161/CNAI/KPI/TM/consultaEmplazamiento.php?CodClave=' . "$cp" . " " . "$code" )
      or die 'Aviso: no se logra conectar con el Inventario de TME';
    my $te = HTML::TableExtract->new();
    $te->parse($html);
    my @tables = $te->tables;

    foreach (@tables) {
        my @rows = $_->rows;
        shift @rows;    # la primera línea no interesa

        my @tecnologia   = map { $_->[0] } @rows;
        my @celda        = map { $_->[2] } @rows;
        my @nodo         = map { $_->[7] } @rows;
        my @controladora = map { $_->[8] } @rows;

        @tecnologia   = grep /\S/, @tecnologia;
        @celda        = grep /\S/, @celda;
        @nodo         = grep /\S/, @nodo;
        @controladora = grep /\S/, @controladora;
		
        for my $i ( 0 .. $#rows ) {
            if ( $tecnologia[$i] eq "UMTS" ) {
                push @ret, $celda[$i];
            }
        }

    }

    if (@ret) {
        my $refret = TMEcommon::RemoveMultipleElem (\@ret);
        @ret = grep /\S/, @$refret;
    }
    @ret = sort @ret;
    return \@ret;

}


# Pilla los NodosB fijandose en el nombre del NodoB
# Input : site code
sub ngetNodeB {
    my $sitecode = shift;
    my $cp       = substr( $sitecode, 0, 2 );
    my $code     = substr( $sitecode, 2, 5 );
    my @ret      = ();
    ## Interpretación del contenido
    my $html = get( 'http://10.34.213.161/CNAI/KPI/TM/consultaEmplazamiento.php?CodClave=' . "$cp" . " " . "$code" )
      or die 'Aviso: no se logra conectar con el Inventario de TME';
    my $te = HTML::TableExtract->new();
    $te->parse($html);
    my @tables = $te->tables;

    foreach (@tables) {
        my @rows = $_->rows;
        shift @rows;    # la primera línea no interesa

        my @tecnologia   = map { $_->[0] } @rows;
        my @celda        = map { $_->[2] } @rows;
        my @nodo         = map { $_->[7] } @rows;
        my @controladora = map { $_->[8] } @rows;

        @tecnologia   = grep /\S/, @tecnologia;
        @celda        = grep /\S/, @celda;
        @nodo         = grep /\S/, @nodo;
        @controladora = grep /\S/, @controladora;
		
        for my $i ( 0 .. $#rows ) {
            if ( defined $nodo[$i] ) {
                my $prefix = substr $nodo[$i], 0, 3;
                if ( $prefix eq "ERB" ) {
                    if ( not grep /^\Q$nodo[$i]$/, @ret ) {
                        push @ret, $nodo[$i];
                    }
                }
            }
        }
    }

    if (@ret) {
        my $refret = TMEcommon::RemoveMultipleElem (\@ret);
        @ret = grep /\S/, @$refret;
    }
    @ret = sort @ret;
    return \@ret;
}
1;
