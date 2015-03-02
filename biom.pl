#!/usr/bin/env perl
use strict;
use Getopt::Long;
use List::Util qw(min sum);
#use PerlIO::gzip;
use Cwd 'abs_path';
my $path = abs_path($0);
$path =~ s|(.+/).*?$|$1|;
my $cmd = join(' ', @ARGV);
$cmd =~ s/\n/ /g;
$cmd =~ s/"/'/g;
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $date = sprintf("%4d-%02d-%02dT%02d:%02d:%02d",($year + 1900),($mon+1),$mday,$hour,$min,$sec);

my @infile;
my $outfile;

my $region;
my $taxonomy = 'silva';
my $fp = 'minus';
my $support = 2;
my $confidence = 0.8;
my $trylong = 0.8;
my $trylong_conf = 0.7;
my $diffpos = 2;
my $absolutepath;
my $like;

GetOptions(
	'region=s' => \$region,
	'taxonomy=s' => \$taxonomy,
	'fp=s' => \$fp,
	'min-pos=i' => \$diffpos,
	'support=i' => \$support,
	'confidence=f' => \$confidence,
	'like' => \$like,
	'use-long=f' => \$trylong,
	'long=f' => \$trylong_conf,
	'absolutepath' => \$absolutepath,
	'in=s{,}' => \@infile,
	'out=s' => \$outfile
) or die "\n";

unless($outfile && @infile)
{
	print <<"USAGE";

usage: $0 [options] -region v4|v5|v6|v7 -out OUTFILE -in INFILE1 [INFILE2 ...]

  Required:

	-in INFILE1 INFILE2 ...    one or more files generated from ribotagger.pl 
	-out OUTFILE               output biom file
	-region [v4|v5|v6|v7]      variable region

  Optional:

	-min-pos INT               minimum number of different start positions 
	                           for a tag to be reported
	                           default = $diffpos
	-fp minus|nothing          report abundance as observed count minus estimated false positive,
	                           or do nothing,
	                           default = $fp
	
  For taxa annotation (only works with default -tag, -long, and -before-tag):

	-taxonomy TYPE             which taxonomy to use for tag annotation, available:
	                           greengenes, silva
	                           default = $taxonomy
	-long FLOAT                a long sequence is called a short tag's representive if
	                           >= FLOAT proportion of the tags have this long sequence
	                           default = $trylong_conf
	-use-long FLOAT            try to use long sequence for annotation for a tag if 
	                           number of samples sharing the same long sequence representative
	                           for the tag / total number of samples >= FLOAT
	                           default = $trylong
	-like                      if no exact tag annotation found in the dictionary,
	                           find alike taxa annotation from tags with one base difference

USAGE

	exit;
}

my $nolike = not $like;

die "you must specify the variable region with --region option\n" unless $region;
$region = lc $region;
die "--region accepts v4, v5, v6, or v7 only\n" unless $region =~ m/v4|v5|v6|v7/;
die "--fp accepts minus or nothing only\n" unless $fp =~ m/minus|nothing/i;
die "--confidence must in the range of [0, 1]\n" unless $confidence >= 0 && $confidence <= 1;
die "--trylong must in the range of [0, 1]\n" unless $trylong >= 0 && $trylong <= 1.1;
die "--trylong_conf must in the range of [0, 1]\n" unless $trylong_conf >= 0 && $trylong_conf <= 1.1;
die "--taxonomy must be one of greengenes or silva\n" unless $taxonomy =~ m/greengenes|silva/i;
for(@infile){
	die "cannot find file $_\n" unless -f $_;
}
my $pa = $path."dict/$taxonomy.tag.$region";
open(my $DTAG, "<", $pa ) or die "cannot open annotation file: $!";
$pa = $path."dict/$taxonomy.long.$region";
open(my $DLONG, "<", $pa) or die "cannot open annotation file: $!";
my %res = (silva=>'g', greengenes=>'s');
my $resolution = $res{$taxonomy};


$outfile =~ s/\.(biom|biome|anno|tab|table)$//i;
open(OUT, ">$outfile.biom") or die "cannot create --out $outfile.biom\n";
open(ANNO, ">$outfile.anno") or die "cannot create --out $outfile.anno\n";
open(TAB, ">$outfile.tab") or die "ctabt create --out $outfile.tab\n";
print TAB "tag";
print ANNO "tag\tuse\ttaxon_level\ttaxon_data\tlong\tlong_total\tlong_this\tsupport\tconfidence";
for my $k(qw(k p c o f g s))
{
	print ANNO "\t$k";
}
print ANNO "\n";

my $fi = 0;
my %tag;
my %long;
my %long2;
my %tagcount;
for my $inf(@infile)
{
	open(IN, $inf) or die;

	my %tagcountthis;
	my $total;

	while(<IN>)
	{
		chomp;
		next if m/^#/;
		my ($tag, $n, $npos, $nfp, $divtotal, $div0, $div1, $div2, $divtag0, $divtag1, $divtag2) = split(/\t/, $_);
		next if $npos < $diffpos;
		$n -= $nfp if $fp =~ m/minus/i;
		$n = int($n + 0.5);
		next if $n <= 0;
		$tag{$tag}->{$fi} = $n;
		$tagcountthis{$tag} += $n;
		$total += $n;
		if($divtotal > 0 && $div0 / $divtotal >= $trylong_conf)
		{
			$long{$tag}->{$divtag0}++;
			$long2{$divtag0} = 1;
		}
	}

	$tagcount{$_} += $tagcountthis{$_} / $total for keys %tagcountthis;

	$fi++;
}
my $tagi = scalar keys %tag;
my $shape = "[$tagi, $fi]";
my $columns;
for(@infile)
{
	s|.+/|| unless $absolutepath;
	s/[^a-zA-Z0-9]/./g;
	$columns .= qq(\n\t\t{"id":"$_", "metadata":null},);
	print TAB "\t$_";
}
$columns =~ s/,$//;
print TAB "\n";

my ($dict_tag, $dict_tag_good, $dict_tag_data, $dict_tag_raw) = read_dict($DTAG, 'tag');
my ($dict_long, $dict_long_good, $dict_long_data, $dict_long_raw) = read_dict($DLONG, 'long');

my @order = sort {$tagcount{$b} <=> $tagcount{$a}} keys %tagcount;
my %map;
my $i=1;
$map{$i++} = $_ for @order;

my $rows;
my $data;
for my $i(1..$tagi)
{
#	my $id = "tag_$i";
	my $id = $map{$i};
	my $tag = $map{$i};
	my %data = %{$tag{$tag}};

	my $tax;
	my $level;
	my $longinfo;
	if($long{$tag})
	{
		my %longs = %{$long{$tag}};
		my @count = sort{$b <=> $a} values %longs;

		my $tagnfile = sum(scalar keys %data);
		if($count[0]/$tagnfile >= $trylong)
		{
			my $total = sum(@count);
			my @longs = sort{$longs{$b} <=> $longs{$a}} keys %longs;
			my $long = $longs[0];
			$tax = $dict_long->{$long};
			$level = $dict_long_good->{$long};
			unless($nolike)
			{
				my $like = taxa_like($long, $dict_long_raw, $dict_long_good, $level, $dict_long_data->{$long}, $tax);
				$tax =~ s/,""]/,$like,""]/ if $like;
			}
			$longinfo = qq(,\n\t\t\t"long":"$long",\n\t\t\t"long_total":"$total",\n\t\t\t"long_this":"$count[0]");
		}
	}
	unless($level)
	{
		$tax = "$dict_tag->{$tag}$tax";
		$level = $dict_tag_good->{$tag};
		unless($nolike)
		{
			my $like = taxa_like($tag, $dict_tag_raw, $dict_tag_good, $level, $dict_tag_data->{$tag}, $tax);
			$tax =~ s/,""]/,$like,""]/ if $like;
		}
	}
	$tax = qq(\t"taxonomy":[""]) unless $level;
	$tax .= $longinfo;
	$tax =~ s/^,//;

	$rows .= qq(\n\t\t{"id":"$id", 
		"metadata": {
			"tag":"$tag",
		$tax}
		},\n);

	for my $file(keys %data)
	{
		my $ii = $i - 1;
		$data .= "\t\t[$ii,$file,$data{$file}],\n";
	}

	# write the ANNO file
	{

		my $use = $1 if $tax =~ m/"use":"(.+?)"/;
		my $taxon_level = $1 if $tax =~ m/"taxon-level":"(.+?)"/;
		my $taxon_data = $1 if $tax =~ m/"taxon-data":"(.+?)"/;
		my $long = $1 if $tax =~ m/"long":"(.+?)"/;
		my $long_total = $1 if $tax =~ m/"long_total":"(.+?)"/;
		my $long_this = $1 if $tax =~ m/"long_this":"(.+?)"/;
		my $support = $1 if $tax =~ m/"support":"(.+?)"/;
		my $confidence = $1 if $tax =~ m/"confidence":"(.+?)"/;

		my %taxa;
		my $taxa = $1 if $tax =~ m/"taxonomy":\[(.+)\]/;
		while($taxa =~ m/"(\w)__([^"]+?)"/g)
		{
			$taxa{$1} = $2;
		}

		print ANNO "$tag\t$use\t$taxon_level\t$taxon_data\t$long\t$long_total\t$long_this\t$support\t$confidence";
		for my $k(qw(k p c o f g s))
		{
			print ANNO "\t$taxa{$k}";
		}
		print ANNO "\n";
	}

	# write the TAB file
	print TAB $tag;
	for my $i(0..($fi-1))
	{
		print TAB "\t", 0 + $tag{$tag}->{$i};
	}
	print TAB "\n";

}
$data =~ s/,$//;
$rows =~ s/,\s+}/}/g;
$rows =~ s/,$//;

print OUT<<"END";
{
	"id":null,
	"format": "Biological Observation Matrix 0.9.1-dev",
	"format_url": "http://biom-format.org/documentation/format_versions/biom-1.0.html",
	"type": "OTU table",
	"date": "$date",
	"comment": "$cmd",
	"rows": [
$rows
		],
	"columns":[
$columns
		],
	"matrix_type": "sparse",
	"matrix_element_type": "int",
	"shape": $shape,
	"data": [
$data
		]
}
END


sub read_dict
{
	my $dict_file = shift;
	my $use = shift;
	my %dict;
	my %dict_good;
	my %dict_data;
	my %dict_raw;
	while(<$dict_file>)
	{
		my $tag = $1 if m/^(\w+?)\t/;
#		next unless $tag{$tag} || $long2{$tag};
		my $tax;
		my $conf;
		my $supp;
		my $i=0;
		my $j=0;
		while(m/\t((\w)__[^\t]+?)\+\+(\d+?)--(\d+)/g)
		{
			next if $3 < $support;
			$i = $2;
			my $conf_this = $4 / $3;
			next if $conf_this < $confidence;
			$j = $2;
			$supp = $3;
			$conf = $conf_this;
			my $name = $1;
			$name =~ s/"/'/g;
			$dict_raw{$tag}->{$j} = "$4:::$name";
			$tax .= qq("$name",);
		}
		$tax =~ s/,$//;
		if($tax)
		{
			$dict{$tag} = qq(\t"taxonomy":[$tax,""], \n\t\t\t"confidence":"$conf", \n\t\t\t"support":"$supp",\n\t\t\t"use":"$use",\n\t\t\t"taxon-level":"$j",\n\t\t\t"taxon-data":"$i");
		}
		$dict_good{$tag} = $j;
		$dict_data{$tag} = $i;
	}
	return (\%dict, \%dict_good, \%dict_data, \%dict_raw);
}

sub taxa_like
{
	my($tag, $dict, $dict_good, $level, $level_data, $real) = @_;
	return if $nolike;
	return if $level eq $resolution;

	my $levels = 'kpcofgs';

	my $len = length $tag;
	my %like1;
	$like1{$tag} = 10 if $dict->{$tag};
	
	for my $pos (0..$len)
	{
		my $original = substr($tag, $pos, 1);
		for my $nt (qw(A T G C))
		{
			next if $original eq $nt;
			my $temp = $tag;
			substr($temp, $pos, 1) = $nt;
#			next unless $dict_good{$temp} =~ m/[gs]/;
			next unless $dict_good->{$temp};
			$like1{$temp} = 1;
		}
	}

	my $like1 = sum_like(\%like1, $dict);
	$like1 = compare_like($like1, $real);

	my $l1 = $like1;
	$l1 =~ s/(\w__.*?),/"$1 (like)",/g;
	$l1 =~ s/,$//;

	return $l1;
}

sub compare_like
{
	my ($like, $real) = @_;
	$real =~ s/"//g;
	$like =~ s/"//g;
	my $level = $1 if $real =~ m/.*(\w)__/;
	my $tocompare = $1 if 'kpcofgs' =~ m/(.*$level)/;
	my $from = $1 if $real =~ m/(\w)__/;
	$tocompare = $1 if $tocompare =~ m/($from.+)/;
	return $like unless $tocompare;
	my $like_level = $1 if $like =~ m/.*(\w)__/;
	my $tosave = $1 if 'kpcofgs' =~ m/$level(.*$like_level)/;
	return unless $tosave;
	$tosave =~ s/(.).+/$1/;

	while($tocompare =~ m/(\w)/g)
	{
		my $level = $1;
		my $r = $1 if $real =~ m/${level}__(.+?)(,|$)/;
		my $l = $1 if $like =~ m/${level}__(.+?)(,|$)/;
		return unless $r eq $l;
	}
	my $good = $1 if $like =~ m/(${tosave}__.+)/;;
	return $good;
}

sub sum_like
{
	my ($likes, $dict) = @_;
	my %likes = %$likes;

	my %taxa;
	for my $like(keys %likes)
	{
		my %this = %{$dict->{$like}};
		for my $level (keys %this)
		{
			my $data = $this{$level};
			$taxa{$level}->{$2} = $1 * $likes{$like} if $data =~ m/(\d+):::(.+)/;
		}
	}
	my $like;
	while('kpcofgs' =~ m/(\w)/g)
	{
		my $level = $1;
		next unless $taxa{$level};
		my %this = %{$taxa{$level}};
		my @good = sort {$this{$b} <=> $this{$a}} keys %this;
		$like .= shift @good;
		$like .= ',' if $like;
	}
	return $like;
}

system(qq(paste -d "\t" $outfile.tab $outfile.anno > $outfile.xls));

