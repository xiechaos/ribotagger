#!/usr/bin/env perl
use strict;
use autodie qw(:all);
use Getopt::Long;
use Cwd;
my $path = Cwd::abs_path($0);
$path =~ s|(.+/).*?$|$1|;

my @infile;
my $outdir;
my $region;
my $prefix = 'ribotag';
my $rename = 's/\.v\d\b//ig';

unless(@ARGV)
{
	print <<"USAGE";

Usage: batch.pl -in infiles -out outdir -region REGION [options]
     
     -in      the output files from ribotagger.pl
              accepts multiple files, one for each sample
     -out     output directory
     -region  variable regions [v4|v5|v6|v7]
     -prefix  prefix for output files
              default = $prefix
     -name    perl regex to rename your sample names
              default = '$rename'
USAGE

	exit;
}


GetOptions(
	'in=s{,}' => \@infile,
	'out=s' => \$outdir,
	'prefix=s' => \$prefix,
	'name=s' => \$rename,
	'region=s' => \$region
) or die;

$prefix .= '.' unless !$prefix or $prefix=~m/\.$/;
my $in = join(' ', @infile);

mkdir $outdir or die $!;

my $biom = "'$outdir/${prefix}$region'";
my $cmd = "$path/biom.pl -r $region -o $biom -in $in";
print $cmd, "\n"; system $cmd;

if($rename)
{
	my $cmd = qq(perl -pi -e '$rename' $biom.tab);
	print $cmd, "\n"; system $cmd;
}

my $pcoa = "'$outdir/${prefix}$region.pcoa'";
system("mkdir $pcoa");
my $cmd = "$path/pcoa.r $biom.tab $pcoa 1 10";
print $cmd, "\n"; system $cmd;
