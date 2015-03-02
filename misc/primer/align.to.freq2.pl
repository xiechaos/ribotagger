#!/usr/bin/env perl
use strict;

my @data;
while(my $seq = <>)
{
	chomp $seq;
	$seq = uc $seq;
	push @data, $seq;
}
for my $pos(0..(length($data[0])-1))
{
	my @a = map {substr($_, $pos, 1)} @data;
	my %temp;
	$temp{$_}++ foreach @a;
	for my $nt(keys %temp)
	{
		print "$pos\t$nt\t$temp{$nt}\n";
	}
}


