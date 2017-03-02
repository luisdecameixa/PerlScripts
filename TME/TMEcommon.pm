package TMEcommon;
use strict;
use warnings;
use diagnostics -verbose;

use String::Strip;    # 35% faster than the regex methods.
use LWP::Simple;
use Exporter qw(import);
our @EXPORT_OK = qw(ftrim getZONA RemoveMultipleElem TestConnection);

# left trim
sub ltrim { my $s = shift; $s =~ s/^\s+//; return $s }

# right trim
sub rtrim { my $s = shift; $s =~ s/\s+$//; return $s }

# trim space (left and right)
sub trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s }

# left trim
sub fltrim { my $s = shift; StripLSpace($s); return $s }

# right trim
sub frtrim { my $s = shift; StripTSpace($s); return $s }

# trim space (left and right)
sub ftrim { my $s = shift; StripLTSpace($s); return $s }

sub getZONA {
    my $sitecode = shift;
    my $cp = substr( $sitecode, 0, 2 );

    my $zona = 'M';
    for ($cp) {
        /39/ and do { $zona = 'B'; last; };
        /48/ and do { $zona = 'B'; last; };
        /01/ and do { $zona = 'B'; last; };
        /20/ and do { $zona = 'B'; last; };
        /26/ and do { $zona = 'B'; last; };
        /31/ and do { $zona = 'B'; last; };
        /50/ and do { $zona = 'B'; last; };
        /22/ and do { $zona = 'B'; last; };
        /44/ and do { $zona = 'B'; last; };
        /25/ and do { $zona = 'B'; last; };
        /43/ and do { $zona = 'B'; last; };
        /08/ and do { $zona = 'B'; last; };
        /17/ and do { $zona = 'B'; last; };
    }

    return $zona;
}

sub TestConnection {
    my $html = get('http://10.34.213.161/CNAI/KPI/TM/consultaEmplazamiento.php')
      or die 'Aviso: no se logra conectar con el Inventario de TME';
    return 1;
}

sub RemoveMultipleElem {
    my $refin = shift;
    my %h     = ();
    my @ret   = grep { !$h{$_}++ if ( defined $_ ) } @$refin;
    return \@ret;
}
1;
