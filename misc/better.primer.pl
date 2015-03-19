#!/usr/bin/env perl
# xiechaos@gmail.com
use strict;
use Getopt::Long;

my %par;

GetOptions(\%par,
	'in=s', 
	'out=s',
	'primer=s',
	'mis=i',
	'reads'
);

unless($par{mis} && $par{primer} && $par{in} && $par{out})
{
	print_usage();
	exit();
}

check_agrep();

my ($pattern, $pattern2) = make_pattern($par{primer});

my $match = `agrep --show-cost --color -$par{mis} -i "$pattern" $par{in}`;
my $match2 = `agrep --show-cost --color -$par{mis} -i "$pattern2" $par{in}`;

my %cost;
my %match;
my %reads;
#while($match =~ m/^(\d+?):.*?\e\[.*?m(.+?)\e/mg)
while($match =~ m/^((\d+?):.+?\e\[.*?m(.+?)\e\[.*?m..*?)$/mg)
{
	my $c = $2;
	my $m = $3;
	my $line = $1;
	$m = uc $m;
	next if $m =~ m/[^ATGC]/;
	$match{$m}++;
	$cost{$m} = $c;
	if($par{reads})
	{
		$reads{$m}->{$line}++;
	}
}
#while($match2 =~ m/^(\d+?):.*?\e\[.*?m(.+?)\e/mg)
while($match2 =~ m/^((\d+?):.+?\e\[.*?m(.+?)\e\[.*?m..*?)$/mg)
{
	my $c = $2;
	my $m = $3;
	my $line = $1;
	$m = uc $m;
	next if $m =~ m/[^ATGC]/;
	$m = reverse $m;
	$m =~ tr/ATGC/TACG/;
	$match{$m}++;
	$cost{$m} = $c;
	if($par{reads})
	{
		$reads{$m}->{$line}++;
	}
}

open(OUT, ">$par{out}") or die;

for my $m(sort {$match{$b} <=> $match{$a}} keys %match)
{
	print OUT "####\t$m\t$cost{$m}\t$match{$m}\n";
	if($par{reads})
	{
		for my $line(sort {$reads{$m}->{$b} <=> $reads{$m}->{$a}} keys %{$reads{$m}})
		{
			print OUT "----\t$reads{$m}->{$line}:\t$line\n";
		}
	}
}
close OUT;

sub print_usage
{
	my $usage =<<USAGE;
	
	usage: $0 [options]
	
	Required
		-mis INT     number of mismatches allowed on the input primer
		-primer STR  primer pattern sequence, accepts IUPAC notion
		-in STR      input fasta/fastq file
		-out STR     output file

	Optional:
		-read       print read sequences for each primer sequence

	(INT: integer, STR: string)

USAGE
	print $usage;
}

sub make_pattern
{
	my $p = shift;
	my $pattern = uc $p;
	$pattern =~ s/\s+//g;
	for($pattern)
	{
		s/R/[AG]/g;
		s/Y/[CT]/g;
		s/S/[GC]/g;
		s/W/[AT]/g;
		s/K/[GT]/g;
		s/M/[AC]/g;
		s/B/[CGT]/g;
		s/D/[AGT]/g;
		s/H/[ACT]/g;
		s/V/[ACG]/g;
		s/N/[ATGCN]/g;
	}
	my $pattern2 = reverse $pattern;
	$pattern2 =~ tr/ATGC[]/TACG][/;

	return($pattern, $pattern2);
}

sub check_agrep
{
	my $agrep = `agrep -V`;
	unless($agrep =~ m/TRE agrep/)
	{
		die "TRE-agrep is required, please install a free copy from http://laurikari.net/tre/download/\n";
	}
}
