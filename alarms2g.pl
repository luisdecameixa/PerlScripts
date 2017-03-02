#
# "THE BEER-WARE LICENSE" (Revision 42):
# <luisdecameixa@coit.es> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return Luis Diaz Gonzalez
#

use strict;
use warnings;

#use diagnostics;

my %alarm;
my %replunit;

main();

sub msghelp {
    return <<"END_USAGE";
---------------------------------------------------------------------------------
Usage : alarms2g.pl <device> <alarmcode>
<devices> : CF TRXC TRX CON RX TF TS TX MCTR
Example: alarms2g.pl MCTR I2A:20
---------------------------------------------------------------------------------
Usage : alarms2g.pl rxelp <device> <alarmmap> <alarmcode1> <alarmcode2>
<devices> : xxxCF xxxTRXC xxxTRX xxxCON xxxRX xxxTF xxxTS xxxTX xxxMCTR
<alarmmap> : REPLMAP | 1AMAP | 1BMAP | 2AMAP | EXT1BMAP | EXT2BMAP | EXT2BMAPEXT
Example: alarms2g.pl rxelp RXOCF 1AMAP 000000000000 000000000001
---------------------------------------------------------------------------------
Usage : alarms2g.pl log2g <logfile>
Example: alarms2g.pl log2g MAD6151.Log2G.MAD60B4.txt
---------------------------------------------------------------------------------
Usage : alarms2g.pl rxelplog2g <verbose> <logfile>
<verbose> : 0->NO  1->YES
Example: alarms2g.pl rxelplog2g 0 MAD6151.Log2G.MAD60B4.txt
---------------------------------------------------------------------------------
>>  * Send feedback and/or bugs to luisdecameixa\@coit.es *  <<
END_USAGE
}

sub main {
    if ( !defined $ARGV[0] ) {
        warn msghelp();
        exit 1;
    }

    my $msgend = "That's all folks!\n * Send feedback and/or bugs to luisdecameixa\@coit.es *\n";

    ## Caso 1 : default command : alarms2g.pl <device> <alarmcode>
    if ( $ARGV[0] !~ /^(rxelp|log2g|rxelplog2g)$/ ) {
        my $nargs = $#ARGV + 1;
        if ( $nargs != 2 ) {
            warn msghelp();
            exit 1;
        }

        # Input parameters
        my $dev  = $ARGV[0];
        my $code = $ARGV[1];

        if ( $dev eq 'TRX' ) { $dev .= 'C' }
        my $codealarm = $dev . ' ' . $code;
        if ( exists $alarm{$codealarm} ) {
            print $codealarm . ' (' . $alarm{$codealarm} . ")\n";
        }
        else {
            print "Oops!. Alarm's comment isn't in our database.\n\n";
            warn msghelp();
            exit 1;
        }
        print $msgend;
        exit 0;
    }
###
## Caso 2 : rxelp command : alarms2g.pl rxelp <device> <alarmmap> <alarmcode1> <alarmcode2> <alarmcode3>
    if ( $ARGV[0] =~ /^rxelp$/ ) {

        my $nargs = $#ARGV + 1;

        # main input parameters
        my $dev      = $ARGV[1];
        my $alarmmap = $ARGV[2];

        substr( $dev, 0, 3 ) = '';
        if ( $dev !~ /(CF|TRXC|TRX|CON|RX|TF|TS|TX|MCTR)/ ) {
            warn msghelp();
            exit 1;
        }

        if ( $alarmmap !~ /(REPLMAP|1AMAP|1BMAP|2AMAP|EXT1BMAP|EXT2BMAP|EXT2BMAPEXT)/ ) {
            warn msghelp();
            exit 1;
        }

        my @out;

        for ($nargs) {
            /4/ and do {
                my $alarmcode1 = $ARGV[3];
                if ( $alarmmap =~ /(EXT1BMAP|EXT2BMAP|EXT2BMAPEXT)/ ) {
                    @out = rxelp_dec( $dev, $alarmmap, $alarmcode1 );
                }
                last;
            };

            /5/ and do {
                my $alarmcode1 = $ARGV[3];
                my $alarmcode2 = $ARGV[4];

                if ( $alarmmap =~ /(REPLMAP|1AMAP|1BMAP|2AMAP)/ ) {
                    @out = rxelp_dec( $dev, $alarmmap, $alarmcode1 . $alarmcode2 );
                }
                last;
            };

            /6/ and do {
                my $alarmcode1 = $ARGV[3];
                my $alarmcode2 = $ARGV[4];
                my $alarmcode3 = $ARGV[5];

                if ( $alarmmap =~ /2AMAP/ ) {
                    @out = rxelp_dec( $dev, $alarmmap, $alarmcode1 . $alarmcode2 . $alarmcode3 );
                }
                last;
            };
        }

        if ( $alarmmap !~ /REPLMAP/ ) {
            print_alarm(@out);
        }
        else {    # if ( $alarmmap =~ /REPLMAP/ )
            print_replunit(@out);
        }

        print $msgend;
        exit 0;
    }
###
## Caso 3: log2g command : alarms2g.pl log2g <infile.txt> > <outfile.txt>
    if ( $ARGV[0] =~ /^log2g$/ ) {
        my $nargs = $#ARGV + 1;
        if ( $nargs != 2 ) {
            warn msghelp();
            exit 1;
        }

        my $filename = $ARGV[1];

        open( my $f, '<', $filename ) or die "Can't open $filename: $!";

        log2g_decode_active_alarms($f);

        close $f;
        print $msgend;
        exit 0;
    }
###
## Caso 4 : rxelplog2g command : alarms2g.pl rxelplog2g <infile.txt> > <outfile.txt>
    if ( $ARGV[0] =~ /^rxelplog2g$/ ) {
        my $nargs = $#ARGV + 1;
        if ( $nargs != 3 ) {
            warn msghelp();
            exit 1;
        }

        my $verbose  = $ARGV[1];
        my $filename = $ARGV[2];

        open( my $f, '<', $filename ) or die "Can't open $filename: $!";

        rxelplog2g_decode_alarms( $f, $verbose );

        close $f;
        print $msgend;
        exit 0;
    }
}


# hex-string to bin-string
# hex : string
# return : string
sub hex_to_bin {
    my $hex    = shift;
    my $hexlen = length($hex);
    my $binlen = $hexlen * 4;
    return unpack( "B$binlen", pack( "H$hexlen", $hex ) );
}

# devuelve el n-esimo caracter de una string
# cadena : $_[0]
# posn   : $_[1]
sub getn {
    my ( $cadena, $posn ) = @_;
    return substr $cadena, $posn - 1, 1;
}

# decodifica rxelp
# input :
#	$_[0] dev  (xxxCF xxxTRXC xxxTRX xxxCON xxxRX xxxTF xxxTS xxxTX xxxMCTR)
#   $_[1] mapa  (REPLMAP, 1AMAP, 1BMAP, 2AMAP, EXT1BMAP, EXT2BMAP)
#   $_[2] code (alarmas activas: 000000000000 000000000001)
# output :
#	array con las alarmas (CF I1A:0, CF I2A:4)
sub rxelp_dec {
    my ( $device, $mapa, $code ) = @_;

    my $internal_alarm = undef;

    my $type;    # tipo de map
    if ( $mapa =~ /(1AMAP|1BMAP|2AMAP)/ ) {
        $internal_alarm = 1;          # 1 -> internal alarm
        $type = substr $mapa, 0, 2;
    }

    if ( $mapa =~ /(EXT1BMAP|EXT2BMAP|EXT2BMAPEXT)/ ) {
        $internal_alarm = 0;          # 0 -> external alarm
        $type = substr $mapa, 3, 2;
    }

    #print "$dev $type $code\n";
    my $bincode = hex_to_bin($code);

    #print "bincode " . $bincode . "\n";
    my $lenbincode = length($bincode);
    my @ret;

    for my $i ( 1 .. $lenbincode ) {

        # get the char at position $i of $bincode string
        my $getchar = substr $bincode, $i - 1, 1;

        #if ( getn( $bincode, $i ) eq '1' ) {
        if ( $getchar eq '1' ) {

            #print $i . "\n";
            my $num = $lenbincode - $i;
            if ( $device eq 'TRX' ) { $device .= 'C' }

            if ( $mapa !~ /REPLMAP/ ) {
                if ($internal_alarm) {
                    push @ret, $device . ' I' . $type . ':' . $num;
                }
                else {
                    push @ret, $device . ' EC' . $type . ':' . $num;
                }
            }

            if ( $mapa =~ /REPLMAP/ ) {
                push @ret, $device . ' ' . $num;
            }

        }
    }
    return @ret;
}

# input: array con las alarmas (CF I1A:0, CF I2A:3)
sub print_alarm {
    foreach (@_) {
        if ( exists $alarm{$_} ) {
            print $_ . ' - ' . $alarm{$_} . "\n";
        }
        else {
            print "$_ : Oops!. Alarm's comment isn't in our database.\n";

        }
    }

}

sub print_replunit {
    foreach (@_) {
        if ( exists $replunit{$_} ) {
            print 'RU : ' . $_ . ' - ' . $replunit{$_} . "\n";
        }
        else {
            print "RU : $_ : Oops!. Replunit's comment isn't in our database.\n";

        }
    }
}

# leer las alarmas 2G activas de un fichero log, las decodifica y muestra por pantalla
# input :
# $_[0] : fh fichero log
sub log2g_decode_active_alarms {
    my $f = shift;

    while (<$f>) {
        chomp;

        if ( $_ =~ /^MANAGED OBJECT FAULT INFORMATION$/ ) {
            my $dev;
            while (<$f>) {
                chomp;

                my $atype;
                my @splitline;

                if ( $_ =~ /^MO\s+/ ) {
                    print "\n";
                    $_ = <$f>;    # next line
                    chomp;

                    @splitline = split /\s/, $_;
                    my @splitDeviceName = split /-/, $splitline[0];
                    print "$splitline[0]\n";
                    substr( $splitDeviceName[0], 0, 3 ) = '';
                    $dev = $splitDeviceName[0];
                }

                #print "Device name : >$dev<\n";

                my $InternalORExternalAlarm = undef;

                # $InternalORExternalAlarm = ' I'  if ( $line =~ /^FAULT CODES CLASS\s+/ );
                # $InternalORExternalAlarm = ' EC' if ( $line =~ /^EXTERNAL FAULT CODES CLASS\s+/ );

                for ($_) {
                    /^FAULT CODES CLASS\s+/          and do { $InternalORExternalAlarm = ' I';  last };
                    /^EXTERNAL FAULT CODES CLASS\s+/ and do { $InternalORExternalAlarm = ' EC'; last };
                }

                if ( defined $InternalORExternalAlarm ) {

                    print $_. "\n";
                    chomp;
                    @splitline = split /\s/, $_;
                    $atype = $splitline[$#splitline];

                    #print "Tipo de alarma >$atype<\n";

                    $_ = <$f>;    # next line
                    print;
                    chomp;
                    my @number_alarm = split /\s/, $_;
                    @number_alarm = grep /\d/, @number_alarm;
                    foreach (@number_alarm) {

                        if ( $dev eq 'TRX' ) { $dev .= 'C'; }

                        my $codealarm = $dev . $InternalORExternalAlarm . $atype . ':' . $_;

                        #print ">$codealarm<\n";
                        if ( exists $alarm{$codealarm} ) {
                            print $codealarm . ' (' . $alarm{$codealarm} . ")\n";
                        }
                        else {
                            print 'Oops!.' . ' Alarm\'s comment isn\'t in our database.' . "\n";
                        }

                        #print "\n";
                    }
                }

                if ( $_ =~ /^REPLACEMENT UNITS/ ) {

                    #print "device >$dev<\n";
                    if ( $dev =~ /CF|TRXC/ ) {
                        print $_ . "\n";
                        $_ = <$f>;    # next line
                        print;
                        chomp;
                        my @number_ru = split /\s/, $_;
                        @number_ru = grep /\d/, @number_ru;

                        #print ">$dev<\n";
                        foreach (@number_ru) {
                            my $ru = $dev . ' ' . $_;

                            #print ">$ru<\n";
                            if ( exists $replunit{$ru} ) {
                                print $ru . ' (' . $replunit{$ru} . ")\n";
                            }
                            else {
                                print 'Oops!.' . ' REPLACEMENT UNIT\'s comment isn\'t in our database.' . "\n";
                            }
                        }

                    }

                    #print "\n";
                }

                last if ( $_ =~ /^END$/ );
            }

        }
    }
}

# leer las alarmas 2G de un fichero log, las decodifica y muestra por pantalla
# input :
# $_[0] : fh fichero log
sub rxelplog2g_decode_alarms {
    my ( $f, $verbose ) = @_;

    my @out;
    while (<$f>) {
        chomp;

        # my flag;
        # flag = 1 if ( $line =~ /^ERROR LOG DATA$/ );

        if ( $_ =~ /^FAULT INFORMATION LOG$/ ) {
            my $dev;
            while (<$f>) {
                chomp;
                my @splitline;

                if ( $_ =~ /^MO\s+/ ) {
                    print $_ . "\n";
                    $_ = <$f>;    # next line
                    print $_ . "\n";
                    chomp $_;

                    @splitline = split /\s+/, $_;
                    my @splitDeviceName = split /-/, $splitline[0];
                    $dev = $splitDeviceName[0];
                    substr( $dev, 0, 3 ) = '';
                    if ( $dev eq 'TRX' ) { $dev .= 'C' }

                    $_ = <$f>;    # next line (empty line)
                    $_ = <$f>;    # next line (labels : REPLMAP & 1AMAP)
                    print if ( $verbose == 1 );
                    $_ = <$f>;                      # next line
                    @splitline = split /\s+/, $_;
                    print $_ . "\n" if ( $verbose == 1 );

                    @out = rxelp_dec( $dev, 'REPLMAP', $splitline[0] . $splitline[1] );
                    print_replunit(@out);
                    @out = rxelp_dec( $dev, '1AMAP', $splitline[2] . $splitline[3] );
                    print_alarm(@out);

                    ##
                    $_ = <$f>;                      # next line (empty line)
                    $_ = <$f>;                      # next line (labels : 1BMAP & 2AMAP)
                    print if ( $verbose == 1 );
                    $_ = <$f>;                      # next line

                    @splitline = split /\s+/, $_;
                    print $_ . "\n" if ( $verbose == 1 );

                    @out = rxelp_dec( $dev, '1BMAP', $splitline[0] . $splitline[1] );
                    print_alarm(@out);

                    @out = rxelp_dec( $dev, '2AMAP', $splitline[2] . $splitline[3] )
                      if ( $#splitline == 3 );

                    @out = rxelp_dec( $dev, '2AMAP', $splitline[2] . $splitline[3] . $splitline[4] )
                      if ( $#splitline == 4 );

                    print_alarm(@out);

                    $_ = <$f>;    # next line (empty line)
                    $_ = <$f>;    # next line (labels : EXT1BMAP & EXT2BMAP & EXT2BMAPEXT)
                    print if ( $verbose == 1 );
                    $_ = <$f>;    # next line

                    @splitline = split /\s+/, $_;
                    print $_ . "\n" if ( $verbose == 1 );

                    @out = rxelp_dec( $dev, 'EXT1BMAP', $splitline[0] );
                    print_alarm(@out);
                    @out = rxelp_dec( $dev, 'EXT2BMAP', $splitline[1] );
                    print_alarm(@out);

                    if ( $#splitline == 1 ) {
                        @out = rxelp_dec( $dev, 'EXT2BMAPEXT', '00000000' );
                    }
                    else {
                        @out = rxelp_dec( $dev, 'EXT2BMAPEXT', $splitline[2] );
                    }
                    print_alarm(@out);
                    print "-" x 63 . "\n";

                }

                last if ( $_ =~ /^END$/ );
            }

        }
    }
}


BEGIN {
    # alarms database
    %alarm = (
        'CF I1A:0'     => 'Reset, Automatic Recovery',
        'CF I1A:1'     => 'Reset, Power On',
        'CF I1A:2'     => 'Reset, Switch',
        'CF I1A:3'     => 'Reset, Watchdog',
        'CF I1A:4'     => 'Reset, SW Fault',
        'CF I1A:5'     => 'Reset, RAM Fault',
        'CF I1A:6'     => 'Reset, Internal Function Change',
        'CF I1A:7'     => 'XBus Fault',
        'CF I1A:8'     => 'Timing Unit VCO Fault',
        'CF I1A:9'     => 'Timing Bus Fault',
        'CF I1A:10'    => 'Indoor Temp Out of Safe Range',
        'CF I1A:12'    => 'DC Voltage Out of Range',
        'CF I1A:14'    => 'Bus Fault',
        'CF I1A:15'    => 'IDB Corrupted',
        'CF I1A:16'    => 'RU Database Corrupted',
        'CF I1A:17'    => 'HW and IDB Inconsistent',
        'CF I1A:18'    => 'Internal Configuration Failed',
        'CF I1A:19'    => 'HW and SW Inconsistent',
        'CF I1A:21'    => 'HW Fault',
        'CF I1A:22'    => 'Air Time Counter Lost',
        'CF I1A:23'    => 'Time Distribution Fault',
        'CF I1A:24'    => 'Temperature Close to Destructive Limit',
        'CF I2A:1'     => 'Reset, Power On',
        'CF I2A:2'     => 'Reset, Switch',
        'CF I2A:3'     => 'Reset, Watchdog',
        'CF I2A:4'     => 'Reset, SW Fault',
        'CF I2A:5'     => 'Reset, RAM Fault',
        'CF I2A:6'     => 'Reset, Internal Function Change',
        'CF I2A:7'     => 'RX Internal Amplifier Fault',
        'CF I2A:8'     => 'VSWR Limits Exceeded',
        'CF I2A:9'     => 'Power Limits Exceeded',
        'CF I2A:10'    => 'DXU-Opt EEPROM Checksum Fault',
        'CF I2A:12'    => 'RX Maxgain/Mingain Violated',
        'CF I2A:13'    => 'Timing Unit VCO Ageing',
        'CF I2A:14'    => 'CDU Supervision/Communication Lost',
        'CF I2A:15'    => 'VSWR/Output Power Supervision Lost',
        'CF I2A:16'    => 'Indoor Temp Out of Normal Conditional Range',
        'CF I2A:17'    => 'Indoor Humidity',
        'CF I2A:18'    => 'DC Voltage Out of Range',
        'CF I2A:19'    => 'Power and Climate System in Standalone Mode',
        'CF I2A:21'    => 'Internal Power Capacity Reduced',
        'CF I2A:22'    => 'Battery Backup Capacity Reduced',
        'CF I2A:23'    => 'Climate Capacity Reduced',
        'CF I2A:24'    => 'HW Fault',
        'CF I2A:25'    => 'Loadfile Missing in DXU or ECU',
        'CF I2A:26'    => 'Climate Sensor Fault',
        'CF I2A:27'    => 'System Voltage Sensor Fault',
        'CF I2A:28'    => 'A/D Converter Fault',
        'CF I2A:29'    => 'Varistor Fault',
        'CF I2A:30'    => 'Bus Fault',
        'CF I2A:31'    => 'High Frequency of Software Fault',
        'CF I2A:32'    => 'Non-volatile Memory Corrupted',
        'CF I2A:33'    => 'RX Diversity Lost',
        'CF I2A:34'    => 'Output Voltage Fault',
        'CF I2A:35'    => 'Optional Synchronization Source',
        'CF I2A:36'    => 'RU Database Corrupted',
        'CF I2A:37'    => 'Circuit Breaker Tripped or Fuse Blown',
        'CF I2A:38'    => 'Default Values Used',
        'CF I2A:39'    => 'RX Cable Disconnected',
        'CF I2A:40'    => 'Reset, DXU Link Lost',
        'CF I2A:41'    => 'Lost Communication to TRU',
        'CF I2A:42'    => 'Lost Communication to ECU',
        'CF I2A:43'    => 'Internal Configuration Failed',
        'CF I2A:44'    => 'ESB Distribution Failure',
        'CF I2A:45'    => 'High Temperature',
        'CF I2A:46'    => 'DB Parameter Fault',
        'CF I2A:47'    => 'Antenna Hopping Failure',
        'CF I2A:48'    => 'GPS Synch Fault',
        'CF I2A:49'    => 'Battery Backup Time Shorter Than Expected',
        'CF I2A:50'    => 'RBS Running on Battery',
        'CF I2A:51'    => 'TMA Supervision/Communications Lost',
        'CF I2A:52'    => 'CXU Supervision/Communication Lost',
        'CF I2A:53'    => 'HW and IDB Inconsistent',
        'CF I2A:54'    => 'Timing Bus Fault',
        'CF I2A:55'    => 'XBus Fault',
        'CF I2A:57'    => 'RX Path Imbalance',
        'CF I2A:58'    => 'Disconnected',
        'CF I2A:59'    => 'Operating Temperature Too High, Main Load',
        'CF I2A:60'    => 'Operating Temperature Too High, Battery',
        'CF I2A:61'    => 'Operating Temperature Too High, Capacity Reduced',
        'CF I2A:62'    => 'Operating Temperature Too Low, Capacity Reduced',
        'CF I2A:63'    => 'Operating Temperature Too High, No Service',
        'CF I2A:64'    => 'Operating Temperature Too Low, Communication',
        'CF I2A:65'    => 'Battery Voltage Too Low, Main Load Disconnected',
        'CF I2A:66'    => 'Battery Voltage Too Low, Prio Load Disconnected',
        'CF I2A:67'    => 'System Undervoltage',
        'CF I2A:68'    => 'System Overvoltage',
        'CF I2A:69'    => 'Cabinet Product Data Mismatch',
        'CF I2A:70'    => 'Battery Missing',
        'CF I2A:71'    => 'Low Battery Capacity',
        'CF I2A:72'    => 'Software Load of RUS Failed',
        'CF I2A:73'    => 'Degraded or Lost Communication to Radio Unit',
        'CF I2A:79'    => 'Configuration Fault of CPRI System',
        'CF I2A:80'    => 'Antenna System DC Power Supply Overloaded',
        'CF I2A:81'    => 'Primary Node Disconnected',
        'CF I2A:82'    => 'Radio Unit Incompatible',
        'CF I2A:83'    => 'Radio Unit Connection Fault',
        'CF I2A:84'    => 'Unauthorized External Process Hunt',
        'CF I2A:85'    => 'Unused MCPA, Capacity Reduced',
        'CF I2A:86'    => 'Low Battery Capacity, Battery Test',
        'CF I2A:87'    => 'Radio Unit HW Fault',
        'CF I2A:88'    => 'CPRI Delay Too Long',
        'CF I2A:89'    => 'DU Degraded - TRX functionality lost',
        'CF I2A:90'    => 'Ring Redundancy Lost',
        'CF I2A:91'    => 'Fan Power Reduced',
        'CF I2A:92'    => 'Secondary node Disconnected',
        'CF I2A:93'    => 'Alarm Port Inconsistent Configuration',
        'CF I2A:94'    => 'Feeder Connectivity Fault',
        'CF EC1B:2'    => 'LMT (BTS Locally Disconnected)',
        'CF EC1B:4'    => 'L/R SWI (BTS in Local Mode)',
        'CF EC1B:5'    => 'L/R TI (Local to Remote While Link Lost)',
        'CF EC1B:9'    => 'Smoke Alarm',
        'CF EC2B:2'    => 'Limited Super Channel Support',
        'CF EC2B:3'    => 'Smoke Alarm Faulty',
        'CF EC2B:4'    => 'TP (Technician Present)',
        'CF EC2B:5'    => 'Alarm Suppr',
        'CF EC2B:6'    => 'O&M Link Disturbed',
        'CF EC2B:9'    => 'RBS DOOR (RBS Cabinet Door Open)',
        'CF EC2B:10'   => 'MAINS FAIL (External Power Source Failure)',
        'CF EC2B:11'   => 'ALNA/TMA Fault',
        'CF EC2B:12'   => 'ALNA/TMA Degraded',
        'CF EC2B:13'   => 'Auxiliary Equipment Fault',
        'CF EC2B:14'   => 'Battery Backup External Fuse Fault',
        'TRXC I1A:0'   => 'Reset, Automatic Recovery',
        'TRXC I1A:1'   => 'Reset, Power On',
        'TRXC I1A:2'   => 'Reset, Switch',
        'TRXC I1A:3'   => 'Reset, Watchdog',
        'TRXC I1A:4'   => 'Reset, SW Fault',
        'TRXC I1A:5'   => 'Reset, RAM Fault',
        'TRXC I1A:6'   => 'Reset, Internal Function Change',
        'TRXC I1A:8'   => 'Timing Reception Fault',
        'TRXC I1A:9'   => 'Signal Processing Fault',
        'TRXC I1A:10'  => 'RX Communication Fault',
        'TRXC I1A:11'  => 'DSP CPU Communication Fault',
        'TRXC I1A:12'  => 'Terrestrial Traffic Channel Fault',
        'TRXC I1A:13'  => 'RF Loop Test Fault',
        'TRXC I1A:14'  => 'RU Database Corrupted',
        'TRXC I1A:15'  => 'X Bus Communication Fault',
        'TRXC I1A:16'  => 'Initiation Fault',
        'TRXC I1A:17'  => 'X Interface Fault',
        'TRXC I1A:18'  => 'DSP Fault',
        'TRXC I1A:19'  => 'Reset, DXU Link Lost',
        'TRXC I1A:20'  => 'HW and IDB Inconsistent',
        'TRXC I1A:21'  => 'Internal Configuration Failed',
        'TRXC I1A:22'  => 'Voltage Supply Fault',
        'TRXC I1A:23'  => 'Air Time Counter Lost',
        'TRXC I1A:24'  => 'High Temperature',
        'TRXC I1A:25'  => 'TX/RX Communication Fault',
        'TRXC I1A:26'  => 'Radio Control System Load',
        'TRXC I1A:27'  => 'Traffic Lost Downlink',
        'TRXC I1A:28'  => 'Traffic Lost Uplink',
        'TRXC I1A:29'  => 'Y Link Communication HW Fault',
        'TRXC I1A:30'  => 'DSP RAM Soft Error',
        'TRXC I1A:31'  => 'Memory Fault',
        'TRXC I1A:32'  => 'UC/HC Switch Card/Cable Missing or Corrupted',
        'TRXC I1A:33'  => 'Low Temperature',
        'TRXC I1A:34'  => 'Radio Unit HW Fault',
        'TRXC I1A:35'  => 'Radio Unit Fault',
        'TRXC I1A:36'  => 'Lost Communication to Radio Unit',
        'TRXC I1A:37'  => 'Radio Unit Communication Failure',
        'TRXC I1B:0'   => 'CDU/Combiner Not Usable',
        'TRXC I1B:1'   => 'Indoor Temp Out of Safe Range',
        'TRXC I1B:3'   => 'DC Voltage Out of Range',
        'TRXC I1B:7'   => 'TX Address Conflict',
        'TRXC I1B:8'   => 'Y Link Communication Fault',
        'TRXC I1B:9'   => 'Y Link Communication Lost',
        'TRXC I1B:10'  => 'Timing Reception Fault',
        'TRXC I1B:11'  => 'X Bus Communication Fault',
        'TRXC I1B:12'  => 'TRX Not Activated for Combined Cell',
        'TRXC I1B:13'  => 'Frequency Bandwidth Mismatch',
        'TRXC I2A:0'   => 'RX Cable Disconnected',
        'TRXC I2A:1'   => 'RX EEPROM Checksum Fault',
        'TRXC I2A:2'   => 'RX Config Table Checksum Fault',
        'TRXC I2A:3'   => 'RX Synthesizer Unlocked',
        'TRXC I2A:4'   => 'RX Internal Voltage Fault',
        'TRXC I2A:5'   => 'RX Communication Fault',
        'TRXC I2A:6'   => 'TX Communication Fault',
        'TRXC I2A:7'   => 'TX EEPROM Checksum Fault',
        'TRXC I2A:8'   => 'TX Config Table Checksum Fault',
        'TRXC I2A:9'   => 'TX Synthesizer Unlocked',
        'TRXC I2A:10'  => 'TX Internal Voltage Fault',
        'TRXC I2A:11'  => 'TX High Temperature',
        'TRXC I2A:12'  => 'TX Output Power Limits Exceeded',
        'TRXC I2A:13'  => 'TX Saturation',
        'TRXC I2A:14'  => 'Voltage Supply Fault',
        'TRXC I2A:15'  => 'VSWR/Output Power Supervision Lost',
        'TRXC I2A:16'  => 'Non-volatile Memory Corrupted',
        'TRXC I2A:17'  => 'Loadfile Missing for TRX node',
        'TRXC I2A:18'  => 'DSP Fault',
        'TRXC I2A:19'  => 'High Frequency of Software Fault',
        'TRXC I2A:20'  => 'RX Initiation Fault',
        'TRXC I2A:21'  => 'TX Initiation Fault',
        'TRXC I2A:22'  => 'CDU-Bus Communication Fault',
        'TRXC I2A:23'  => 'Default Values Used',
        'TRXC I2A:24'  => 'Radio Unit Antenna System Output Voltage Fault',
        'TRXC I2A:25'  => 'TX Max Power Restricted',
        'TRXC I2A:26'  => 'DB Parameter Fault',
        'TRXC I2A:29'  => 'Power Amplifier Fault',
        'TRXC I2A:32'  => 'RX High Temperature',
        'TRXC I2A:33'  => 'Inter TRX Communication Fault',
        'TRXC I2A:36'  => 'RX Filter Loadfile Checksum Fault',
        'TRXC I2A:37'  => 'RX Internal Amplifier Fault',
        'TRXC I2A:39'  => 'RF Loop Test Fault, Degraded RX',
        'TRXC I2A:40'  => 'Memory Fault',
        'TRXC I2A:41'  => 'IR Memory Not Started',
        'TRXC I2A:42'  => 'UC/HC Switch Card/Cable and IDB Inconsistent',
        'TRXC I2A:43'  => 'Internal HC Load Power Fault',
        'TRXC I2A:44'  => 'TX Low Temperature',
        'TRXC I2A:45'  => 'Radio Unit HW Fault',
        'TRXC I2A:46'  => 'Traffic Performance Uplink',
        'TRXC I2A:47'  => 'Internal Configuration Failed',
        'TRXC EC1B:4'  => 'L/R SWI (TRU in Local Mode)',
        'TRXC EC1B:5'  => 'L/R TI (Local to Remote While Link Lost)',
        'TRXC EC2B:6'  => 'O&M Link Disturbed',
        'TRXC EC2B:16' => 'TS0 TRA Lost (TS Mode Is IDLE)',
        'TRXC EC2B:17' => 'TS0 TRA Lost (TS Mode Is CS)',
        'TRXC EC2B:18' => 'TS0 PCU Lost (TS Mode Is PS)',
        'TRXC EC2B:20' => 'TS1 TRA Lost (TS Mode Is IDLE)',
        'TRXC EC2B:21' => 'TS1 TRA Lost (TS Mode Is CS)',
        'TRXC EC2B:22' => 'TS1 PCU Lost (TS Mode Is PS)',
        'TRXC EC2B:24' => 'TS2 TRA Lost (TS Mode Is IDLE)',
        'TRXC EC2B:25' => 'TS2 TRA Lost (TS Mode Is CS)',
        'TRXC EC2B:26' => 'TS2 PCU Lost (TS Mode Is PS)',
        'TRXC EC2B:28' => 'TS3 TRA Lost (TS Mode Is IDLE)',
        'TRXC EC2B:29' => 'TS3 TRA Lost (TS Mode Is CS)',
        'TRXC EC2B:30' => 'TS3 PCU Lost (TS Mode Is PS)',
        'TRXC EC2B:32' => 'TS4 TRA Lost (TS Mode Is IDLE)',
        'TRXC EC2B:33' => 'TS4 TRA Lost (TS Mode Is CS)',
        'TRXC EC2B:34' => 'TS4 PCU Lost (TS Mode Is PS)',
        'TRXC EC2B:36' => 'TS5 TRA Lost (TS Mode Is IDLE)',
        'TRXC EC2B:37' => 'TS5 TRA Lost (TS Mode Is CS)',
        'TRXC EC2B:38' => 'TS5 PCU Lost (TS Mode Is PS)',
        'TRXC EC2B:40' => 'TS6 TRA Lost (TS Mode Is IDLE)',
        'TRXC EC2B:41' => 'TS6 TRA Lost (TS Mode Is CS)',
        'TRXC EC2B:42' => 'TS6 PCU Lost (TS Mode Is PS)',
        'TRXC EC2B:44' => 'TS7 TRA Lost (TS Mode Is IDLE)',
        'TRXC EC2B:45' => 'TS7 TRA Lost (TS Mode Is CS)',
        'TRXC EC2B:46' => 'TS7 PCU Lost (TS Mode Is PS)',
        'CON EC1B:8'   => 'LAPD Q CG (LAPD Queue Congestion)',
        'CON EC2B:8'   => 'LAPD Q CG (LAPD Queue Congestion)',
        'RX I1B:0'     => 'RX Internal Amplifier Fault',
        'RX I1B:1'     => 'ALNA/TMA Fault',
        'RX I1B:3'     => 'RX EEPROM Checksum Fault',
        'RX I1B:4'     => 'RX Config Table Checksum Fault',
        'RX I1B:5'     => 'RX Synthesizer A/B Unlocked',
        'RX I1B:6'     => 'RX Synthesizer C Unlocked',
        'RX I1B:7'     => 'RX Communication Fault',
        'RX I1B:8'     => 'RX Internal Voltage Fault',
        'RX I1B:9'     => 'RX Cable Disconnected',
        'RX I1B:10'    => 'RX Initiation Fault',
        'RX I1B:11'    => 'CDU Output Voltage Fault',
        'RX I1B:12'    => 'TMA-CM Output Voltage Fault',
        'RX I1B:14'    => 'CDU Supervision/Communication Fault',
        'RX I1B:15'    => 'RX High Temperature',
        'RX I1B:17'    => 'TMA Supervision Fault',
        'RX I1B:18'    => 'TMA Power Distribution Fault',
        'RX I1B:19'    => 'RX Filter Loadfile Checksum Fault',
        'RX I1B:20'    => 'RX Cable Supervision Lost',
        'RX I1B:21'    => 'Traffic Lost Uplink',
        'RX I1B:22'    => 'Antenna System DC Power Supply Overloaded',
        'RX I1B:23'    => 'Radio Unit Antenna System Output Voltage Fault',
        'RX I1B:47'    => 'RX Auxiliary Equipment Fault',
        'RX I2A:0'     => 'CXU Supervision/Communication Fault',
        'RX I2A:1'     => 'RX Path Lost on A Receiver Side',
        'RX I2A:2'     => 'RX Path Lost on B Receiver Side',
        'RX I2A:3'     => 'RX Path Lost on C Receiver Side',
        'RX I2A:4'     => 'RX Path Lost on D Receiver Side',
        'RX I2A:5'     => 'RX Path A Imbalance',
        'RX I2A:6'     => 'RX Path B Imbalance',
        'RX I2A:7'     => 'RX Path C Imbalance',
        'RX I2A:8'     => 'RX Path D Imbalance',
        'TF I1A:0'     => 'Temperature Below Operational Limit',
        'TF I1A:1'     => 'Temperature Above Operational Limit',
        'TF I1B:0'     => 'Optional Synchronization Source',
        'TF I1B:1'     => 'DXU-Opt EEPROM Checksum Fault',
        'TF I1B:2'     => 'GPS Synch Fault',
        'TF I2A:0'     => 'Frame Start Offset Fault',
        'TF EC1B:0'    => 'EXT SYNCH (No Usable External Reference)',
        'TF EC1B:1'    => 'PCM SYNCH (No Usable PCM Reference)',
        'TF EC1B:6'    => 'EXT CFG (Multiple Timing Masters)',
        'TF EC1B:7'    => 'EXT MEAS (ESB Measurement Failure)',
        'TF EC2B:0'    => 'EXT SYNCH (No Usable External Reference)',
        'TF EC2B:1'    => 'PCM SYNCH (No Usable PCM Reference)',
        'TF EC2B:7'    => 'EXT MEAS (ESB Measurement Failure)',
        'TS EC1B:3'    => 'TRA/PCU (Remote Transcoder/PCU Com. Lost)',
        'TX I1A:0'     => 'TX Offending',
        'TX I1A:1'     => 'Internal HC Load Power Fault',
        'TX I1A:2'     => 'UC/HC Switch Inconsistent with IDB',
        'TX I1A:3'     => 'TX RF Power Back Off Failed',
        'TX I1B:0'     => 'CU/CDU Not Usable',
        'TX I1B:1'     => 'CDU/Combiner VSWR Limits Exceeded',
        'TX I1B:2'     => 'CU/CDU Output Power Limits Exceeded',
        'TX I1B:4'     => 'TX Antenna VSWR Limits Exceeded',
        'TX I1B:6'     => 'TX EEPROM Checksum Fault',
        'TX I1B:7'     => 'TX Config Table Checksum Fault',
        'TX I1B:8'     => 'TX Synthesizer A/B Unlocked',
        'TX I1B:9'     => 'TX Synthesizer C Unlocked',
        'TX I1B:10'    => 'TX Communication Fault',
        'TX I1B:11'    => 'TX Internal Voltage Fault',
        'TX I1B:12'    => 'TX High Temperature',
        'TX I1B:13'    => 'TX Output Power Limits Exceeded',
        'TX I1B:14'    => 'TX Saturation',
        'TX I1B:17'    => 'TX Initiation Fault',
        'TX I1B:18'    => 'CU/CDU HW Fault',
        'TX I1B:19'    => 'CU/CDU SW Load/Start Fault',
        'TX I1B:20'    => 'CU/CDU Input Power Fault',
        'TX I1B:21'    => 'CU/CDU Park Fault',
        'TX I1B:22'    => 'VSWR/Output Power Supervision Lost',
        'TX I1B:23'    => 'CU/CDU Reset, Power On',
        'TX I1B:24'    => 'CU Reset, Communication Fault',
        'TX I1B:25'    => 'CU/CDU Reset, Watchdog',
        'TX I1B:26'    => 'CU/CDU Fine Tuning Fault',
        'TX I1B:27'    => 'TX Max Power Restricted',
        'TX I1B:28'    => 'CDU High Temperature',
        'TX I1B:30'    => 'TX CDU Power Control Fault',
        'TX I1B:31'    => 'Power Amplifier Fault',
        'TX I1B:32'    => 'TX Low Temperature',
        'TX I1B:33'    => 'CDU-Bus Communication Fault',
        'TX I1B:34'    => 'Y link - XBus Collision Fault',
        'TX I1B:35'    => 'RX Path Imbalance',
        'TX I1B:36'    => 'Radio Unit HW Fault',
        'TX I1B:37'    => 'Feeder Connectivity Fault',
        'TX I1B:47'    => 'TX Auxiliary Equipment Fault',
        'TX I2A:0'     => 'TX Diversity Fault',
        'TX I2A:1'     => 'Fast Antenna Hopping Failure',
        'TX I2A:2'     => 'TX RF Power Back Off Exceeded',
        'MCTR I1A:0'   => 'Radio Unit Fault',
        'MCTR I1A:1'   => 'HW Fault',
        'MCTR I1A:2'   => 'Software Load of Radio Unit Failed',
        'MCTR I1A:3'   => 'HW and IDB Inconsistent',
        'MCTR I1A:4'   => 'Radio Unit in Full Maintenance Mode',
        'MCTR I1B:0'   => 'Radio Unit Connection Fault',
        'MCTR I1B:1'   => 'Temperature Exceptional',
        'MCTR I1B:2'   => 'Lost Communication to Radio Unit',
        'MCTR I1B:3'   => 'Traffic Lost',
        'MCTR I1B:4'   => 'MSMM Synch Fault',
        'MCTR I2A:0'   => 'HW Fault',
        'MCTR I2A:1'   => 'RX Cable Disconnected',
        'MCTR I2A:2'   => 'VSWR Over Threshold',
        'MCTR I2A:4'   => 'Temperature Abnormal',
        'MCTR I2A:5'   => 'RX Maxgain Violated',
        'MCTR I2A:6'   => 'Current to high',
        'MCTR I2A:7'   => 'High Frequency of Software Fault',
        'MCTR I2A:8'   => 'Traffic Lost',
        'MCTR I2A:9'   => 'ALNA/TMA Fault',
        'MCTR I2A:10'  => 'Auxiliary Equipment Fault',
        'MCTR I2A:11'  => 'CPRI Delay Too Long Active Path',
        'MCTR I2A:12'  => 'Communication Disturbance Between Radio',
        'MCTR I2A:13'  => 'Communication Failure Between Radio Units',
        'MCTR I2A:14'  => 'Communication Equipment Fault in Cascade',
        'MCTR I2A:15'  => 'Lost Communication to Radio Unit in Cascade',
        'MCTR I2A:16'  => 'RX Path Lost on A Receiver Side',
        'MCTR I2A:17'  => 'RX Path Lost on B Receiver Side',
        'MCTR I2A:18'  => 'RX Path Lost on C Receiver Side',
        'MCTR I2A:19'  => 'RX Path Lost on D Receiver Side',
        'MCTR I2A:20'  => 'RX Path A Imbalance',
        'MCTR I2A:21'  => 'RX Path B Imbalance',
        'MCTR I2A:22'  => 'RX Path C Imbalance',
        'MCTR I2A:23'  => 'RX Path D Imbalance',
        'MCTR I2A:24'  => 'CPRI Delay Too Long Redundant Path',
        'MCTR I2A:25'  => 'Frequency Bandwidth Mismatch',
        'MCTR I2A:26'  => 'Tx RF Power Back Off Failed',
        'MCTR I2A:27'  => 'Feeder Connectivity Fault',
        'MCTR I2A:28'  => 'Lost Communication to Radio Unit',
        'MCTR EC1B:10' => 'CC CONF (Inconsistent Combined Cell Configuration)'
    );

    # replunit database
    %replunit = (
        'CF 0'    => 'DXU, DUG 10, DUG 20, MU or IXU',
        'CF 1'    => 'ECU',
        'CF 2'    => 'Micro RBS',
        'CF 3'    => 'Y Link',
        'CF 4'    => 'TIM',
        'CF 5'    => 'CDU',
        'CF 6'    => 'CCU',
        'CF 7'    => 'PSU',
        'CF 8'    => 'BFU',
        'CF 9'    => 'BDM',
        'CF 10'   => 'ACCU',
        'CF 11'   => 'Active Cooler',
        'CF 12'   => 'ALNA/TMA A',
        'CF 13'   => 'ALNA/TMA B',
        'CF 14'   => 'Battery',
        'CF 15'   => 'Fan / Fan Group',
        'CF 16'   => 'Heater',
        'CF 17'   => 'Heat Exchanger Ext Fan',
        'CF 18'   => 'Heat Exchanger Int Fan',
        'CF 19'   => 'Humidity Sensor',
        'CF 20'   => 'TMA-CM',
        'CF 21'   => 'Temperature Sensor',
        'CF 22'   => 'CDU HLOUT HLIN Cable',
        'CF 23'   => 'CDU RX IN Cable',
        'CF 24'   => 'CU',
        'CF 25'   => 'DU',
        'CF 26'   => 'FU',
        'CF 27'   => 'FU CU PFWD Cable',
        'CF 28'   => 'FU CU PREFL Cable',
        'CF 29'   => 'CAB HLIN Cable',
        'CF 30'   => 'CDU bus',
        'CF 31'   => 'Environment',
        'CF 32'   => 'Local Bus',
        'CF 33'   => 'EPC Bus/Power Communication Loop',
        'CF 34'   => 'IDB',
        'CF 36'   => 'Timing Bus',
        'CF 37'   => 'CDU CXU RXA Cable',
        'CF 38'   => 'CDU CXU RXB Cable',
        'CF 39'   => 'X bus',
        'CF 40'   => 'Antenna',
        'CF 41'   => 'PSU DC Cable',
        'CF 42'   => 'CXU',
        'CF 43'   => 'Flash Card',
        'CF 45'   => 'Battery Temp Sensor',
        'CF 46'   => 'FCU',
        'CF 47'   => 'TMA-CM Cable',
        'CF 48'   => 'GPS Receiver',
        'CF 49'   => 'GPS Receiver DXU Cable',
        'CF 50'   => 'Active Cooler Fan',
        'CF 51'   => 'BFU Fuse or Circuit Breaker',
        'CF 52'   => 'CDU CDU PFWD Cable',
        'CF 53'   => 'CDU CDU PREFL Cable',
        'CF 54'   => 'IOM Bus',
        'CF 55'   => 'ASU RXA Units or Cables',
        'CF 56'   => 'ASU RXB Units or Cables',
        'CF 57'   => 'ASU CDU RXA Cable',
        'CF 58'   => 'ASU CDU RXB Cable',
        'CF 59'   => 'MCPA',
        'CF 60'   => 'BSU',
        'CF 61'   => 'PDU',
        'CF 62'   => 'SAU',
        'CF 63'   => 'SCU or SUP',
        'CF 64'   => 'RUS, RRUS, AIR or mRRUS',
        'CF 65'   => 'SXU',
        'TRXC 0'  => 'TRU, dTRU, DRU, RUG, RRU or DUG 20',
        'TRXC 2'  => 'Micro RBS',
        'TRXC 3'  => 'CXU TRU RXA Cable',
        'TRXC 4'  => 'CXU TRU RXB Cable',
        'TRXC 10' => 'CDU to TRU PFWD Cable',
        'TRXC 11' => 'CDU to TRU PREFL Cable',
        'TRXC 12' => 'CDU to TRU RXA Cable',
        'TRXC 13' => 'CDU to TRU RXB Cable',
        'TRXC 14' => 'CDU to Splitter Cable or Splitter to TRU RXA Cable',
        'TRXC 15' => 'CDU to Splitter Cable or Splitter to TRU RXB Cable',
        'TRXC 16' => 'CDU to TRU TX Cable',
        'TRXC 17' => 'CDU to Splitter Cable or Splitter to CXU RXA Cable',
        'TRXC 18' => 'CDU to Splitter Cable or Splitter to CXU RXB Cable',
        'TRXC 19' => 'Splitter to DRU Cable or DRU to Splitter RXA Cable',
        'TRXC 20' => 'Splitter to DRU Cable or DRU to Splitter RXB Cable',
        'TRXC 21' => 'DRU to DRU RXA Cable',
        'TRXC 22' => 'DRU to DRU RXB Cable',
        'TRXC 23' => 'HCU TRU TX Cable or HCU or CDU HCU TX Cable',
        'TRXC 24' => 'BSU',
        'TRXC 25' => 'RUS, RRUS, AIR or mRRUS',
        'TRXC 26' => 'RUG to RUG RXA Cable',
        'TRXC 27' => 'RUG to RUG RXB Cable',
        'TRXC 28' => 'RUS to RUS RXA Cable',
        'TRXC 29' => 'RUS to RUS RXB Cable'
    );

}
