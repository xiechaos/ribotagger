#!/usr/bin/env perl
use strict;

my %map = (domain=>'k', phylum=>'p', 'class'=>'c', 'order'=>'o', 'family'=>'f', 'genus'=>'g', 'species'=>'s');
my %tag;
while(<>)
{
	my @a = split(/\t/, $_);
#	TTTTTTAAGTCTGATGTGAAAGCCCACGGCTCA       18880   18880   18880   phylum  1       Firmicutes      Bacteria;domain;Firmicutes;phylum       120083
	my $tag = $a[0];
	my $support = $a[2];
	my $confi = $a[3];
	my $level = $a[4];
	my $good = $a[5];
	my $name = $a[6];
	$tag{$tag} .= "\t$map{$level}__$name++$support--$confi" if $good;
}

for my $tag(keys %tag)
{
	print "$tag$tag{$tag}\n";
}

