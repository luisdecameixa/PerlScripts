#
# "THE BEER-WARE LICENSE" (Revision 42):
# <luisdecameixa@coit.es> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return Luis Diaz Gonzalez
#

#
# El objetivo es facilitar la comprobación por KPIs en OSP (M.A.Q.A)
#

use strict;
use warnings;
use diagnostics;

use Spreadsheet::Read;
use POSIX qw(strftime);
use LWP::Simple qw(get);

####
my $url1 = 'https://manuelbonales.sytes.net/private/';
my $url2 = 'https://manuelbonales.no-ip.biz/private/';
my $url3 = 'https://manuelbonales.redirectme.net/private/';
####
my $url  = $url3;

main();

sub msgbugs {
    return '** Send feedback and/or bugs to luisdecameixa@coit.es **' . "\n";
}

sub usage_commands {
    return <<"END_USAGE_COMMANDS";
*************************** Commands **************************
* <ENTER>          : go to next site                          *  
* [ prev | p ]     : go back to previous site                 *
* [ load | l ]     : load again the actual site               *
* [ jump | j ] <n> : jump to line <n> & show site's KPI       *
* [ show | s ] <n> : NO jump to line <n>, but show site's KPI *
* [ yday | y ] [n] : show site's KPIs of yerterday            *
* [ help | h ]     : show help                                *
* [ quit | q ]     : exit                                     *
***************************************************************
END_USAGE_COMMANDS
}

sub usage {
    warn <<"END_USAGE";
Usage : OSPKPIs.pl -[txt|excel] <input file> <date>
Example : OSPKPIs.pl -txt KPItable.txt 201608162330
Example : OSPKPIs.pl -txt KPItable.txt now
END_USAGE

    warn usage_commands();
    warn msgbugs();
}

sub main {
    my $nARGV = $#ARGV + 1;
    if ( $nARGV != 3 ) {
        usage();
        exit 1;
    }

    if ( $ARGV[0] ne '-excel' ) {
        if ( $ARGV[0] ne '-txt' ) {
            usage();
            exit 1;
        }
    }
    my @line = ();
    if ( $ARGV[0] eq '-excel' ) {

        # Carga y lee las columnas 1 y 2 del fichero excel de KPIs OSP
        # Leo del excel y guardo los codigos de site en @sites
        my $book  = ReadData( $ARGV[1] );
        my $sheet = $book->[1];
        for my $i ( 2 .. $sheet->{maxrow} ) {
            if (    defined $sheet->{cell}[1][$i]
                and defined $sheet->{cell}[2][$i] )
            {
                if (    $sheet->{cell}[1][$i] !~ /^\s*$/
                    and $sheet->{cell}[2][$i] !~ /^\s*$/ )
                {

                    push @line, substr( $sheet->{cell}[1][$i], 0, 7 ) . " " . substr( $sheet->{cell}[2][$i], 0, 6 );
                }
            }
        }
    }

    if ( $ARGV[0] eq '-txt' ) {

        # Carga/lee los sites de un fichero de texto
        # formato del fichero es un site por linea
        my $inputfilename = $ARGV[1];
        open( my $fin, '<', $inputfilename )
          or die "Could not open input file $inputfilename $!";
        chomp( @line = <$fin> );
        close $fin;
    }

    my $fecha_arg = $ARGV[2];    # '201608162330'
    if ( $fecha_arg eq 'now' ) {
        $fecha_arg = strftime '%Y%m%d%H%M', localtime;
    }

    #print $fecha_arg. "\n";
    if ( $fecha_arg !~ /^\d{12}$/ ) {
        print "Wrong date.\n";
        exit 1;
    }

    for ( my $i = 0 ; $i <= $#line ; $i++ ) {

      START:
        my $fecha = $fecha_arg;
        my ( $emplazamiento, $zone ) = split /\s+/, $line[$i], 2;

      STARTSHOW:
        my ( $ok, $prefixsite, $code, $zone_code ) = get_check_site_code_zone( $emplazamiento, $zone );

        if ( $ok == 3 ) {
            print "Checking : $emplazamiento\t$zone\n";
            open_2g( $url, $prefixsite, $code, $zone_code, $fecha );
            open_3g( $url, $prefixsite, $code, $zone_code, $fecha );
            open_4g( $url, $emplazamiento, $zone_code, $fecha );
        }
        else {
            print "Site code or ZONE are wrong!!\nCheck it : $line[$i]\n";
            exit 1;
        }

      PROMPT:
        if ( $ARGV[0] eq '-txt' ) {
            print 'OSPKPI ' . ( $i + 1 ) . ' ' . $emplazamiento . '> ';
        }
        else {
            print 'OSPKPI ' . ( $i + 2 ) . ' ' . $emplazamiento . '> ';
        }

        chomp( my $command = <STDIN> );
        $command =~ s/^\s+|\s+$//g;
        my @command_values = split /\s+/, $command;

        if ( defined $command_values[0] ) {

            # print "comando :>$command_values[0]<\n";
            for ( $command_values[0] ) {
                /^(quit|q)/ and do {
                    print "Goodbye.\n";
                    exit 0;
                };

                /^(help|h)/ and do {
                    warn usage_commands();
                    warn msgbugs();
                    goto PROMPT;
                };

                /^(load|l)/ and do {
                    goto START;
                };

                /^(prev|p)/ and do {
                    if ( $i == 0 ) {
                        goto START;
                    }
                    $i--;
                    goto START;
                };

                /^(jump|j)/ and do {
                    if ( $command_values[1] =~ /\d+/ ) {
                        my $i_tmp = $command_values[1] - 2;
                        if ( $i_tmp > $#line || $i_tmp < 0 ) {
                            print "Out of range!\n";
                            goto PROMPT;
                        }
                        $i = $i_tmp;
                        goto START;
                    }
                    else {
                        print "Ooops!\n";
                        goto PROMPT;
                    }
                };

                /^(show|s)/ and do {
                    if ( $command_values[1] =~ /\d+/ ) {
                        my $i_tmp = $command_values[1] - 2;
                        if ( $i_tmp > $#line || $i_tmp < 0 ) {
                            print "Out of range!\n";
                            goto PROMPT;
                        }
                        ( $emplazamiento, $zone ) =
                          split /\s+/, $line[$i_tmp], 2;
                        goto STARTSHOW;
                    }
                    else {
                        print "Ooops!\n";
                        goto PROMPT;
                    }
                };

                /^(yday|y)/ and do {
                    my $i_tmp;

                    if ( defined $command_values[1] ) {
                        if ( $command_values[1] =~ /\d+/ ) {
                            $i_tmp = $command_values[1] - 2;
                            if ( $i_tmp > $#line || $i_tmp < 0 ) {
                                print "Out of range!\n";
                                goto PROMPT;
                            }
                        }
                    }
                    else { $i_tmp = $i }

                    $fecha = strftime '%Y%m%d%H%M', localtime( time - 86400 );

                    ( $emplazamiento, $zone ) =
                      split /\s+/, $line[$i_tmp], 2;

                    goto STARTSHOW;
                };

                !/^\s*$/ and do {
                    print "Ooops!\n";
                    goto PROMPT;
                };
            }
        }
    }
}

sub get_check_site_code_zone {
    my $site = shift;
    my $zone = shift;

    my $comunidad = substr( $site, 0, 3 );
    my $code      = substr( $site, 3, 4 );

    # checking zone...
    my $zone_code;
    my $zone_ok = 0;
    for ($zone) {
        /^(ZONA|ZONE) 1$/ and do { $zone_ok = 1; $zone_code = 'z1'; last; };
        /^(ZONA|ZONE) 2$/ and do { $zone_ok = 1; $zone_code = 'z2'; last; };
        /^(ZONA|ZONE) 3$/ and do { $zone_ok = 1; $zone_code = 'z3'; last; };
        /^(ZONA|ZONE) 5$/ and do { $zone_ok = 1; $zone_code = 'z5'; last; };
    }

    # checking comunidad...
    my $prefixsite;
    my $comunidad_ok = 0;
    for ($comunidad) {
        /ARA/ and do { $comunidad_ok = 1; $prefixsite = 'R'; last; };
        /AST/ and do { $comunidad_ok = 1; $prefixsite = 'S'; last; };
        /CTB/ and do { $comunidad_ok = 1; $prefixsite = 'T'; last; };
        /CLM/ and do { $comunidad_ok = 1; $prefixsite = 'X'; last; };
        /CYL/ and do { $comunidad_ok = 1; $prefixsite = 'Z'; last; };
        /CAT/ and do { $comunidad_ok = 1; $prefixsite = 'C'; last; };
        /GAL/ and do { $comunidad_ok = 1; $prefixsite = 'G'; last; };
        /RIO/ and do { $comunidad_ok = 1; $prefixsite = 'J'; last; };
        /MAD/ and do { $comunidad_ok = 1; $prefixsite = 'M'; last; };
        /NAV/ and do { $comunidad_ok = 1; $prefixsite = 'N'; last; };
        /PVA/ and do { $comunidad_ok = 1; $prefixsite = 'P'; last; };
    }

    # checking numeric code...
    my $code_ok = 0;
    if ( $code =~ /^\d{4}$/ ) {
        $code_ok = 1;
    }

    # Triple-check : $zone_ok + $comunidad_ok + $code_ok
    return ( $zone_ok + $comunidad_ok + $code_ok, $prefixsite, $code, $zone_code );
}

sub open_2g {
    my $web     = shift;
    my $presite = shift;
    my $code    = shift;
    my $zona    = shift;
    my $date    = shift;
	
    my $site2g = $presite . $code;
    my $cmd;

    for ($zona) {
        /z1|z2|z5/ and do {
            $cmd =
                "start chrome \"$web" . "$zona"
              . '/stats/online/kpi2ge-' . "$zona"
              . '?tipo=hb&nodo='
              . "$site2g"
              . '&fecha=' . "$date" . '"';
            last;
        };

        /z3/ and do {
            $cmd =
                "start chrome \"$web" . "$zona"
              . '/stats/online/kpi2ge-z3?tipo=qrl&nodo='
              . "$site2g"
              . '&fecha=' . "$date" . '"';
            last;
        };
    }

    system($cmd);
}

sub open_3g {
    my $web     = shift;
    my $presite = shift;
    my $code    = shift;
    my $zona    = shift;
    my $date    = shift;

    my $site3g = $presite . $code;

    my $cmd;
    for ($zona) {
        /z1|z2|z5/ and do {
            $cmd =
                "start chrome \"$web" . "$zona"
              . '/stats/online/kpi3ge-' . "$zona"
              . '?tipo=rabhb&nodo='
              . "$site3g"
              . '&fecha=' . "$date" . '"';
            last;
        };

        /z3/ and do {
            $cmd =
                "start chrome \"$web" . "$zona"
              . '/stats/online/kpi3ghz3?tipo=rabhb&nodo='
              . "$site3g"
              . '&fecha=' . "$date" . '"';
            last;
        };
    }
    system($cmd);
}

sub open_4g {
    my $web  = shift;
    my $site = shift;
    my $zona = shift;
    my $date = shift;

    my $code      = substr( $site, 3, 4 );
    my $comunidad = substr( $site, 0, 3 );
    my $site4g    = $comunidad . 'X' . $code;

    my $cmd =
        "start chrome \"$web" . "$zona"
      . '/stats/online/kpi4ge-' . "$zona"
      . '?tipo=rabhb&nodo='
      . "$site4g"
      . '&fecha=' . "$date" . '"';

    system($cmd);
}
