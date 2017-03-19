#
# El objetivo de este script es generar los ficheros con las celdas presentes
# en cada una de las tecnoligías de los sites de TME.
#
#	Uso: perl TME_node_report.pl <source>
#	Input : <source> : Fiechero de texto, una unica columna con los codigos de sites
#	Output : Crea la carpteta NodeReports con los ficheros de los nodos presentes en cada site (todas las tecnologías):
#			 GSMCellReport.txt	UMTSMADRIDNodeReport.txt  UMTSBARCELONANodeReport.txt  LTENodeReport.txt
#

use strict;
use warnings;
use diagnostics;

use LWP::Simple;
use HTML::TableExtract;
use GSM;
use UMTS;
use LTE;
use TMEcommon;

main();

sub usagemsg {
    return <<"END_USAGE";
Usage : Usage : TME_node_report <source>
<source> : sites (file)
The output files will be created in directory NodeReports
 * Send feedback and/or bugs to luisdecameixa\@coit.es *
END_USAGE
}

sub main {
    my $numberargv = $#ARGV + 1;
    if ( $numberargv != 1 ) {
        warn usagemsg();
        exit 0;
    }

    # Primero comprobamos acceso al Inevtario de TME
    # Si no hay conexion sale dando un Aviso
    TMEcommon::TestConnection();

    # Lee los codigos de los sites del fichero sites.txt
    open( my $filesites, '<', $ARGV[0] )
      or die "Could not open input file '$ARGV[0]' $!";
    chomp( my @sites = sort <$filesites> );
    close $filesites;

    @sites = map { TMEcommon::ftrim($_) } @sites;
    @sites = map { substr $_, 0, 7 } @sites;

    # Elimina lineas vacias, y repeticiones multiples en @sites
    my $refsites = TMEcommon::RemoveMultipleElem( \@sites );
    @sites = grep /\S/, @$refsites;

    # Se crea el directorio para escribir los ficheros de salida
    my $outputdir = 'NodeReports';
    unless ( -e $outputdir or mkdir $outputdir ) {
        die "Unable to create directory '$outputdir' $!";
    }

    # Ficheros de salida
    my $GSMCellReport = 'GSMCellReport.txt';
    open( my $fGSMCellReport, '>', "$outputdir/$GSMCellReport" )
      or die "Could not open file '$GSMCellReport' $!";

    my $UMTSMADRIDNodeReport = 'UMTSMADRIDNodeReport.txt';
    open( my $fUMTSMADRIDNodeReport, '>', "$outputdir/$UMTSMADRIDNodeReport" )
      or die "Could not open file '$UMTSMADRIDNodeReport' $!";

    my $UMTSBARCELONANodeReport = 'UMTSBARCELONANodeReport.txt';
    open( my $fUMTSBARCELONANodeReport, '>', "$outputdir/$UMTSBARCELONANodeReport" )
      or die "Could not open file '$UMTSBARCELONANodeReport' $!";

    my $LTENodeReport = 'LTENodeReport.txt';
    open( my $fLTENodeReport, '>', "$outputdir/$LTENodeReport" )
      or die "Could not open file '$LTENodeReport' $!";

    for my $i ( 0 .. $#sites ) {

        my $refgsmcells  = GSM::getCells( $sites[$i] );
        my $refumtsnodes = UMTS::ngetNodeB( $sites[$i] );
        my $refltenodes  = LTE::ngetENodeB( $sites[$i] );

        my @gsmcells  = @$refgsmcells;
        my @umtsnodes = @$refumtsnodes;
        my @ltenodes  = @$refltenodes;

        for my $icell ( 0 .. $#gsmcells ) {
            if ( $gsmcells[$icell] ne "" ) {
                print $fGSMCellReport $gsmcells[$icell] . "\n";
            }
        }

        my $zona = TMEcommon::getZONA $sites[$i];

        for my $j ( 0 .. $#umtsnodes ) {
            if ( $umtsnodes[$j] ne "" ) {
                if ( $zona eq 'B' ) {
                    print $fUMTSBARCELONANodeReport $umtsnodes[$j] . "\n";
                }
                else {
                    print $fUMTSMADRIDNodeReport $umtsnodes[$j] . "\n";
                }
            }
        }

        for my $j ( 0 .. $#ltenodes ) {
            if ( $ltenodes[$j] ne "" ) {
                print $fLTENodeReport $ltenodes[$j] . "\n";
            }
        }

    }

    close $fGSMCellReport;
    close $fUMTSMADRIDNodeReport;
    close $fUMTSBARCELONANodeReport;
    close $fLTENodeReport;
}
