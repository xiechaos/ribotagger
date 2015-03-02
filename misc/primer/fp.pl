#!/usr/bin/env perl
use strict;

my $rand = rand().time();

open(QU, ">$rand.fa") or die;

my %seq;
while(<>)
{
	chomp;
	my $seq = $_;
	$seq{$seq} = 1;
	print QU ">$seq\n$seq\n";
}
close QU;

my %true;

my $blast = `blastall -p blastn -m 8 -i $rand.fa -e 1e-5 -v 10 -b 10 -d ~/rna/data/blast/subset.fa`;
my @blast = split(/\n/, $blast);
foreach(@blast)
{
	if(m/^(\S+?)\t\S+?\t\S+?\t(\d+?)\t/ && $2 >= 40)
	{
		$true{$1} = 1;
	}
}

open(QU, ">$rand.fa") or die;
for my $seq(keys %seq)
{
	print QU ">$seq\n$seq" unless $true{$seq};
}
close QU;
my $blast = `blastall -p blastn -m 8 -i $rand.fa -e 1e-5 -v 10 -b 10 -d ~/rna/data/blast/release10_30_unaligned.fa`;
my @blast = split(/\n/, $blast);
foreach(@blast)
{
	if(m/^(\S+?)\t\S+?\t\S+?\t(\d+?)\t/ && $2 >= 50)
	{
		$true{$1} = 1;
	}
}

unlink "$rand.fa";

for my $seq(keys %seq)
{
	if($true{$seq})
	{
		print "1\t$seq\n";
	}else
	{
		print "0\t$seq\n";
	}
}

