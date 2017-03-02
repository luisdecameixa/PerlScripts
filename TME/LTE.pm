package LTE;
use strict;
use warnings;
use TMEcommon;
use diagnostics -verbose;

use LWP::Simple;
use HTML::TableExtract;
use Exporter qw(import);
our @EXPORT_OK = qw(getCells getENodeB);

# Input : site code
sub getCells {
    my $sitecode = shift;
    my $cp       = substr( $sitecode, 0, 2 );
    my $code     = substr( $sitecode, 3, 6 );
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
            if ( $tecnologia[$i] eq "LTE" ) {
                push @ret, $celda[$i];
            }
        }
    }
    if (@ret) { @ret = grep /\S/, @ret }
    @ret = sort @ret;
    return \@ret;
}

# Pilla los ENodosB fijandose en la columna _tecnologia_, he comprobado que puede fallar cuando hay tecnologia pero no ENodoB
# Input : site code
sub getENodeB {
    my $sitecode = shift;
    my $cp       = substr( $sitecode, 0, 2 );
    my $code     = substr( $sitecode, 3, 6 );
    my @ret      = ();
    ## Interpretación del contenido
    my $html = get( 'http://10.34.213.161/CNAI/KPI/TM/consultaEmplazamiento.php?CodClave=' . "$cp" . " " . "$code" )
      or die 'Aviso: no se logra conectar con el Inventario de TME';
    my $te = HTML::TableExtract->new();
    $te->parse($html);
    my @tables = $te->tables;

    my ( @tecnologia, @celda, @nodo, @controladora, @rows ) = (undef);

    foreach (@tables) {
        @rows = $_->rows;
        shift @rows;    # la primera línea no interesa

        @tecnologia   = map { $_->[0] } @rows;
        @celda        = map { $_->[2] } @rows;
        @nodo         = map { $_->[7] } @rows;
        @controladora = map { $_->[8] } @rows;

        @tecnologia   = grep /\S/, @tecnologia;
        @celda        = grep /\S/, @celda;
        @nodo         = grep /\S/, @nodo;
        @controladora = grep /\S/, @controladora;

        for my $i ( 0 .. $#rows ) {
            if ( $tecnologia[$i] eq "LTE" ) {
                push @ret, $nodo[$i];
            }
        }
    }

    #print $#ret . "\n";
    if (@ret) {
        my $refret = TMEcommon::RemoveMultipleElem \@ret;
        @ret = grep /\S/, @$refret;
    }

    @ret = sort @ret;
    return \@ret;
}

# Pilla los ENodosB fijandose en el nombre del ENodoB
# Input : site code
sub ngetENodeB {
    my $sitecode = shift;
    my $cp       = substr( $sitecode, 0, 2 );
    my $code     = substr( $sitecode, 3, 6 );
    my @ret      = ();
    ## Interpretación del contenido
    my $html = get( 'http://10.34.213.161/CNAI/KPI/TM/consultaEmplazamiento.php?CodClave=' . "$cp" . " " . "$code" )
      or die 'Aviso: no se logra conectar con el Inventario de TME';
    my $te = HTML::TableExtract->new();
    $te->parse($html);
    my @tables = $te->tables;

    my ( @tecnologia, @celda, @nodo, @controladora, @rows ) = (undef);

    foreach (@tables) {
        @rows = $_->rows;
        shift @rows;    # la primera línea no interesa

        @tecnologia   = map { $_->[0] } @rows;
        @celda        = map { $_->[2] } @rows;
        @nodo         = map { $_->[7] } @rows;
        @controladora = map { $_->[8] } @rows;

        @tecnologia   = grep /\S/, @tecnologia;
        @celda        = grep /\S/, @celda;
        @nodo         = grep /\S/, @nodo;
        @controladora = grep /\S/, @controladora;

        for my $i ( 0 .. $#rows ) {
            if ( defined $nodo[$i] ) {
                my $prefix = substr $nodo[$i], 0, 3;
                if ( $prefix eq "ENB" ) {
                    if ( not grep /^\Q$nodo[$i]$/, @ret ) {
                        push @ret, $nodo[$i];
                    }
                }
            }
        }
    }

    #print $#ret . "\n";
    if (@ret) {
        my $refret = TMEcommon::RemoveMultipleElem \@ret;
        @ret = grep /\S/, @$refret;
    }

    @ret = sort @ret;
    return \@ret;
}
1;
