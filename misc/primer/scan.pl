#!/usr/bin/env perl
use strict;
use List::Util qw(min);


my $primer = '#######';
$primer =~ s/\[(\w)\]/$1/g;
my $primer2 = reverse $primer;
$primer2 =~ tr/ATGC][/TACG[]/;
my $regex1 = qr/($primer)/;
my $regex2 = qr/($primer2)/;

open(IN, 'pssm.txt') or die;
my %pssm;
my $pos = 1;
while(<IN>)
{
	chomp;
	my @a = split(/\t/, $_);
	$pssm{$pos}->{A} = $a[0];
	$pssm{$pos}->{T} = $a[1];
	$pssm{$pos}->{G} = $a[2];
	$pssm{$pos}->{C} = $a[3];
	$pos++;
}

my $len = scalar keys %pssm;

my %score;

while(<>)
{
	next if m/^>/;
	$_ = uc $_;
	chomp;
	my $match;
	if(m/$regex1/)
	{
		$match = $1;
	}elsif(m/$regex2/)
	{
		$match = reverse $1;
		$match =~ tr/ATGC/TACG/;
	}
	next unless $match;

	my $score;
	if($score{$match})
	{
		$score = $score{$match};
	}else
	{
		my @nt = split(//, $match);
		my $pos;
		for my $nt(@nt)
		{
			$pos++;
			$score += $pssm{$pos}->{$nt};
		}
		$score{$match} = $score;
	}
	print "$match\t$score\t$_\n";
}


