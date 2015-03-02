#!/usr/bin/env perl
use strict;

open(IN, 'config') or die;
my $config = join('', <IN>);
my $pssmcut = $1 if $config =~ m/^pssmcut\t(\d+)/m;
my $primercut = $1 if $config =~ m/^primer\t(\S+)/m;
my $rc = $1 if $config =~ m/^rc\t(\d+)/m;


print "\nusing primer [nt freq] cut at $primercut\n";
print "\nusing pssm cut at $pssmcut\n\n";

my $primer = `~/rna/script/primer/primer.r $primercut`; 
$primer =~ s/.+?"(.+?)"\n/$1/;

print "using primer $primer\n";
system(qq|perl -pe 's/#######/$primer/'  ~/rna/script/primer/scan.pl > scan.pl|);
system("chmod a+x scan.pl");

my $min = $pssmcut;
$min = 10 if $pssmcut > 10;
print "\nscreening the refseq.sub with pssmcut $min\n";
system(qq(./scan.pl ~/rna/data/refseq/refseq.sub | perl -lane 'print if \$F[1] >= $min'));

my $nseq = `wc -l seq`;
$nseq =~ s/(\d+).+?$/$1/;
print "\n\n'seq' file has $nseq sequences\n\n";

print q(./scan.pl seq | perl -lane 'print if $F[1] >= 10' | wc -l), "\n";
my $t10 = `./scan.pl seq | perl -lane 'print if \$F[1] >= 10' | wc -l`;
print $t10;
print 100 * $t10 / $nseq, "\n";

print q(./scan.pl seq | perl -lane 'print if $F[1] >= 15' | wc -l), "\n";
my $t10 = `./scan.pl seq | perl -lane 'print if \$F[1] >= 15' | wc -l`;
print $t10;
print 100 * $t10 / $nseq, "\n";

print q(./scan.pl seq | perl -lane 'print if $F[1] >= 20' | wc -l), "\n";
my $t20 = `./scan.pl seq | perl -lane 'print if \$F[1] >= 20' | wc -l`;
print $t20;
print 100 * $t20 / $nseq, "\n";

unless($pssmcut == 10 | $pssmcut == 20 | $pssmcut == 15)
{
	print "testing with pssmcut $pssmcut\n";
	my $t20 = `./scan.pl seq | perl -lane 'print if \$F[1] >= $pssmcut' | wc -l`;
	print $t20;
	print 100 * $t20 / $nseq, "\n";
}

system("~/rna/script/primer/DATA.pl > data");

my $region;
my $pwd = `pwd`;
my $region = $1 if $pwd =~ m|/(v\d)|;


if($rc || $region eq 'v6')
{
	print "\n\nwarning: either you used 'rc' in 'config',  or because region is $region,\n \tusing Reverse Complement strand\n";
	system('~/rna/script/primer/logo.rc.r');
	my $data = `cat data`;
	my $primer = $1 if $data =~ m/^REGEX\t(\S+)/m;
	$primer = reverse $primer;
	$primer =~ tr/ATGC][/TACG[]/;
	$data =~ s/^REGEX\t.+/REGEX\t$primer/m;
	$data =~ s/^(\S+)\t(\S+)\t(\S+)\t(\S+)$/$2\t$1\t$4\t$3/mg;
	open(OUT, ">data") or die;
	print OUT $data;
	close OUT;
}else
{
	print "\n\nwarning: 'rc' not specified in 'config', region is $region,\n \tso NOT using Reverse Complement strand\n";
}

