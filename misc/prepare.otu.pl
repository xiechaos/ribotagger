#!/usr/bin/env perl
use strict;

for my $f(@ARGV)
{
	open(IN, $f) or die;
	$f =~ s/_/./g;
	$f =~ s|.+/||;
	my $source;
	my $i = 1;
	while(<IN>)
	{
		if(m/^SOURCE:\t(.+)/)
		{
			$source = $1;
			$source =~ s/^[>@]//;
		}elsif(m/^LONG:\t(\S+)/)
		{
			print ">${f}_$i $source orig_bc=ATGC new_bc=ATGC bc_diffs=0\n";
			print "$1\n";
			$i++;
		}
	}
}

__DATA__
pick_otus:enable_rev_strand_match True
pick_otus:stepwords 8
pick_otus:word_length 8
