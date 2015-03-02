#!/usr/bin/env perl
use strict;

my $primer = `grep 'my \$primer = ' scan.pl`;
$primer = $1 if $primer =~ m/'(.+?)'/;
my $pssm = `cat pssm.txt`;
chomp $pssm;
my $pwd = `pwd`;
my $region = $1 if $pwd =~ m/\/(v\d)-/;
my $target = $1 if $pwd =~ m/\/v\d-(.+)$/;

my $order = int(10000 + rand() * 100);

print <<"END";

>>>>
REGION	$region
ORDER	$order
TYPE	Bacteria
END

print "TARGET	$target\n" if $target;

print <<"END";
REGEX	$primer
PSSMCUT	15
PSSM=>
$pssm
<=PSSM
<<<<

END

