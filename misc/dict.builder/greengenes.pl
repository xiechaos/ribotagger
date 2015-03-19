#!/usr/bin/env perl
use strict;
use List::Util qw(min sum);

my %tag;
my %count;

my %anno;
open(IN, 'zcat data/gg_13_5/gg_13_5_taxonomy.txt.gz |') or die $!;
while(<IN>)
{
	$anno{$1} = $2 if m/^(\d+)\t(.+)/;
}


my %map = (k__=>'domain', p__=>'phylum', c__=>'class', o__=>'order', f__=>'family', g__=>'genus', s__=>'species');

while(my $h = <>)
{
	my $tag = <>;
	chomp $tag;
	$tag =~ s/.+:\t//;
	$h =~ s/.+:\t//;
	$h =~ s/>//;
	$count{$tag}++;
	$h =~ s/(\d+)/$anno{$1}/;
	for my $rank(qw(k__ p__ c__ o__ f__ g__ s__))
	{
		if($h =~ m/(.*$rank(.*?))(;|$)/)
		{
			my $name = $1;
			my $this = $2;
			next unless $this;
			next if $this eq 'unclassified';


			my $r = $map{$rank};
			$name =~ s/(\w__)(.*?)(;|$)/$2;$map{$1}$3/g;
			$name =~ s/unclassified;\w+;//g;
			$name =~ s/; /;/g;
			$tag{$tag}->{$r}->{$name}++;
		}
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
	for my $rank(qw(domain phylum class order family genus species))
	{
		next unless $tag{$tag}->{$rank};
		my %label = %{$tag{$tag}->{$rank}};
		my $good = sum values %label;
		my @best = sort{$label{$b} <=> $label{$a}} keys %label;
		my $best = $best[0];
		my $top = $label{$best};

		my $fine = 0;
		$fine = 1 if $best =~ m/(^|;)$last;/;

		my $this = $2 if $best =~ m/(^|;)([^;]+?);$rank$/;
		$last = $this if $fine;

		$all{$rank}->{$best} += $top;
		$out{$tag}->{$rank} = "$tag\t$total\t$good\t$top\t$rank\t$fine\t$this\t$best";
		$best{$tag}->{$rank} = $best;
	}
}

for my $tag(@order)
{
	for my $rank(qw(domain phylum class order family genus species))
	{
		my $best = $best{$tag}->{$rank};
		next unless $best;
		print "$out{$tag}->{$rank}\t$all{$rank}->{$best}\n";
	}
}

