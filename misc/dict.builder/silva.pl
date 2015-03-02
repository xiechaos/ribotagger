#!/usr/bin/env perl
use strict;
use List::Util qw(min sum);

my $type = shift;

my %rank;
open(IN, "data/silva.119/raw/taxonomy/tax_slv_ssu_nr_119.txt") or die;
while(<IN>)
{
	my @a = split(/\t/, $_);
	$rank{$a[0]} = $a[2];
}
$rank{"Bacteria;Actinobacteria;"} = 'phylum';


my %tag;
my %count;

while(my $h = <>)
{
	my $tag = <>;
	my $long = <>;
	chomp $tag;
	$tag =~ s/.+:\t//;
	chomp $long;
	$long =~ s/.+:\t//;

	$tag = $long if $type =~ m/long/;

	$count{$tag}++;

#	SOURCE: >HQ605699.1.2370 Eukaryota;Archaeplastida;Rhodophyceae;Bangiales;Porphyra;Pyropia sp. Antar68
	$h =~ s/.+:\t>\S+ /1;/;
	while($h =~ s/^((.+);([^;]+))$/\2/)
	{
#		my $tax = $1;
		my $name = "$1;";
		$name =~ s/^1;//;
		next unless $rank{$name};
		next if $name =~ m/uncultured|Unknown/i;
		my $rank = $rank{$name};
		$tag{$tag}->{$rank}->{$name}++;
	}
}

my %all;
my %out;
my %best;
my @order;
for my $tag(sort {$count{$b} <=> $count{$a}} keys %count)
{
	push @order, $tag;
	my $total = $count{$tag};
	my $last = '.*';
	for my $rank(qw(domain phylum class order family genus))
	{
		next unless $tag{$tag}->{$rank};
		my %label = %{$tag{$tag}->{$rank}};
		my $good = sum values %label;
		my @best = sort{$label{$b} <=> $label{$a}} keys %label;
		my $best = $best[0];
		my $top = $label{$best};

		my $fine = 0;
		$fine = 1 if $best =~ m/(^|;)$last;/;

		my $this = $2 if $best =~ m/(^|;)([^;]+?);$/;
#		print STDERR "$this\t$last\t$best\n";
		$last = $this if $fine;

		$all{$rank}->{$best} += $top;
		$out{$tag}->{$rank} = "$tag\t$total\t$good\t$top\t$rank\t$fine\t$this\t$best";
		$best{$tag}->{$rank} = $best;
	}
}

for my $tag(@order)
{
	for my $rank(qw(domain phylum class order family genus))
	{
		my $best = $best{$tag}->{$rank};
		next unless $best;
		print "$out{$tag}->{$rank}\t$all{$rank}->{$best}\n";
	}
}

