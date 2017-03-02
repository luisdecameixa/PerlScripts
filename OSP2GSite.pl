#
# "THE BEER-WARE LICENSE" (Revision 42):
# <luisdecameixa@coit.es> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return Luis Diaz Gonzalez
#

# Dado el nombre de un site de OSP, el script devuelve la BSC, TG y CELLs del site

use strict;
use warnings;
use diagnostics;
use OSPcommon;

main();

sub usagemsg {
    return <<"END_USAGE";
Usage : Usage : Usage: perl OSP2GSite.pl <sitecode>
<sitecode> : OSP site code
 * Send feedback and/or bugs to luisdecameixa\@coit.es *
END_USAGE
}

sub main {
    my $num_args = $#ARGV + 1;
    if ( $num_args != 1 ) {
        warn usagemsg();
        exit 1;
    }
    my $site_name = $ARGV[0];

    my $refDB = OSPcommon::GenerateDBfromWinFIOL('OSP2GDB.txt');
    my %DB    = %$refDB;

    my ( $refbsc_names, $reftg_numbers ) = OSPcommon::SeekBSCTG( \%DB, $site_name );

    if ( not defined $refbsc_names or not defined $reftg_numbers ) {
        print "Wrong site code : $site_name\n";
        exit 0;
    }

    my @bsc_names  = @$refbsc_names;
    my @tg_numbers = @$reftg_numbers;

    if (@bsc_names) {
        if (@tg_numbers) {
            for my $i ( 0 .. $#bsc_names ) {
                ShowDBdata( \%DB, $bsc_names[$i], $tg_numbers[$i] );
            }
        }
    }
    else {
        print "Wrong site code : $site_name\n";
        exit 0;
    }

}

# showdata: Inputs-> %h (DB), $bsc, $tg.  Output-> show $bsc $tg @cells
sub ShowDBdata {
    my %h = %{ $_[0] };
    my ( $bscname, $tgnumber ) = @_[ 1, 2 ];

    foreach my $f ( keys %h ) {
        foreach my $g ( keys %{ $h{$f} } ) {
            print "$f  $g  @{$h{$f}{$g}}\n"
              if ( $g == $tgnumber and $f eq $bscname );
        }
    }

}
