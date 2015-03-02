#!/usr/bin/env perl
use strict;

my %rank;
my %data;
open(IN, "data/silva.119/raw/taxonomy/tax_slv_ssu_nr_119.txt") or die;
while(<IN>)
{
	my @a = split(/\t/, $_);
	$rank{$a[0]} = $a[2];
	my $name = $1 if $a[0] =~ m/.+;([^;]+?);$/;
	$data{$name}->{$a[0]}++;
}

for my $name(keys %data)
{
	next unless scalar(keys %{$data{$name}}) > 1;
	next if $name =~ m/unknown|uncultured|Incertae Sedis/i;
	print "NAME:\t$name\n";
	for my $path(keys %{$data{$name}})
	{
		print "\t$rank{$path}\t$path\n";
	}
	print "////\n\n\n";
}
