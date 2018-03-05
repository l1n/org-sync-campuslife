#!/usr/bin/perl

use JSON;
use HTML::Entities;

@ARGV = (split /\t/, shift);

my %out = (
    name => $ARGV[1],
    src => $ARGV[0]
);
my @body = split /\n/, `curl -sL $ARGV[0]`;
my @repro;
my $print;
foreach (@body) {
    if (/<article /) {
        $print = 1;
    }
    if (/Contact A/) {
        $print = 0;
    } if ($print && !(/<article /)) {if (/h4>(.*)</) {
            push @repro, [$1];
        } else {
            /p>(.*)<.p>/;
            if (defined $repro[0]) {
                $repro[-1][1] = $1;
            } else {
                push @repro, ["Description", $1];
            }
        }
    }
}
$out{update_sql} = "UPDATE organizations_canonical SET ";
foreach my $parts (@repro) {
    my @parts = @$parts;
    $parts[0] =~ s/Group //;
    $parts[0] =~ s/MyUMBC Group/organization_group/i;
    $parts[0] = lc $parts[0];
    $parts[1] =~ s/.*>(.*)<.a>/$1/;
    if ($parts[0]) {
        $out{$parts[0]} = $parts[1];
        $out{update_sql} .= $parts[0] . " = \"" . encode_entities( $parts[1] ) . "\", ";
    }
}
chop $out{update_sql};
chop $out{update_sql};
$out{update_sql} .= " WHERE name = \"" . encode_entities( $out{name} ) . "\";";
print to_json(\%out), "\n";
