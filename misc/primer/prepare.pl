#!/usr/bin/env perl
use strict;

my $cmd = shift;
my $master_align = $cmd if -f $cmd;

open(IN, 'config') or die;
my $config = join('', <IN>);
my ($cut_start, $cut_length) = ($1, $2) if $config =~ m/^cut\t(\d+)\t(\d+)/m;

if($master_align)
{
	if(-f 'align')
	{
		die "please remove the current align file first\n";
	}
	system(qq{perl -ne 'next if m/^>/; print substr(\$_, $cut_start, $cut_length), "\\n"' $master_align | head});
	system(qq{perl -ne 'next if m/^>/; print substr(\$_, $cut_start, $cut_length), "\\n"' $master_align > align});
	$cmd = 1;
}elsif(-f 'align')
{
	print "\n\n\nWARNING: reusing previous 'align' file\n\n\n";
}else
{
	die "usage: prepare.pl master_align.fa\n";
}

if($cmd eq '1' || $cmd eq '2')
{

	if($cmd eq '1')
	{
		die unless -f 'align';
		print "calculating nt freq\n";
		system("~/rna/script/primer/align.to.freq2.pl align > freq");
		print "converting msa to seq\n";
		system(q(perl -ne 's/-+//g; $_ = uc $_; print if m/^[ATGC]+/' align > seq));
	}

	die unless -f 'freq';
	print "calculating misc R stuff\n";
	system("~/rna/script/primer/run.r");

	print "\n\nlength distribution of seqs\n";
	system("perl -lne 'print length' seq | sort | uniq -c | sort -n | tail");
	print "\n\nlength of pattern\n";
	system("wc -l pssm.txt");
}

