#
# El objetivo de este script es generar los ficheros con las celdas presentes
# en cada una de las tecnoligías de los sites de TME.
#
#	Uso: perl TME_cells_report.pl <source>
#	Input : <source> : Fiechero de texto, una unica columna con los codigos de sites
#	Output : Ficheros con las celdas/portadoras presentes en cada site (todas las tecnologías):
#			 GSMCellReport.txt	UMTSMADRIDCellReport.txt  UMTSBARCELONACellReport.txt  LTECellReport.txt
#

use strict;
use warnings;
use diagnostics -verbose;

use LWP::Simple;
use HTML::TableExtract;
use Excel::Writer::XLSX;
use GSM;
use UMTS;
use LTE;
use TMEcommon;

###############################################################################
# Functions used for Autofit.
#
# Adjust the column widths to fit the longest string in the column.
#
sub autofit_columns {

    my $worksheet = shift;
    my $col       = 0;

    for my $width ( @{ $worksheet->{__col_widths} } ) {

        $worksheet->set_column( $col, $col, $width ) if $width;
        $col++;
    }
}

# The following function is a callback that was added via add_write_handler()
# above. It modifies the write() function so that it stores the maximum
# unwrapped width of a string in a column.
#
sub store_string_widths {

    my $worksheet = shift;
    my $col       = $_[1];
    my $token     = $_[2];

    # Ignore some tokens that we aren't interested in.
    return if not defined $token;       # Ignore undefs.
    return if $token eq '';             # Ignore blank cells.
    return if ref $token eq 'ARRAY';    # Ignore array refs.
    return if $token =~ /^=/;           # Ignore formula

    # Ignore numbers
    #return if $token =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/;

    # Ignore various internal and external hyperlinks. In a real scenario
    # you may wish to track the length of the optional strings used with
    # urls.
    return if $token =~ m{^[fh]tt?ps?://};
    return if $token =~ m{^mailto:};
    return if $token =~ m{^(?:in|ex)ternal:};

    # We store the string width as data in the Worksheet object. We use
    # a double underscore key name to avoid conflicts with future names.
    #
    my $old_width    = $worksheet->{__col_widths}->[$col];
    my $string_width = string_width($token);

    if ( not defined $old_width or $string_width > $old_width ) {

        # You may wish to set a minimum column width as follows.
        #return undef if $string_width < 10;

        $worksheet->{__col_widths}->[$col] = $string_width;
    }

    # Return control to write();
    return undef;
}

sub string_width {
    return 1.25 * length $_[0];
}
###############################################################################

sub main {
    my $numberargv = $#ARGV + 1;
    if ( $numberargv != 1 ) {
        warn "Usage : TME_cells_report <source>\n";
		exit 0;
    }

    # Primero comprobamos acceso al Inevtario de TME
    # Si no hay conexion sale dando un Aviso
    TMEcommon::TestConnection();

    # Lee los codigos de los sites del fichero sites.txt
    open my $filesites, '<', $ARGV[0]
      or die "Could not open input file '$ARGV[0]' $!";
    chomp( my @sites = sort <$filesites> );
    close $filesites;

    # Elimina lineas vacias, y repeticiones multiples en @sites
    my $refsites = TMEcommon::RemoveMultipleElem \@sites;
    @sites = grep /\S/, @$refsites;

    # Se crea el directorio para escribir los ficheros de salida
    my $outputdir = 'CellReports';
    unless ( -e $outputdir or mkdir $outputdir ) {
        die "Unable to create directory '$outputdir' $!";
    }

    # Fichero xlsx de salida con todas las celdas/portadotas por tecnología de los sites
    my $workbook  = Excel::Writer::XLSX->new("$outputdir/CellReport.xlsx");
    my $worksheet = $workbook->add_worksheet();
    $worksheet->add_write_handler( qr[\w], \&store_string_widths );

    # Ficheros de salida
    my $GSMCellReport = 'GSMCellReport.txt';
    open( my $fGSMCellReport, ">$outputdir/$GSMCellReport" )
      or die "Could not open file '$GSMCellReport' $!";

    my $UMTSMADRIDCellReport = 'UMTSMADRIDCellReport.txt';
    open( my $fUMTSMADRIDCellReport, ">$outputdir/$UMTSMADRIDCellReport" )
      or die "Could not open file '$UMTSMADRIDCellReport' $!";

    my $UMTSBARCELONACellReport = 'UMTSBARCELONACellReport.txt';
    open( my $fUMTSBARCELONACellReport, ">$outputdir/$UMTSBARCELONACellReport" )
      or die "Could not open file '$UMTSBARCELONACellReport' $!";

    my $LTECellReport = 'LTECellReport.txt';
    open( my $fLTECellReport, ">$outputdir/$LTECellReport" )
      or die "Could not open file '$LTECellReport' $!";

    # Formato del encabezado del fichero xlsx
    my $format = $workbook->add_format();
    $format->set_bold();
    $format->set_color('black');
    $format->set_align('center');
    $format->set_fg_color('#4D8BE5');    # AzulClaro (colors_hex)

    # Genera el encabezado del fichero xlsx
    $worksheet->write( "A1", "SITE", $format );
    $worksheet->write( "B1", "2G",   $format );
    $worksheet->write( "C1", "3G",   $format );
    $worksheet->write( "D1", "4G",   $format );

    my $bi = 2;
    for my $i ( 0 .. $#sites ) {

        my $refgsmcells  = GSM::getCells( $sites[$i] );
        my $refumtscells = UMTS::getCells( $sites[$i] );
        my $refltecells  = LTE::getCells( $sites[$i] );

        my @gsmcells  = @$refgsmcells;
        my @umtscells = @$refumtscells;
        my @ltecells  = @$refltecells;

        for my $icell ( 0 .. $#gsmcells ) {
            my $j = $bi + $icell;
            if ( $gsmcells[$icell] ne "" ) {
                print $fGSMCellReport $gsmcells[$icell] . "\n";
                $worksheet->write( "B$j", "$gsmcells[$icell]" );
            }
        }

        my $zona = TMEcommon::getZONA $sites[$i];

        for my $icell ( 0 .. $#umtscells ) {
            my $j = $bi + $icell;
            if ( $umtscells[$icell] ne "" ) {
                if ( $zona eq 'B' ) {
                    print $fUMTSBARCELONACellReport $umtscells[$icell] . "\n";
                }
                else {
                    print $fUMTSMADRIDCellReport $umtscells[$icell] . "\n";
                }

                $worksheet->write( "C$j", "$umtscells[$icell]" );
            }
        }

        for my $icell ( 0 .. $#ltecells ) {
            my $j = $bi + $icell;
            if ( $ltecells[$icell] ne "" ) {
                print $fLTECellReport $ltecells[$icell] . "\n";
                $worksheet->write( "D$j", "$ltecells[$icell]" );
            }
        }

        #calcula el maximo
        my @numbercells = ( $#gsmcells, $#umtscells, $#ltecells );
        my $max = $numbercells[0];
        $max = $_ > $max ? $_ : $max foreach (@numbercells);

        for ( 0 .. $max ) {
            my $j = $bi + $_;
            $worksheet->keep_leading_zeros();
            $worksheet->write( "A$j", "$sites[$i]" );
        }

        $bi += $max;
        $bi++;
    }

    autofit_columns($worksheet);

    close $fGSMCellReport;
    close $fUMTSMADRIDCellReport;
    close $fUMTSBARCELONACellReport;
    close $fLTECellReport;
    $workbook->close;
}

main();
