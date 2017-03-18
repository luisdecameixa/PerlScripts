#
# "THE BEER-WARE LICENSE" (Revision 42):
# <luisdecameixa@coit.es> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return Luis Diaz Gonzalez
#

#
# Objetivo : Filtar printado de los comandos del AMOS (logs)
#  perl AMOSCmdFilter.pl [alt|hgetm_alarmport] <logfile>
#

use strict;
use warnings;
use diagnostics;

main();

sub usage {
    return <<"END_USAGE";
Print into stdout the AMOS's command screenshot
Usage : AMOSCmdFilter.pl [alt|hgetm_alarmport] <logfile>
<logfile> : logfile
 * Send feedback and/or bugs to luisdecameixa\@coit.es *
END_USAGE
}

sub main {
    my $nargv = $#ARGV + 1;
    if ( $nargv != 2 ) {
        warn usage();
        exit 1;
    }

    my $msgend = "That's all folks!\n * Send feedback and/or bugs to luisdecameixa\@coit.es *\n";

    my $cmd = $ARGV[0];

    # Carga/lee los sites de un fichero de texto
    # formato del fichero es un site por linea
    my $inputfilename = $ARGV[1];

    open( my $fin, '<', $inputfilename )
      or die "Could not open input file $inputfilename $!";
    chomp( my @a = <$fin> );
    close $fin;

    for ($cmd) {
        /alt/ and do {
            alt_filter( \@a );
            last;
        };

        /hgetm_alarmport/ and do {
            hgetm_alarmport_filter( \@a );
            last;
        };
		
		warn usage();
    }

    print $msgend;
    exit 0;

}


sub alt_filter {
    my @lines = @{ $_[0] };

    for my $i ( 0 .. $#lines ) {

        if ( $lines[$i] =~ /.*alt$/ ) {

            #print "LINEA >$line[$i]<\n";

            my ( $nodo, $command ) = split /\s+/, $lines[$i], 3;
			my $mayor;
            $mayor = chop $nodo if ( defined $nodo );
            if ( defined $command && $mayor eq '>' ) {
                for ($command) {
                    /^al.*$/ and do {

                        while ( $lines[$i] !~ /.*Total:.*/ ) {
                            print $lines[$i] . "\n";
                            $i++;

                        }

                        print $lines[$i] . "\n";
                        $i++;

                        print "\n";
                        print "*" x 120 . "\n";
                        print "#" x 120 . "\n";
                        print "*" x 120 . "\n";
                        print "\n";
                        last;

                      }
                }
            }

        }
    }
}

sub hgetm_alarmport_filter {
    my @lines = @{ $_[0] };

    for my $i ( 0 .. $#lines ) {

        if ( $lines[$i] =~ /.*hgetm alarmport.*/ ) {

            #print "LINEA >$lines[$i]<\n";

            my ( $nodo, $command ) = split /\s+/, $lines[$i], 3;

            #print $command . "\n";
			my $mayor;
            $mayor = chop $nodo if ( defined $nodo );
            if ( defined $command && $mayor eq '>' ) {
                for ($command) {
                    /hgetm/ and do {

                        while ( $lines[$i] !~ /.*Total:.*/ ) {
                            print $lines[$i] . "\n";
                            $i++;

                        }

                        print $lines[$i] . "\n";
                        $i++;

                        print "\n";
                        print "*" x 120 . "\n";
                        print "#" x 120 . "\n";
                        print "*" x 120 . "\n";
                        print "\n";
                        last;

                      }
                }
            }

        }
    }
}




