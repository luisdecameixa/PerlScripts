#
# El objetivo de este script es generar el fichero para el script de WinFIOL,
# que comprueba (hace logs) de cada una de las tecnoligías de los sites de TME.
#
# Es decir, hace de 'pegamento' entre el Inventario de TME y WinFIOL.
#
#	Uso: perl tme_generate_winfiol.pl <source> <destination>
#	Input : <source> : Fichero de texto, una unica columna con los codigos de sites
#	Output : <destination> : Fichero TMEsite.txt
#

use strict;
use warnings;
use diagnostics -verbose;

use LWP::Simple;
use HTML::TableExtract;
use GSM;
use UMTS;
use LTE;
use TMEcommon;

main();

sub usagemsg {
    return <<"END_USAGE";
Usage : TME_generate_winfiol <source> <destination>
<source> : sites (file)
<destination> : file to WinFIOL
 * Send feedback and/or bugs to luisdecameixa\@coit.es *
END_USAGE
}

sub main {
    my $numberargv = $#ARGV + 1;
    if ( $numberargv != 2 ) {
        warn usagemsg();
        exit 0;
    }

    # Primero comprobamos acceso al Inventario de TME
    # Si no hay conexion sale dando un Aviso
    TMEcommon::TestConnection();

    # Lee los codigos de los sites del fichero sites.txt
    open my $filesites, '<', $ARGV[0]
      or die "Could not open input file '$ARGV[0]' $!";
    chomp( my @sites = <$filesites> );
    close $filesites;

    # Elimina lineas vacias, y repeticiones multiples en @sites
    my $refsites = TMEcommon::RemoveMultipleElem (\@sites);
    @sites = grep /\S/, @$refsites;

    my $TMEsites = $ARGV[1];
    open( my $fTMEsites, '>', $ARGV[1] )
      or die "Could not open file '$ARGV[1]' $!";

    foreach (@sites) {
        print $fTMEsites $_ . "\n";

        my $zona = TMEcommon::getZONA($_);
        print $fTMEsites "$zona\n";

        my $refgsmvsccell = GSM::getBSCCells($_);
        my %gsmbsccell    = %$refgsmvsccell;

        my $size = 0;
        $size = keys %gsmbsccell;

        if ( $size != 0 ) {
            my $tag = 0;
            foreach my $celda ( keys %gsmbsccell ) {
                if ( $tag == 0 ) {
                    print $fTMEsites "$gsmbsccell{$celda}";
                    $tag = 1;
                }
                print $fTMEsites "\@$celda";
            }
        }
        else { print $fTMEsites "#"; }

        print $fTMEsites "@#\n";

        my $refumtsnodeb = UMTS::ngetNodeB($_);
        my @umtsnodeb    = @$refumtsnodeb;
        $size = scalar @umtsnodeb;
        if ( $size != 0 ) {
            for my $i ( 0 .. $#umtsnodeb ) {
                print $fTMEsites $umtsnodeb[$i] . "@";
            }
            print $fTMEsites "#\n";
        }
        else { print $fTMEsites "#@#\n"; }

        my $reflteenodeb = LTE::ngetENodeB($_);
        my @lteenodeb    = @$reflteenodeb;
        $size = scalar @lteenodeb;
        if ( $size != 0 ) {
            for my $i ( 0 .. $#lteenodeb ) {
                print $fTMEsites $lteenodeb[$i] . "@";
            }
            print $fTMEsites "#\n";
        }
        else { print $fTMEsites "#@#\n"; }

    }

    print $fTMEsites "ENDFILE";
    close $fTMEsites;
}