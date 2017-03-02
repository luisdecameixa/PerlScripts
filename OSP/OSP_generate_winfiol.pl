#
# "THE BEER-WARE LICENSE" (Revision 42):
# <luisdecameixa@coit.es> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return Luis Diaz Gonzalez
#

#
# El objetivo de este script es generar el fichero para el script de WinFIOL que
# hace logs de cada una de las tecnoligías de los sites de OSP.
#
# Es decir, hace de 'pegamento' entre el fichero de Maxplanck/TEXTO y WinFIOL.
#
#	Uso: perl OSP_generate_winfiol.pl <source> <destination>
#	Inputs :
#          [txt|excel]	 : tipo de fichero de entrada
#          <source>  : fichero de entrada
#          <destination> : fichero de salida para el script de WinFIOL
#

use strict;
use warnings;
use diagnostics;
use Encode;
use Spreadsheet::Read;
use OSPcommon;

main();

sub usagemsg {
    return <<"END_USAGE";
Usage : Usage : OSP_generate_winfiol -[txt|excel] <source> <destination>
<source> : sites (file txt/excel)
<destination> : file to WinFIOL
 * Send feedback and/or bugs to luisdecameixa\@coit.es *
END_USAGE
}

sub main {
    my $numberargv = $#ARGV + 1;
    if ( $numberargv != 3 ) {
        warn usagemsg();
        exit 1;
    }

    if ( $ARGV[0] ne '-excel' ) {
        if ( $ARGV[0] ne '-txt' ) {
            warn usagemsg();
            exit 1;
        }
    }

    my @sites = ();
    if ( $ARGV[0] eq '-excel' ) {

        # Carga y lee la columna 3 del fichero excel extraido de MaxPlanck
        # Leo del excel y guardo los codigos de site en @sites
        my $book  = ReadData( $ARGV[1] );
        my $sheet = $book->[1];
        for my $i ( 2 .. $sheet->{maxrow} ) {
            push @sites, substr( $sheet->{cell}[3][$i], 0, 7 );

            #print $fh substr( $sheet->{cell}[3][$i], 0, 7 ) . "-#\n";
        }
    }

    if ( $ARGV[0] eq '-txt' ) {

        # Carga/lee los sites de un fichero de texto
        # formato del fichero es un site por linea
        my $inputfilename = $ARGV[1];
        open( my $fin, '<', $inputfilename )
          or die "Could not open input file $inputfilename $!";
        chomp( @sites = <$fin> );

        foreach (@sites) {
            $_ = OSPcommon::trim $_;
        }
        close $fin;
    }

    # Elimina lineas vacias, y repeticiones multiples en @sites
    my $refsites = OSPcommon::RemoveMultipleElem \@sites;
    @sites = grep /\S/, @$refsites;

    # Abrir fichero de salida.
    my $outfilename = $ARGV[2];
    open( my $fout, '>', $outfilename )
      or die "Could not open output file $outfilename $!";

    # Leo la BBDD de 2G, se guarda en %DB
    my $refDB = OSPcommon::GenerateDBfromWinFIOL('OSP2GDB.txt');
    my %DB    = %$refDB;

    foreach (@sites) {
        my ( $refbscs, $reftg_numbers ) = OSPcommon::SeekBSCTG( \%DB, $_ );
        if ( not defined $refbscs or not defined $reftg_numbers ) {
            die "Wrong site code : $_\n";
        }

        # Por defecto supone MADRID
        # Esto solo es para saber a cual UAS conectarse.
        my $comunidad = substr( $_, 0, 3 );
        my $zona = 'M';
        for ($comunidad) {
            /ARA/ and do { $zona = 'B'; last; };
            /CAT/ and do { $zona = 'B'; last; };
            /RIO/ and do { $zona = 'B'; last; };
            /NAV/ and do { $zona = 'B'; last; };
            /PVA/ and do { $zona = 'B'; last; };
        }

        my $site_actual  = $_;
        my $refbsc_names = OSPcommon::RemoveMultipleElem $refbscs;
        my @bsc_names    = @$refbsc_names;
        my @tg_numbers   = @$reftg_numbers;

        if (@bsc_names) {
            foreach (@bsc_names) {
                print $fout $site_actual . "-" . $zona . "-" . $_;
                foreach (@tg_numbers) {
                    print $fout "-" . $_;
                }

            }
        }
        else { print $fout $site_actual . "-" . $zona }

        print $fout "-#\n";
    }

    print $fout 'ENDFILE';
    close $fout;
}
