#!/usr/bin/env perl
use strict;
use LWP::Simple;
die "usage: $0 gi.of.genome [more gi for more genomes]\n" unless @ARGV;

for my $gi(@ARGV)
{
#	print "http://www.ncbi.nlm.nih.gov/sviewer/viewer.cgi?tool=portal&sendto=on&log\$=seqview&db=nuccore&dopt=gb&sort=&val=$gi\n";
	my $gb = get "http://www.ncbi.nlm.nih.gov/sviewer/viewer.cgi?tool=portal&sendto=on&log\$=seqview&db=nuccore&dopt=gb&sort=&val=$gi";
	while($gb =~ m/^     rRNA            (\S+)\n((^                     .+\n)+)/mg)
	{
		my $loc = $1;
		my $label = $2;
		$label =~ s/\s+/ /g;
		if($loc =~ m/^(complement\()?(\d+?)..(\d+?)\)?$/m)
		{
			my $strand = '&strand=on' if $1;
			my $seq = get "http://www.ncbi.nlm.nih.gov/sviewer/viewer.cgi?tool=portal&sendto=on&log\$=seqview&db=nuccore&dopt=fasta&sort=&val=$gi&from=$2&to=$3$strand\n";
			$seq =~ s/ / $label (from /;
			$seq =~ s/\n/)\n/;
			print $seq;
		}
	}
}
