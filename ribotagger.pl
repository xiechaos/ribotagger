#!/usr/bin/env perl
use strict;
use Getopt::Long;
use List::Util qw(min sum);

my $version = <DATA>;
$version = $1 if $version =~ m/VERSION:\t(.+?)$/;
my $cmd = join(' ', @ARGV);
$cmd =~ s/\n/ /g;
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $date = sprintf("%4d-%02d-%02dT%02d:%02d:%02d",($year + 1900),($mon+1),$mday,$hour,$min,$sec);

my %pscore;

my @infile;
my $outfile;
my $region;
my $minscore = 30;
my $minpos = 1;
my $fp_config = 1;
my $phredoff = 33;
my $nntb = 0;
my $nnt = 33;
my $long = 60;
my $nvariant = 2;
my $nobacteria;
my $noarchaea;
my $noeukaryota;
my $nospecial;
my $funny_characters;
my $print_seq;
my $print_tag;
my $print_head;
my $print_long;
my $print_no_prefix;
my $filetype = 'guess';
my $help;

my $nofp;
my $nofp2;
my $fasta;
my $fastq;
my $seqfile;

my $nreads;

GetOptions(
	'in=s{,}' => \@infile,
	'out=s' => \$outfile,
	'region|variable=s' => \$region,

	'tag=i' => \$nnt,               
	'long=i' => \$long,            
	'before-tag=i' => \$nntb,              # hidden

	'min-score=i' => \$minscore,
	'min-pos=i' => \$minpos,

	'no-bacteria' => \$nobacteria,
	'no-archaea' => \$noarchaea,
	'no-eukaryota' => \$noeukaryota,
	'no-supplementary' => \$nospecial,

	'print-head' => \$print_head,
	'print-tag' => \$print_tag,
	'print-long' => \$print_long,
	'print-seq' => \$print_seq,
	'print-no-prefix' => \$print_no_prefix,

	'filetype=s' => \$filetype,
	'phredoff=i' => \$phredoff,     # 33, 64
	'se=i' => \$fp_config,

	'nvariant=i' => \$nvariant,      # hidden
	'funny_characters' => \$funny_characters,  # hidden

	'help' => \$help
) or die "\n";

if($help or !$outfile or !@infile)
{
	print <<"USAGE";

usage: $0 [options] -region v4|v5|v6|v7 -out OUTFILE -in INFILE1 [INFILE2 ...]

  Required:

	-in INFILE1 INFILE2 ...    one or more input files, 
	                           can be compressed by gz or bz2, but not tar
	                           files must be in fastq, fasta, or plain sequence format
	-out OUTFILE               output file
	-region [v4|v5|v6|v7]      variable region

  Optional:

	-min-score INT             minimum score at each position of 
	                           the tag or long sequences
	                           default = $minscore
	-min-pos INT               minimum number of different start positions 
	                           for a tag to be reported
	                           default = $minpos

	-no-bacteria               don't use Bacteria recognition profiles
	-no-archaea                don't use Archaea recognition profiles
	-no-eukaryota              don't use Eukaryota recognition profiles
	-no-supplementary          don't use taxa-specific supplementary profiles

	-print-head                print sequence header to screen for sequences covering a tag
	-print-tag                 print tag sequences to screen
	-print-long                print long sequences to screen
	-print-seq                 print raw sequences to screen
	-print-no-prefix           don't print prefix label for the above output

	-filetype TYPE             sequence format of input files, available options:
	                           fastq, fasta, mlfasta (multi-line fasta), seqfile (plain sequences)
	-phredoff INT              phred score offset for fastq encoding
	                           default = $phredoff
	-se INT                    number of sequencing errors used to 
	                           estimate expected number of observations of a tag
	                           due to sequencing erros
	                           default = $fp_config

	-tag INT                   length of tag to report   
	                           default = $nnt
	-long INT                  length of long sequence to report
	                           (probe sequence is included in long, 
	                           but not counted to this length) 
	                           default = $long
	-before-tag INT            length of sequence before the probe
	                           to be included in the reported long sequence
	                           default = $nntb

	-help
USAGE

	exit;
}


my $nnt2 = $long - $nnt;

#die "usage: $0 [options] -region v4|v5|v6|v7 -out OUTFILE -in INFILE1 [INFILE2 ...]\n" unless $outfile && @infile; 
die "you must specify the variable region with -region option\n" unless $region;
$region = lc $region;
$region = "v$region" if $region =~ m/^\d+$/;
die "-region accepts v4, v5, v6, or v7 only\n" unless $region =~ m/v4|v5|v6|v7/;
die "-phredoff accepts 33 or 64 only\n" unless $phredoff =~ m/33|64/;
for(@infile)
{
	die "cannot find file $_\n" unless -f $_;
}
die "--nvariant accepts 0-3 only\n" if $nvariant > 3;

die "-fp accepts 0-2 only\n" unless $fp_config =~ m/^[012]$/;
if($fp_config == 0)
{
	$nofp = 1;
	$nofp2 = 1;
}elsif($fp_config == 1)
{
	$nofp = 0;
	$nofp2 = 1;
}else
{
	$nofp = 0;
	$nofp2 = 0;
}

$filetype = lc $filetype;
die "-filetype accepts guess, fastq, fasta, mlfasta, seqfile only\n" unless $filetype =~ m/^(guess|fastq|fasta|mlfasta|seqfile)$/;
if($filetype eq 'guess')
{
	$filetype = guess_file($infile[0]) if $filetype eq 'guess';
}else
{
	my $filetypetest = guess_file($infile[0]);
	warn "provided -filetype ($filetype) differs from detected filetype ($filetypetest)\n";
}
if($filetype eq 'fasta')
{
	$fasta = 1;
}elsif($filetype eq 'fastq')
{
	$fasta = 0;
}elsif($filetype eq 'mlfasta')
{
	$fasta = 2;
}elsif($filetype eq 'seqfile')
{
	$fasta = 1;
	$seqfile = 1;
}else
{
	die "$filetype\n\nUnable to detect input file type, please check your file format, and specify -filetype option\n";
}


my $par = get_par($region, $nobacteria, $noarchaea, $noeukaryota, $nospecial);
my @primers = @{$par->{primers}};
my %pssmcheck;
for my $pri(@primers)
{
	$pssmcheck{$pri} = $par->{$pri}->{pssmcheck};
}

open(OUT, ">$outfile") or die "cannot create --out $outfile\n";

my %tag;
my %error;
my %pos;
my %other;
my %probe;


for my $inf(@infile)
{
	my $file = $inf;
	$file = "gunzip -c '$file' |" if $file =~ m/\.gz$/i;
	$file = "bzcat '$file' |" if $file =~ m/\.bz2?$/i;
	if($fasta == 2)
	{
		my $pipe_prefix = q(perl -pe 'm/^>/ ? s/^/\n/ : chomp; END{print "\n"}');
		my $pipe_suffix = q(tail -n +2);
		if($file =~ m/\|$/)
		{
			$file = "$file $pipe_prefix | $pipe_suffix |";
		}else
		{
			$file = "$pipe_prefix $file | $pipe_suffix |";
		}
	}
	open(IN, $file) or die;

	while(my $h = <IN>)
	{
		$nreads++;
		my ($seq, $nouse, $qual);
		if($seqfile)
		{
			$seq = $h;
		}elsif($fasta)
		{
			$seq = <IN>;
		}else
		{
			$seq = <IN>;
			$nouse = <IN>;
			$qual = <IN>;
		}
		chomp $seq;
		chomp $qual;
		
		$seq = uc $seq;
		my $raw_seq = $seq if $print_seq;;
		my $len = length $seq;

		for my $pi(@primers)
		{
			my $match;
			my $pscore = -Inf;
			my $rev = 0;
			while($seq =~ m/$par->{$pi}->{regex1}/g)
			{
				my $m = $1;
				my $s = pssm_eval($pi, $m);
				if($s > $pscore)
				{
					$match = $m;
					$pscore = $s;
				}
			}
			while($seq =~ m/$par->{$pi}->{regex2}/g)
			{
				my $m = reverse $1;
				$m =~ tr/ATGC/TACG/;
				my $s = pssm_eval($pi, $m);
				if($s > $pscore)
				{
					$match = $m;
					$pscore = $s;
					$rev = 1;
				}
			}
			next if $pscore < $par->{$pi}->{pssmcut};
			if($rev)
			{
				$seq = reverse $seq;
				$seq =~ tr/ATGC/TACG/;
				$qual = reverse $qual;
			}

			my $match_start = index($seq, $match);
			my $start = $match_start + length($match);

			last if $start + $nnt > $len;
			my $tag = substr($seq, $start, $nnt);

			last unless $funny_characters || $tag =~ m/^[ATGC]+$/;


			my @score;
			if($fasta)
			{
				@score = ($minscore) x $nnt;
			}else
			{
				@score = phred(substr($qual, $start, $nnt), $phredoff);
				next if min(@score) < $minscore;
			}


			my $long;
			my $other = substr($seq, $start, $nnt + $nnt2) if $start + $nnt + $nnt2 <= $len;
			if($other && ($fasta || min(phred(substr($qual, $start+$nnt, $nnt2)), $phredoff) >= $minscore))
			{
				if($nntb)
				{
					my $before = substr($seq, $match_start - $nntb, $nntb) if $match_start - $nntb >= 0;
					if(length($before) == $nntb && ($fasta || min(phred(substr($qual, $match_start - $nntb, $nntb)), $phredoff) >= $minscore))
					{
						$long = "$before$match$other";
						$other{$tag}->{$long}++;
					}
				}else
				{
					$long = "$match$other";
					$other{$tag}->{$long}++;
				}
			}

			if($print_no_prefix)
			{
				print "$h" if $print_head;
				print "$tag\n" if $print_tag;
				print "$long\n" if $print_long;
				print "$raw_seq\n" if $print_seq;
			}else
			{
				print "SOURCE:\t$h" if $print_head;
				print "TAG:\t$tag\n" if $print_tag;
				print "LONG:\t$long\n" if $print_long;
				print "RAW:\t$raw_seq\n" if $print_seq;
			}


			$tag{$tag}++;
			$pos{$tag}->{$start}++;

			unless($nofp)
			{
				unless($error{$tag})
				{
					$error{$tag} = [(0) x $nnt];
				}

				foreach(@{$error{$tag}})
				{
					my $s = shift @score;
					$_ += 10**(-0.1 * $s);
				}
			}

			last;
		}
	}
}

my $ntag = scalar(keys %tag) + 0;
my $ntagreads = sum(values %tag) + 0;
print OUT "#By:\t$version\n#Date:\t$date\n#CMD:\t$cmd\n#nreads=$nreads\n#ntagreads=$ntagreads\n#ntags=$ntag\n";
print OUT "#tag\tn\tnpos\tfp\tlong.total.count\tlong1.count\tlong2.count\tlong3.count";
print OUT "\tlong1" if $nvariant > 0;
print OUT "\tlong2" if $nvariant > 1;
print OUT "\tlong3" if $nvariant > 2;
print OUT "\n";

my $len = $nnt - 1;
for my $tag(sort {$tag{$b} <=> $tag{$a}} keys %tag)
{
	my $npos = scalar keys %{$pos{$tag}};
	next if $npos < $minpos;

	my $n = $tag{$tag};
	
	my $fp = 0;
	my $fp2 = 0;
	unless($nofp)
	{
		my %done2;
		for my $pos (0..$len)
		{
			my $original = substr($tag, $pos, 1);
			for my $nt (qw(A T G C))
			{
				next if $original eq $nt;
				my $temp = $tag;
				substr($temp, $pos, 1) = $nt;
				next unless $tag{$temp};
				$fp += $tag{$temp} * $error{$tag}[$pos] / $n / 3;

				unless($nofp2)
				{
					for my $pos2 (0..$len)
					{
						next if $pos == $pos2;
						my $original2 = substr($temp, $pos2, 1);
						for my $nt (qw(A T G C))
						{
							next if $original2 eq $nt;
							my $temp2 = $temp;
							substr($temp2, $pos2, 1) = $nt;
							next if $done2{$temp2};
							$done2{$temp2} = 1;
							next unless $tag{$temp2};
							$fp2 += $tag{$temp2} * $error{$tag}[$pos2] / $n / 3 * $error{$tag}[$pos] / $n / 3;
						}
					}
				}
			}
		}
	}
	$fp += $fp2;
	$fp = sprintf("%.4f", $fp);
#	$fp2 = sprintf("%.4f", $fp2);

	my $divtotal = 0;
	my @divtag = ('', '', '');
	my $div0 = 0;
	my $div1 = 0;
	my $div2 = 0;
	if($other{$tag})
	{
		my %oth = %{$other{$tag}};
		$divtotal = sum(values %oth);
		@divtag = sort {$oth{$b} <=> $oth{$a}} keys %oth;
		$div0 = 0 + $oth{$divtag[0]};
		$div1 = 0 + $oth{$divtag[1]};
		$div2 = 0 + $oth{$divtag[2]};
	}

	print OUT "$tag\t$n\t$npos\t$fp\t$divtotal\t$div0\t$div1\t$div2";
	print OUT "\t$divtag[0]" if $nvariant > 0;
	print OUT "\t$divtag[1]" if $nvariant > 1;
	print OUT "\t$divtag[2]" if $nvariant > 2;
	print OUT "\n";
}



sub phred
{
	my $qual = shift;
	my $phredoff = shift;
	map { ord($_) - $phredoff } split('', $qual);
}
sub guess_file
{
	my $file = shift;
	$file = "gunzip -c '$file' |" if $file =~ m/\.gz$/i;
	$file = "bzcat '$file' |" if $file =~ m/\.bz2?$/i;
	open(IN, $file) or die;

	my $fasta;
	my $fastq;
	my $mlfasta;
	my $seqfile;
	my $phred64;

	my $i;
	while(my $h1 = <IN>)
	{
		my $s1 = <IN> if $h1;
		my $h2 = <IN> if $s1;
		my $s2 = <IN> if $h2;

		last unless $s2;

		$i++;

		if($h1 =~ m/^>/)
		{
			$mlfasta++;
		}
		if($h1 =~ m/^>/ && $h2 =~ m/^>/)
		{
			$fasta++;
		}
		if($h1 =~ m/^@/)
		{
			$fastq++;
			chomp $s2;
			my @qual = phred($s2, 33);
			for(@qual)
			{
				$phred64++ if $_ > 55;
			}
		}
		if($h1 =~ m/^[ATGCN]/i && $h2 =~ m/^[ATGCN]/i && $s1 =~ m/^[ATGCN]/i && $s2 =~ m/^[ATGCN]/i)
		{
			$seqfile++;
		}
		last if $i >= 1000;
	}

	my $log = "fasta: $fasta / $i\n".
		"fastq: $fastq / $i\n".
		"seqfile: $seqfile / $i\n".
		"mlfasta: $mlfasta / $i\n";

	if($phred64)
	{
		$phredoff = 64;
		warn "input quality encoding is old Solexa/Illumina(pre-1.8), using 64 as offset\n";
	}

	return 'fasta' if $fasta == $i;
	return 'fastq' if $fastq == $i;
	return 'seqfile' if $seqfile == $i;
	return 'mlfasta' if $mlfasta > 0 && $fasta < $i;
	return $log;
}

sub get_par
{
	my $reg = shift;
	$reg = lc $reg;

	my $nobact = shift;
	my $noarch = shift;
	my $noeuka = shift;
	my $nospec = shift;

	my $raw_par = join('', <DATA>);
	my %par;
	while($raw_par =~ m/>>>>\nREGION\t$reg\n(.+?)<<<<\n/sg)
	{
		$_ = $1;
		my $type = $1 if m/^TYPE\t(\S+?)\n/m;
		next if $type =~ m/^Archaea/i && $noarch;
		next if $type =~ m/^Bact/i && $nobact;
		next if $type =~ m/^Eu/i && $noeuka;

		my $special = $1 if m/^TARGET\t(.+?)\n/m;
		next if $special && $nospecial;

		my $order = $1 if m/^ORDER\t(\d+?)\n/m;
		while($par{$order})
		{
			$order++;
		}

		my $primer = $1 if m/^REGEX\t(\S+?)\n/m;

		my $pssmcut = $1 if m/^PSSMCUT\t(\d+?)\n/m;
		my $pssm = $1 if m/^PSSM=>\n(.+\n)^<=PSSM/ms;
		my $pssmcheck = 0;
		my ($pssmref, $pssmcheck) = pssm_read($pssm, $primer);


		if($pssmcheck >= $pssmcut)
		{
			$pssmcheck = 0;
		}else
		{
			$pssmcheck = 1;
		}

		$primer =~ s/\[(\w)\]/$1/g;
		$primer =~ s/\[[ATCG]{4}\]/./g;
		my $primer2 = reverse $primer;
		$primer2 =~ tr/ATGC][/TACG[]/;
		my $regex1 = qr/($primer)/;
		my $regex2 = qr/($primer2)/;

		$par{$order}->{pssmcheck} = $pssmcheck;
		$par{$order}->{pssmcut} = $pssmcut;
		$par{$order}->{regex1} = $regex1;
		$par{$order}->{regex2} = $regex2;
		$par{$order}->{pssm} = $pssmref;
	}
	my @primers = sort {$a <=> $b} keys %par;
	$par{primers} = \@primers;
	
	return \%par;
}

sub pssm_read
{
	my $pssm = shift;
	my $primerele = shift;
#	print $pssm, "\n";
	$primerele =~ s/^\[|\]$//g;
	my @primerele = split(/\]\[/, $primerele);

	my %pssm;
	my $pssmcheck;

	my $pos = 1;
	while($pssm =~ m/^(.+)\n/mg)
	{
		my @a = split(/\t/, $1);
		$pssm{$pos}->{A} = $a[0];
		$pssm{$pos}->{T} = $a[1];
		$pssm{$pos}->{G} = $a[2];
		$pssm{$pos}->{C} = $a[3];

		my %temp = %{$pssm{$pos}};
		my $ele = shift @primerele;
		my $min = min(@temp{split(//, $ele)});
		$pssmcheck += $min;

		$pos++;
	}
	return(\%pssm, $pssmcheck);
}
sub pssm_eval
{
	my $pi = shift;
	my $match = shift;
	my $pscore = $pscore{$pi}->{$match};
	unless(defined $pscore)
	{
		my @nt = split(//, $match);
		my $pos;
		for my $nt(@nt)
		{
			$pos++;
			$pscore += $par->{$pi}->{pssm}->{$pos}->{$nt};
		}
		$pscore{$pi}->{$match} = $pscore;
	}
	return $pscore;
}

__END__
VERSION:	RiboTagger v0.8.1 (PSSM: 2014-08-01)


>>>>
REGION	v4
ORDER	1
TYPE	Bacteria
REGEX	[TC][AG][G][G][TC][ATCG][TC][A][ACG][AG][AG][ATCG][AG][ATCG][ATCG][ATCG][TCG][TCG][AG][ATCG][ACG][TCG][ATCG][TG]
PSSMCUT	16
PSSM=>
-6.78979246970476	1.38430396445971	-6.0288471609302	-5.48105634293074
-4.28562180077854	-6.4192390765604	1.38228721698971	-8.47625358245279
-5.56778122538218	-6.35395447687323	1.38409950390266	-6.10564756965628
-5.91557248609016	-6.81702981867021	1.38477839444301	-6.32166045314091
-7.05090631516159	-0.170797133923337	-5.94585485421246	1.1484119504642
-3.92507311757291	-0.665687940653109	1.24179179858785	-5.49546051513514
-6.19525816930171	1.38417662019842	-6.3654623353217	-5.44527296303189
1.38378029067814	-5.70917318711214	-5.74843442793569	-6.69576028837669
1.38187696822437	-5.71107981128447	-4.93142899682781	-5.0400017840422
1.38346580348613	-7.08237067999106	-4.73233500775663	-6.70266970881902
-5.34684555806188	-7.00913688555212	1.38441572070263	-6.66367701243353
-0.768460257531124	-5.22102707345324	0.526286161513313	0.608481745201711
-4.15231471044932	-7.01280837798932	1.38165711034039	-6.49011317866795
-0.125978900814393	-0.0134944316798519	-3.34644491186351	0.740104502664214
-0.816489419132753	-0.413975194814714	0.99901422779941	-1.70891227522491
-3.59806834076896	-0.918905837905615	-5.22733342067765	1.27196228376917
-5.63075399077692	-3.92285843305041	1.37023040830652	-3.21856248836534
-6.25997790816814	0.985630777208078	-4.06333932557473	0.263197215272763
1.38389458303896	-6.61444923447018	-5.24585445044969	-6.02833481076042
-3.91395580123556	-4.98964397050605	1.37471464137193	-4.38762218978206
-1.23726831701054	-6.46607586267872	1.30603461053788	-4.12410392977629
-6.02169799330721	-0.0366006266476738	-4.65639810518357	1.10645357641753
-5.19135028730575	-2.76168573010693	1.35677797207963	-3.05977416874231
-5.82390788266035	-4.86708610767911	1.38326067242695	-6.92025002279392
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	2
TYPE	Archaea
REGEX	[TC][ATG][AG][G][TC][TC][TC][AG][AG][AG][AG][TCG][AG][TCG][TC][TC][G][TC][ACG][AG][TC][ATC][ATCG][AG]
PSSMCUT	18
PSSM=>
-6.87820530023108	1.38382235943643	-6.7156863707333	-5.3547098175977
-5.2925780364907	-2.41908146811342	1.36123285286789	-7.00336844318508
-1.57226996540323	-7.00336844318508	1.33215897636325	-7.51419406695107
-5.86127104257723	-6.76697966512085	1.38424743269206	-6.12789970583118
-6.82104688639113	-0.486780967610286	-6.31022126262514	1.21811050408211
-6.93882992204751	-0.548484394708381	-6.57592442835814	1.22850432932347
-6.57592442835814	1.38430814269557	-7.22651199449929	-5.40735355108312
1.38040001658481	-6.41558177828296	-3.92452126292059	-7.40883355129325
1.38319960456147	-7.22651199449929	-4.63001427930283	-6.93882992204751
1.38298686770097	-7.91965917505924	-5.02007076205815	-7.31352337148892
-0.741113691295539	-6.93882992204751	1.25829573677279	-7.14646928682576
-6.02253919017336	-2.27009825456968	-0.688975343438251	1.22100952366763
0.370340608767507	-7.76550849523198	0.936051778511275	-7.91965917505924
-6.76697966512085	1.34120002481606	-3.96841545647781	-1.86248491792322
-5.65097563374087	-0.373212901313215	-6.12789970583118	1.19492258324785
-6.27743143980215	-1.68328958485553	-6.7156863707333	1.33748526311475
-6.04785699815765	-7.31352337148892	1.38496054256395	-6.93882992204751
-7.31352337148892	1.38412600162681	-7.40883355129325	-5.20055913777044
1.38181600531079	-7.40883355129325	-5.40735355108312	-4.48567197057409
-4.7769447111566	-5.76017492570587	1.38149644113273	-6.07383248456091
-6.76697966512085	-4.32234691447079	-6.37921413411209	1.38186164900094
-4.83622132108614	-0.50830431740285	-5.92722901036903	1.2195789594238
-4.16234255939207	-0.806924315390563	1.252078959135	-3.29795968711994
-5.39393053075098	-6.76697966512085	1.3843992007907	-7.51419406695107
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	100
TYPE	Bacteria
TARGET	Lentisphaerae
REGEX	[T][G][G][G][C][CG][T][A][AG][A][G][G][G][T][TC][TC][G][TC][A][G][G][ATCG][TG][G]
PSSMCUT	10
PSSM=>
-Inf	1.38314077919382	-Inf	-4.37449836825309
-Inf	-Inf	1.38566443983922	-Inf
-5.98393628068719	-Inf	1.3850341215076	-5.98393628068719
-Inf	-5.98393628068719	1.3850341215076	-5.98393628068719
-Inf	-5.98393628068719	-Inf	1.38566443983922
-5.98393628068719	-Inf	1.1044724979882	-0.0203569370687441
-5.98393628068719	1.38566443983922	-Inf	-Inf
1.38314077919382	-5.98393628068719	-4.88532399201908	-5.98393628068719
1.0994515669381	-Inf	-0.0101266688179292	-4.88532399201908
1.38440340562419	-Inf	-5.29078910012725	-5.98393628068719
-5.29078910012725	-Inf	1.3850341215076	-Inf
-5.98393628068719	-5.98393628068719	1.3850341215076	-Inf
-5.29078910012725	-Inf	1.3850341215076	-Inf
-Inf	1.38250886764041	-Inf	-4.19217681145914
-5.29078910012725	0.342213192467909	-5.29078910012725	0.948511610885318
-Inf	-2.40041734223108	-Inf	1.36336342005597
-Inf	-4.37449836825309	1.38187655652228	-5.29078910012725
-5.29078910012725	0.551304990326468	-Inf	0.815119581371606
1.38124384533382	-Inf	-5.29078910012725	-4.19217681145914
-4.19217681145914	-5.98393628068719	1.37870898973063	-4.5976419195673
-5.98393628068719	-Inf	1.38566443983922	-Inf
-2.27036421398288	-2.24626666240382	1.32259511825231	-3.41898692322565
-5.98393628068719	-2.93941384296377	1.37170482228706	-Inf
-5.29078910012725	-Inf	1.38440340562419	-5.98393628068719
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	200
TYPE	Bacteria
TARGET	SR1
REGEX	[T][G][G][G][TC][G][T][A][A][A][G][ATCG][AG][TC][C][TC][G][TC][A][AG][ATC][TC][TG][G]
PSSMCUT	10
PSSM=>
-Inf	1.38397686297953	-Inf	-4.68213122712422
-4.68213122712422	-Inf	1.38397686297953	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-4.68213122712422	-Inf	1.38397686297953	-Inf
-Inf	-3.58351893845611	-Inf	1.3793256918038
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38397686297953	-4.68213122712422	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38165398156339	-Inf	-3.98898404656427	-Inf
-4.68213122712422	-Inf	1.38397686297953	-Inf
-0.0870113769896298	0.674455047547793	-2.484906649788	0.0363676441708748
-2.484906649788	-Inf	1.36524095192206	-Inf
-Inf	1.3793256918038	-Inf	-3.58351893845611
-3.98898404656427	-3.98898404656427	-Inf	1.37699196845758
-Inf	0.575364144903562	-Inf	0.798507696217772
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.33646198737201	-Inf	-1.6376087894008
1.38629436111989	-Inf	-Inf	-Inf
-3.58351893845611	-4.68213122712422	1.37699196845758	-Inf
-3.29583686600433	0.465363249689233	-Inf	0.863046217355343
-Inf	-0.419451350082904	-Inf	1.20674673120866
-Inf	0.760286483397574	0.611173597600273	-3.98898404656427
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	300
TYPE	Bacteria
TARGET	TM7
REGEX	[T][G][G][G][TC][G][T][A][A][AG][AG][AG][TG][T][T][G][TC][G][T][A][AG][G][TC][G][G]
PSSMCUT	10
PSSM=>
-6.25910333830874	1.38246110295223	-4.87280897718885	-5.16049104964063
-5.5659561577488	-Inf	1.38485861069379	-Inf
-5.16049104964063	-Inf	1.38485861069379	-Inf
-5.5659561577488	-5.5659561577488	1.38198091086617	-4.87280897718885
-Inf	-1.15923691048454	-5.5659561577488	1.30357790841314
-6.25910333830874	-6.25910333830874	1.38485861069379	-6.25910333830874
-Inf	1.38485861069379	-Inf	-5.5659561577488
1.38437956876846	-Inf	-4.87280897718885	-Inf
1.38437956876846	-5.5659561577488	-5.5659561577488	-Inf
1.38053894954927	-6.25910333830874	-3.86120806551037	-Inf
-3.86120806551037	-Inf	1.38101983438662	-Inf
1.37620054795067	-4.87280897718885	-3.55105313720653	-5.5659561577488
-Inf	-3.55105313720653	1.37861309435606	-Inf
-Inf	1.36697941976364	-Inf	-4.46734386908069
-4.87280897718885	1.38437956876846	-Inf	-Inf
-6.25910333830874	-5.5659561577488	1.38485861069379	-Inf
-Inf	-3.86120806551037	-Inf	1.38101983438662
-5.5659561577488	-Inf	1.38437956876846	-5.5659561577488
-Inf	1.38533742324782	-5.5659561577488	-Inf
1.38390029725197	-5.5659561577488	-5.5659561577488	-6.25910333830874
-3.86120806551037	-5.16049104964063	1.37475022137303	-5.5659561577488
-6.25910333830874	-6.25910333830874	1.38485861069379	-6.25910333830874
-6.25910333830874	0.740319129199218	-Inf	0.64061976897613
-6.25910333830874	-Inf	1.38390029725197	-5.5659561577488
-5.5659561577488	-6.25910333830874	1.38390029725197	-6.25910333830874
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	400
TYPE	Bacteria
TARGET	Acidobacteria_Gp2
REGEX	[T][G][G][G][TC][G][T][A][A][A][G][ACG][G][TC][TCG][ATC][G][T][A][G][G][TC][G][G]
PSSMCUT	10
PSSM=>
-Inf	1.38195595952129	-Inf	-4.74927052996185
-Inf	-Inf	1.3841275130348	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-4.74927052996185	1.3841275130348	-Inf
-Inf	0.731368393380143	-4.74927052996185	0.639801199854653
-Inf	-4.74927052996185	1.38195595952129	-Inf
-Inf	1.3841275130348	-Inf	-Inf
1.3841275130348	-Inf	-Inf	-Inf
1.3841275130348	-Inf	-Inf	-Inf
1.38195595952129	-Inf	-Inf	-Inf
-Inf	-Inf	1.3841275130348	-Inf
-3.36297616884196	-Inf	1.3688266680795	-3.65065824129374
-Inf	-Inf	1.3841275130348	-Inf
-4.74927052996185	1.37322227955254	-Inf	-3.36297616884196
-4.74927052996185	0.996932660578305	-2.95751106073379	0.192371892647456
-2.55204595262563	-1.41706601978664	-Inf	1.30281863896257
-4.74927052996185	-4.74927052996185	1.38195595952129	-Inf
-Inf	1.38195595952129	-Inf	-4.0561233494019
1.38629436111989	-Inf	-Inf	-Inf
-4.74927052996185	-4.74927052996185	1.38195595952129	-Inf
-Inf	-Inf	1.3841275130348	-4.74927052996185
-Inf	-1.5712166996139	-Inf	1.3329483804146
-Inf	-4.0561233494019	1.38195595952129	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Bacteria
TARGET	Acidobacteria_Gp25
REGEX	[T][G][G][G][C][G][T][A][A][A][G][G][G][C][G][C][G][TC][A][TCG][G][TC][TG][ATG]
PSSMCUT	10
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.37079017458393	-Inf	-2.78809290877575
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-2.78809290877575	1.35504181761579	-2.78809290877575
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-1.40179854765586	-Inf	1.32278095539756
-Inf	-1.68948062010764	1.33904147626935	-Inf
1.1239300966524	-0.303186258987746	-1.68948062010764	-Inf
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	600
TYPE	Bacteria
TARGET	25nt-op11
REGEX	[TC][G][G][G][TC][G][AT][A][A][A][G][ACG][G][T][ATCG][ATCG][TC][G][TC][A][G][G][TC][TCG][ATCG]
PSSMCUT	10
PSSM=>
-Inf	1.36160174852952	-Inf	-2.32727770558442
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-2.32727770558442	-Inf	1.36160174852952
-Inf	-Inf	1.38629436111989	-Inf
-2.32727770558442	1.36160174852952	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-0.381367556529104	-Inf	-0.381367556529104	0.968559160419912
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-1.63413052502447	1.10670949890073	-2.32727770558442	-0.381367556529104
-2.32727770558442	1.16922985588206	-0.717839793150317	-1.63413052502447
-Inf	-0.940983344464527	-Inf	1.28364020705981
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.28364020705981	-Inf	-0.940983344464527
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	0.157628944203583	-Inf	1.04001812440206
-Inf	-0.130053128248198	1.10670949890073	-2.32727770558442
-0.940983344464527	0.445311016655364	0.617161273582023	-1.63413052502447
<=PSSM
<<<<


>>>>
REGION	v5
ORDER	1
TYPE	Bacteria
REGEX	[G][TC][AG][AG][TC][TC][TC][ATCG][ATCG][ACG][C][ATCG][ATCG][TC][A][AG][AG][TC][ATCG][ATCG][ATC][ACG]
PSSMCUT	16
PSSM=>
-6.09722324581225	-6.10774175000348	1.38451770599569	-6.8794222039881
-7.34079019110572	1.384799591274	-7.16540107108741	-5.51590667445263
1.38465989436642	-6.70356706487697	-5.488694970093	-8.07086492530621
-5.05555389396597	-5.60598688091906	1.38324559878934	-6.96879326073173
-7.48565540840131	1.38436317122405	-7.77533548351576	-5.14373445457696
-6.58627677969051	-5.08057468718724	-5.93930124339806	1.38341836985828
-7.33054466510384	-3.90236419613834	-8.32687810465154	1.3806697503724
1.27834807595267	-1.23875875684266	-2.54641213490737	-3.21867924947965
-1.52648988269811	-0.863356413371338	-2.21182723128455	1.17895376441662
-1.08804164928252	-6.77742398602547	1.29392540419476	-4.29818726391333
-7.59296184951314	-6.03551923219742	-7.25173901013333	1.38522870286167
-1.59776703624685	-0.462844635091086	-1.96447748283138	1.10735612256864
-3.89033270479877	-4.45468676409891	1.26209079570969	-0.834730489934387
-6.67398952055804	1.38426876936715	-6.70094533054657	-5.29503586640875
1.38400317016817	-5.987563684552	-5.94684893438811	-5.82578229238357
1.3836750612646	-6.71188237123886	-5.41889743034732	-6.5971734234629
1.38335658727154	-6.57764128822187	-5.07732834870104	-5.88087746719174
-6.7922898213844	-5.33800109110715	-6.57998322140007	1.38438968433273
-4.6182557983661	-2.97211467863198	1.36961445225087	-5.39553985813224
1.19343852859967	-1.66483830831042	-0.743954722712074	-3.29965505246114
-5.444009523241	1.38278193968511	-5.75635828845319	-5.06960771818994
-5.23057606704565	-6.72278944704928	1.38177814481901	-4.49650639450293
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	2
TYPE	Archaea
REGEX	[ATG][T][A][G][TC][TC][TC][ATCG][ATCG][ACG][TCG][ATC][ACG][TC][ATC][AG][AG][TCG][ATCG][ATC][TC][AG]
PSSMCUT	15
PSSM=>
-4.51846179339708	-4.96648651592404	1.37997330439571	-7.22651199449929
-6.76697966512085	1.38424743269206	-7.00336844318508	-5.52176390226087
1.38442955164659	-6.45332210626581	-5.8402176333794	-7.91965917505924
-5.72243459772302	-6.41558177828296	1.38365531692372	-6.57592442835814
-7.00336844318508	1.38280448579275	-7.14646928682576	-4.65517283893899
-6.31022126262514	-5.4209592031389	-7.91965917505924	1.38347305689892
-6.7156863707333	-3.41615264284765	-6.87820530023108	1.37672126900933
-1.17618909038496	0.322833978128387	-3.29142371614015	0.81808754980211
1.1573593061549	-5.04797955017523	-0.222613549408939	-5.12645116561672
-2.39953248021013	-6.07383248456091	1.35970962332737	-5.17881915113404
-6.41558177828296	-5.36761322243361	-0.581746175378566	1.23241628878497
-3.69039529493777	0.941005510450821	-6.27743143980215	0.341910316487995
-5.49191093911119	-5.77959301156297	1.38307804618291	-5.46292340223793
-7.00336844318508	1.38116155004532	-6.45332210626581	-4.15459058258776
1.38012572250937	-5.30469939702304	-5.76017492570587	-4.51292161302147
1.38339710541669	-6.76697966512085	-5.17881915113404	-7.14646928682576
1.37951591061744	-6.76697966512085	-4.91562809869055	-6.10050073164307
-6.87820530023108	-3.57153409206104	-2.42454223253659	1.35554778923328
-2.0887546929637	-0.30855889054071	1.11326757647557	-2.3738309007487
1.20452400046577	-4.23495509235578	-5.56828391789576	-0.440265432914598
-6.53336481393935	1.38341229617463	-7.00336844318508	-5.05745829412977
-1.92196407820062	-6.41558177828296	1.34753400850973	-6.7156863707333
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	100
TYPE	Archaea
TARGET	Korachaeota
REGEX	[G][T][AG][AG][T][C][C][C][A][CG][C][TCG][G][T][A][A][AG][C][G][A][TG][G]
PSSMCUT	10
PSSM=>
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.32745386109696	-Inf	-1.47590651980958	-Inf
-2.16905370036952	-Inf	1.35730682424664	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.35730682424664	-2.16905370036952
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-2.16905370036952	-2.16905370036952	1.32745386109696
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.35730682424664	-Inf	-2.16905370036952	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.35730682424664	-2.16905370036952	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	200
TYPE	Bacteria
TARGET	Subdivision5
REGEX	[G][T][A][G][T][C][TC][ATC][ATCG][AG][C][TC][ATCG][T][A][A][A][C][TG][ATG][TC][G]
PSSMCUT	10
PSSM=>
-5.26656866823346	-5.26656866823346	1.38241588179132	-5.26656866823346
-5.26656866823346	1.38241588179132	-5.26656866823346	-5.26656866823346
1.38111970532987	-4.16795637956535	-Inf	-Inf
-Inf	-Inf	1.38371038035397	-5.26656866823346
-Inf	1.38371038035397	-Inf	-Inf
-Inf	-4.16795637956535	-Inf	1.38241588179132
-Inf	-1.68304972977735	-Inf	1.33872925271475
-0.622177769092084	-3.18712712655362	-5.26656866823346	1.22718517161823
0.54756186359161	-1.29627675468133	0.447164137275913	-0.835751869390143
0.476434519576026	-Inf	0.862481541827089	-4.16795637956535
-5.26656866823346	-Inf	-Inf	1.38500320535627
-5.26656866823346	-0.185164303248993	-Inf	1.15179626770276
-3.32065851917814	0.335550152646244	0.764116592027807	-0.884542033559575
-Inf	1.38371038035397	-Inf	-4.57342148767351
1.38111970532987	-5.26656866823346	-5.26656866823346	-Inf
1.38111970532987	-Inf	-4.57342148767351	-Inf
1.37982184661427	-Inf	-4.57342148767351	-5.26656866823346
-5.26656866823346	-5.26656866823346	-Inf	1.38241588179132
-5.26656866823346	-0.5043947334357	1.21500846104297	-4.57342148767351
-3.88027430711357	-0.812221371979949	1.25699363791606	-4.57342148767351
-5.26656866823346	1.37199912093306	-5.26656866823346	-3.32065851917814
-5.26656866823346	-Inf	1.38111970532987	-4.16795637956535
<=PSSM
<<<<



>>>>
REGION	v5
ORDER	300
TYPE	Bacteria
TARGET	Acidobacteria_Gp2
REGEX	[G][T][A][G][TC][C][C][T][A][G][C][C][C][T][A][A][A][C][CG][A][T][C]
PSSMCUT	10
PSSM=>
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.37759865415234	-Inf	-3.36297616884196
-Inf	-4.0561233494019	-Inf	1.38195595952129
-Inf	-Inf	-Inf	1.38629436111989
-4.0561233494019	1.37759865415234	-Inf	-4.0561233494019
1.38629436111989	-Inf	-Inf	-Inf
-4.0561233494019	-Inf	1.38195595952129	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.38629436111989	-Inf	-Inf
1.38195595952129	-4.0561233494019	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-4.0561233494019	0.993732657847634	0.247941743802267
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	400
TYPE	Archaea
TARGET	Methanococci
REGEX	[G][T][A][CG][TC][C][AC][TCG][AG][G][TCG][ATC][G][T][A][A][A][TCG][TG][ATC][AT][G]
PSSMCUT	10
PSSM=>
-Inf	-Inf	1.3831839387055	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.3831839387055	-4.38825718442452
-Inf	1.37693391836033	-Inf	-3.28964489575641
-Inf	-Inf	-Inf	1.38629436111989
-4.38825718442452	-Inf	-Inf	1.3831839387055
-Inf	1.1914726415617	-4.38825718442452	-0.362905493689368
-1.99036191162615	-Inf	1.35153572775472	-Inf
-Inf	-Inf	1.3831839387055	-Inf
-Inf	-3.28964489575641	-4.38825718442452	1.37064458945276
-4.38825718442452	-0.0444517625708338	-Inf	1.10068054173217
-Inf	-Inf	1.3831839387055	-Inf
-Inf	1.3831839387055	-Inf	-Inf
1.3831839387055	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.3831839387055	-Inf	-Inf	-Inf
-Inf	-4.38825718442452	-3.00196282330463	1.37064458945276
-Inf	1.31552529023168	-1.34373474670109	-Inf
-3.28964489575641	0.284571650037389	-Inf	0.968329090247495
-4.38825718442452	1.3831839387055	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<


>>>>
REGION	v6
ORDER	1
TYPE	Bacteria
REGEX	[G][GAT][C][GA][GA][C][GA][GA][CG][C][GA][CT][G][C][GA][CGAT][C][GA][CT][C][CT]
PSSMCUT	10
PSSM=>
-6.40362960792256	-8.11550241223311	1.38573424310258	-8.84293866627169
1.38225561705239	-4.6037758541982	-5.20045505951051	-7.7365908990673
-6.66130330674053	-6.13951437817727	-6.62268847061275	1.3850317171878
-4.93695282203602	-6.72078868886688	1.38371868019655	-6.56624015743302
1.3844667301152	-7.11107649910234	-5.09370738606488	-8.37003143784563
-7.41119956088184	-6.44294909007698	-7.89462621045972	1.38558808620347
1.36174803731244	-6.23073167828746	-2.38087458424159	-6.26545738966129
0.731984494970774	-7.67675160389872	0.651960228470267	-7.23336726092826
-6.97292616062153	-6.08646666953062	-3.81326018821873	1.37984454072728
-7.93116553929131	-6.38539425406148	-8.39930175436225	1.385626621846
1.36822046242901	-6.95519224764661	-2.66121786439078	-7.27144769254245
-7.14031285357644	1.38437169891857	-7.5935093645058	-5.07635067088061
-6.16319475989519	-8.35564605847875	1.38564184131644	-8.79747881075779
-8.05023502529954	-6.10884636096307	-7.54151688387311	1.38546874808895
1.38372619943164	-6.78697808897673	-4.92114607906165	-6.77808914155949
-3.30508374902776	-4.35886233150482	0.602231137681318	0.75327885473371
-7.61369276274415	-5.58931099824734	-7.47422663459981	1.38500989014484
1.38333637610898	-6.84517740024877	-4.73735688898932	-6.35025036255058
-6.7840214306181	-4.36662507235682	-6.33880314823275	1.38231116517055
-7.79179490468804	-5.966721228776	-6.77209678277694	1.38520053106862
-6.51729437229835	1.38377665071185	-6.56143626552828	-4.9731225183202
<=PSSM
<<<<

>>>>
REGION	v6
ORDER	2
TYPE	Archaea
REGEX	[GT][CGAT][CAT][GA][GAT][CT][GA][GA][CG][C][GA][CT][G][C][GA][CGA][CT][CAT][C][CT][CGT]
PSSMCUT	15
PSSM=>
-6.49096491797581	-4.79451562855208	1.38221751744119	-7.79024790210607
0.800938969218495	-3.33590060585256	0.532065203268818	-3.57074019692996
-4.58479509757001	-5.08219770100386	-6.05564684671796	1.37965234687209
-5.42312428797445	-6.40395354098618	1.3833247456779	-6.69163561343796
1.06617562364253	-5.01765917986629	0.0800453599155429	-6.80941864909434
-6.58627509778013	-1.83354734743443	-6.05564684671796	1.34299541948515
-3.74136571396073	-6.80941864909434	1.37795015967215	-5.66998436590598
-4.54505476892049	-7.79024790210607	1.38173271931548	-6.40395354098618
-5.89312791722019	-6.05564684671796	-5.27794227812995	1.38166344325033
-7.09710072154612	-5.79781773741586	-6.32391083331264	1.38322099509421
1.38086642336928	-7.50256582965429	-4.24446929163281	-7.09710072154612
-7.50256582965429	1.38284048416723	-7.50256582965429	-5.10467055685592
-5.79781773741586	-7.27942227834008	1.38349763940056	-7.27942227834008
-8.88886019077418	-5.75336597484503	-6.58627509778013	1.38373964040432
1.36225147018026	-6.69163561343796	-2.47704192306428	-6.49096491797581
-3.66850436569585	-5.59302332476985	-4.97683718534603	1.37600124835715
-7.27942227834008	-1.63326891652051	-7.79024790210607	1.33449827002859
0.685150599653123	0.693664234741507	-5.66998436590598	-5.27794227812995
-7.27942227834008	-6.24980286115892	-7.09710072154612	1.38418891552376
-7.79024790210607	-2.06993612549866	-7.79024790210607	1.35274110751242
-6.40395354098618	1.37209199381493	-4.97683718534603	-3.15228789329499
<=PSSM
<<<<

>>>>
REGION	v6
ORDER	100
TYPE	Bacteria
TARGET	Armatimonadetes
REGEX	[G][A][C][G][A][C][A][GA][C][C][A][T][G][C][A][GA][C][CA][CGAT][CG][T]
PSSMCUT	15
PSSM=>
-Inf	1.38210148285985	-4.78331637137157	-4.78331637137157
-4.09016919081162	-Inf	-0.208605392868183	1.15421983371086
-0.999126737453304	-1.60526254102362	-0.722873360825146	1.08031480422653
1.35441068271467	-5.47646355193151	-Inf	-2.10916772194504
-Inf	-4.78331637137157	-Inf	1.38420011951678
1.37577901712037	-5.47646355193151	-3.68470408270346	-5.47646355193151
1.38105051061388	-Inf	-4.09016919081162	-Inf
-Inf	-Inf	-5.47646355193151	1.38524778854922
-Inf	-Inf	1.38629436111989	-Inf
-5.47646355193151	1.38420011951678	-5.47646355193151	-Inf
1.38524778854922	-Inf	-5.47646355193151	-Inf
-Inf	-4.78331637137157	-Inf	1.38315135172269
-5.47646355193151	-5.47646355193151	-4.3778512632634	1.37894524667842
-1.86554563928729	-Inf	1.34464392032495	-5.47646355193151
1.38420011951678	-Inf	-5.47646355193151	-Inf
-5.47646355193151	-4.78331637137157	-Inf	1.38315135172269
1.38524778854922	-Inf	-5.47646355193151	-Inf
-Inf	-Inf	1.38524778854922	-Inf
-Inf	-5.47646355193151	-Inf	1.38524778854922
1.38524778854922	-Inf	-5.47646355193151	-Inf
-Inf	-5.47646355193151	1.38524778854922	-Inf
<=PSSM
<<<<


>>>>
REGION	v6
ORDER	200
TYPE	Bacteria
TARGET	OP11
REGEX	[GT][A][CG][CG][GA][CT][GA][CG][C][C][A][T][GA][C][A][CGA][C][A][CGT][C][T]
PSSMCUT	15
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-2.39789527279837	0.435318071257845	0.860201265223112
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.03609193168678	-Inf	0.0870113769896297	-2.39789527279837
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-3.09104245335832	-Inf	1.37486566529627	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.37486566529627	-3.09104245335832
1.15745278869104	-Inf	-0.200670695462151	-Inf
-Inf	-0.893817876022096	-Inf	1.27840539910871
1.37486566529627	-Inf	-3.09104245335832	-Inf
-Inf	-Inf	1.37486566529627	-3.09104245335832
-Inf	-Inf	-3.09104245335832	1.37486566529627
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-2.39789527279837	1.36330484289519	-Inf
<=PSSM
<<<<

>>>>
REGION	v6
ORDER	300
TYPE	Archaea
TARGET	Methanococci
REGEX	[G][A][CT][G][A][CT][G][G][CA][C][A][T][G][C][A][CGA][C][A][C][C][T]
PSSMCUT	10
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-3.51154543883102	-Inf	-3.51154543883102	1.37125648375535
1.31676829847128	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-3.51154543883102	-Inf	-Inf	1.37880368939073
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	0.765120680185035	-Inf	0.615588946214071
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-2.81839825827108	-Inf	1.37125648375535
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v7
ORDER	1
TYPE	Bacteria
REGEX	[AC][AG][G][TC][TCG][TCG][ATCG][ATCG][ATCG][AG][AG][C][G][AG][AG][C][G][ATC][AG][AG][C][C][TC]
PSSMCUT	10
PSSM=>
1.38392098518535	-6.93400848985794	-5.70315874879329	-5.387914410187
1.38442378963016	-7.1660342870646	-5.12368528991359	-7.41672779014704
-6.35605560958841	-6.89367146672197	1.38536958266272	-7.37298986724225
-7.66250139647532	1.38464082378726	-8.10433414875436	-5.16870579927008
-6.85134952300066	-5.51969573972837	-1.3195171779831	1.31571414979087
-6.42824968404901	-4.39971853600539	-4.21748813275965	1.3790641907038
-3.55534386375074	-2.15122621061993	-2.44380807875004	1.3265467363261
-0.921031020463147	-3.00276111489393	1.26342777124445	-4.25464520019038
-4.42098880022526	-0.429205034903218	-5.39033857150137	1.20356503630603
1.38463014556453	-7.10253294889478	-5.31281638129653	-7.27107236617414
1.38435397464405	-7.1660342870646	-5.18713397460664	-6.78403066563544
-7.49203261399875	-6.04582259954302	-7.3569963301948	1.38536698922016
-5.90461241628261	-8.2474039297547	1.38534522627318	-7.42232920615221
1.38459788814079	-7.08265435721045	-5.20839366647065	-8.00899542493811
-4.44933273954196	-8.59678712707801	1.38321523910344	-8.16146905582016
-7.4111844496379	-5.87073940869075	-6.83582030473434	1.38511834202693
-5.90345300557841	-8.26037869327253	1.38520075524486	-6.73488720199244
-3.09452239675752	-4.66928064828202	-7.13609207309207	1.37230558878566
1.3843102293163	-7.08665902043537	-5.19679420643066	-6.69060891126181
1.38398078100966	-7.00178570700949	-5.05009367588096	-6.45543623197154
-7.49783308825112	-6.42999245824977	-7.73624411169612	1.385607989023
-7.89459934586817	-5.70339888313533	-7.98900903033925	1.38525448278769
-6.21722923935354	-5.20287729430317	-7.38375273363786	1.38420254135284
<=PSSM
<<<<

>>>>
REGION	v7
ORDER	2
TYPE	Archaea
REGEX	[AT][A][TCG][TC][CG][ATCG][ATCG][ATCG][ATCG][ACG][ACG][C][ACG][ACG][ATG][TC][AG][ACG][G][AG][TC][TC][TC]
PSSMCUT	12
PSSM=>
1.36168621898172	-2.51213324287555	-6.69163561343796	-6.05564684671796
1.3814555862552	-6.94295004171887	-5.5215643607877	-5.75336597484503
-6.24980286115892	-4.88152700554171	1.37927047534986	-5.12766007508062
-6.80941864909434	1.3784020428159	-8.88886019077418	-3.96887926494605
-6.18080998967197	-5.94442121160774	-1.18766000991673	1.30265937297802
1.29830141281619	-1.73346388887744	-3.76489621137092	-2.08646542744987
-3.98358541233575	-5.42312428797445	1.37397872090409	-4.26388737748991
-0.583870610633817	-3.82626515774721	1.223144466214	-4.38905052044391
-3.05112974360824	0.57075920612084	-3.88491388482872	0.765332321714872
1.37711537701497	-6.94295004171887	-5.36249966615802	-3.9121264483536
1.37715017354228	-7.79024790210607	-4.8998761442099	-4.61219407175812
-7.09710072154612	-5.99848843287801	-6.49096491797581	1.38176735554845
-5.45487298628903	-5.99848843287801	1.37892319283204	-4.77798632660087
1.36662136718214	-7.27942227834008	-2.82973699519238	-4.99703989266355
-0.566709120561276	-1.68471089873824	1.17274160485564	-5.84433775305076
-6.80941864909434	-5.27794227812995	-6.49096491797581	1.38194051872054
-1.33977747996189	-7.27942227834008	1.31536138570834	-6.69163561343796
1.37617541280366	-7.50256582965429	-4.99703989266355	-3.79510998996742
-5.59302332476985	-6.69163561343796	1.38211365191233	-6.49096491797581
1.38142093922184	-6.94295004171887	-4.86350850003903	-6.69163561343796
-7.27942227834008	0.206630339523062	-7.79024790210607	1.01437733050674
-7.27942227834008	-5.06021879428508	-6.69163561343796	1.38263287170973
-7.09710072154612	-2.62355897803647	-5.84433775305076	1.36507294344934
<=PSSM
<<<<

>>>>
REGION	v7
ORDER	100
TYPE	Bacteria
TARGET	OP11
REGEX	[AC][A][G][T][ACG][ATG][CG][ACG][ATC][A][AT][AC][G][A][ATG][C][G][ATC][A][A][TC][C][C]
PSSMCUT	10
PSSM=>
0.780158557549575	-Inf	-Inf	0.59783700075562
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-3.09104245335832	-Inf	1.339774345485	-2.39789527279837
0.241162056816888	-2.39789527279837	0.952008814476234	-Inf
-Inf	-Inf	1.36330484289519	-3.09104245335832
-1.48160454092422	-Inf	1.31567679390594	-3.09104245335832
-3.09104245335832	1.32779815443828	-Inf	-1.70474809223843
1.38629436111989	-Inf	-Inf	-Inf
1.351608803132	-1.99243016469021	-Inf	-Inf
-1.99243016469021	-Inf	-Inf	1.351608803132
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-2.39789527279837	-3.09104245335832	1.351608803132	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-2.39789527279837	-3.09104245335832	-Inf	1.351608803132
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-3.09104245335832	-Inf	1.37486566529627
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
<=PSSM
<<<<

>>>>
REGION	v7
ORDER	200
TYPE	Bacteria
TARGET	Caldiserica
REGEX	[A][A][G][T][C][C][TG][T][ATG][A][A][C][G][A][G][C][G][TC][A][A][C][C][TC]
PSSMCUT	10
PSSM=>
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.28093384546206	-0.965080896043587	-3.96081316959758
-Inf	1.38152108236723	-3.96081316959758	-Inf
1.08261194732167	-3.26766598903763	-0.00956945101615067	-3.96081316959758
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-3.96081316959758	-Inf	1.38152108236723
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.02961941718116	-Inf	0.182321556793955
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.02961941718116	-Inf	0.182321556793955
<=PSSM
<<<<

>>>>
REGION	v7
ORDER	300
TYPE	Bacteria
TARGET	OD1
REGEX	[ATC][A][G][T][CG][ACG][ATCG][ATCG][ATC][A][A][C][G][AG][AG][C][G][AC][A][A][C][C][C]
PSSMCUT	10
PSSM=>
1.16486167420931	-2.9041650800285	-Inf	-0.301475394584117
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	0.945982521681558	0.33451337213588
-2.9041650800285	-Inf	1.32266866523968	-1.80555279136039
-1.65140211153313	-3.59731226058845	1.31534262514761	-3.59731226058845
-1.19941698779008	-3.59731226058845	1.25471800333117	-1.98787434815435
0.651182981460913	0.693147180559945	-Inf	-2.9041650800285
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
1.37942148183213	-Inf	-3.59731226058845	-Inf
0.746493161265238	-Inf	0.636794244008814	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-1.98787434815435	-Inf	-Inf	1.35144762978972
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
<=PSSM
<<<<

>>>>
REGION	v7
ORDER	400
TYPE	Archaea
TARGET	Methanococci
REGEX	[A][AG][G][T][CG][A][G][AG][T][A][A][C][G][A][AG][C][G][A][G][A][C][C][C]
PSSMCUT	10
PSSM=>
1.38629436111989	-Inf	-Inf	-Inf
1.37880368939073	-Inf	-3.51154543883102	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-3.51154543883102	1.37880368939073
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-3.51154543883102	-Inf	1.37880368939073	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-3.51154543883102	-Inf	1.37880368939073	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
<=PSSM
<<<<


>>>>
REGION	v4
ORDER	3
TYPE	Eukaryota
#REGEX	[GTC][GA][CAT][CTAG][CTGA][CAGT][ATC][AG][CGA][GA][TGAC][TAGC][GA][CT][CTG][TC][TAGC][TAGC][CA][CGAT][CAT][ATC][CGAT][CAGT][CTGA]
REGEX	[T][GA][CAT][CTAG][CTGA][CT][AT][AG][GA][GA][GA][TAGC][GA][CT][CTG][TC][AG][TA][CA][GAT][CT][ATC][CGAT][CAGT][CTGA]
PSSMCUT	15
PSSM=>
-5.76997404052688	1.3802197911289	-5.51214493122478	-4.91430793046916
-4.56013611674855	-5.58276249843874	1.38015054944076	-5.60745511102911
-3.74337498022143	-1.8829672294478	-5.60745511102911	1.33841450006169
0.950246114608413	-2.74811546238067	0.258729619652117	-3.14360187043894
-3.49724191068252	-2.84428561070582	1.35828601715168	-4.31960082272247
-5.34509084656162	1.37814045207137	-5.51214493122478	-4.22743036292281
-4.36908087998584	1.37807106625149	-6.07745874027484	-4.88961531787879
1.37308583767868	-5.6327729190134	-3.36940853917263	-5.79982700367656
1.37867225013937	-5.6327729190134	-4.46802082784074	-4.84198726888954
1.37955025389263	-6.03823802712156	-4.21493020015858	-6.03823802712156
1.36907968334786	-5.42513355423515	-3.10807044206045	-5.30735051857877
1.28121928014024	-4.8076981954109	-2.93158380829113	-1.15107499862618
-4.02847640607972	-5.58276249843874	1.37816357960817	-5.74098650365363
-5.89513718348089	-2.06143614482821	-6.00049769913871	1.3504465548936
-5.53513444944948	1.36130118951043	-4.52564994067738	-2.57611441000775
-5.8623473606579	-3.47625163479068	-5.58276249843874	1.37434028066149
-3.99302965708397	-5.28900137991057	1.37675182011336	-5.28900137991057
-4.53416063034529	1.37874159425959	-5.46769316865395	-5.32604265159092
1.37957334884754	-5.89513718348089	-5.6327729190134	-4.51721107203151
-4.31960082272247	-4.41353264255667	1.37510611075427	-5.40451426703242
-5.30735051857877	1.3753844490763	-5.83059866234332	-3.6579798958093
-4.37635363931492	1.22786387468832	-5.53513444944948	-0.58918238980364
-3.20276479509791	-2.7920463916064	1.35182468560642	-3.91183950235395
0.400251811624739	-3.90270701879068	0.886223082996301	-4.46005265819157
1.34627685419305	-2.80561103064054	-3.73565293412752	-3.75115712066348
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	3
TYPE	Eukaryota
REGEX	[GCAT][T][A][GAT][TC][TCG][ATGC][GATC][CATG][CATG][TC][ATC][ATCG][CT][CTA][A][AG][TC][GTAC][GATC][T][ATCG]
PSSMCUT	15
PSSM=>
-4.11677372173871	-4.46227536507932	0.772645684909921	0.582173293382712
-5.74320921054139	1.38057868257702	-6.16306305610165	-5.58498520532649
1.38037147879135	-5.86457006754565	-5.74320921054139	-5.66097111230441
-3.04088968414816	-5.23811426148438	1.36799990037016	-5.68763935938657
-5.93126144204433	1.38002604371244	-6.30282499847681	-5.09386465263983
-6.00272040602647	0.343045900874688	-5.40673697392017	0.942687405589416
-5.13967418867113	0.859882528334191	-4.84420997577729	0.474992423390936
-2.25977373064226	1.10794548217934	-4.16275883498054	-0.179893688626521
1.14212515929139	-1.7980277866355	-0.505703983390106	-2.51410020939316
1.35860796080531	-2.90162761681465	-3.51165989066409	-5.12417000213516
-5.93126144204433	-5.13967418867113	-5.93126144204433	1.37981872537439
-1.53214037401114	-0.963605640608346	-5.60967781791686	1.21759924190371
1.19313352529266	-3.10211314423628	-0.493632009412739	-3.43777104856493
-5.77219674741464	1.36832621027423	-6.12050344168285	-2.86401075324335
1.37864310890484	-5.38653426660265	-5.58498520532649	-4.89183802476655
1.38083187335762	-6.30282499847681	-5.53735715633724	-5.83282136923107
1.37871230108615	-5.89735989036864	-5.30957322546652	-5.77219674741464
-5.74320921054139	-3.35838601931037	-6.00272040602647	1.37232649469793
-3.239434076449	0.571838745505129	0.687891801219676	-1.69965681515939
1.36909494830055	-3.76912818451938	-3.99028957462959	-4.34273021442954
-6.16306305610165	1.38073981139986	-6.35411829286436	-5.77219674741464
-1.64364022418248	-4.34273021442954	1.32732067953492	-5.51436763811254
<=PSSM
<<<<

>>>>
REGION	v6
ORDER	3
TYPE	Eukaryota
REGEX	[GA][AGCT][AGC][AG][GTA][CT][AG][GA][ACG][TC][A][T][G][C][CGA][TC][CT][GA][C][TCA][ATCG]
PSSMCUT	17
PSSM=>
1.37820109414825	-5.02686438936446	-4.25910634501334	-5.62598262027613
1.35927960968563	-4.53595407529941	-3.13044887791384	-3.10333564250528
-2.17721682169486	-5.24649299857122	1.34667169177442	-3.66914340068862
1.3772459953627	-4.93283543971618	-4.39919513818402	-5.46090286991668
1.36037053613258	-4.33371720880451	-2.62896911656609	-5.19519970418367
-5.60066481229184	-4.09658741551556	-5.76318374178961	1.37806138056088
-4.2656637455595	-5.2822110811733	1.37906223020277	-5.85555706192063
-3.23981081117382	-5.21200682250005	1.3731122622323	-6.11149043605783
-4.17755647804923	-4.84689300991546	-4.48552322167252	1.37425834054834
-5.79303670493929	-4.24611914948653	-5.85555706192063	1.3798296453306
1.38233707606484	-5.65195810667939	-5.31925235285365	-6.15405005047662
-5.88834688474362	1.38238345072573	-5.88834688474362	-5.31925235285365
-4.87070365860918	-5.65195810667939	1.3814091309326	-5.79303670493929
-6.03144772838429	-5.09988952437935	-5.2822110811733	1.38152517117549
1.3776654193599	-5.73419620491636	-4.11339453383194	-4.76775568935673
-5.99370740040145	-4.25259166399214	-5.57597219970147	1.37950414719934
-5.99370740040145	-4.27890897230952	-5.60066481229184	1.38006207914612
1.37745572935086	-5.17867040223246	-4.08553757932898	-5.11515699651014
-5.9222484364193	-5.01287814738972	-5.22910125585935	1.38099127452983
-4.72519607493794	-2.40916018421977	-4.95881092611944	1.35828250595172
1.36557161644037	-3.35729907895776	-4.1596455514827	-3.70604795762407
<=PSSM
<<<<

#>>>>
#REGION	v6
#ORDER	3
#TYPE	Eukaryota
##REGEX	[CGAT][TGCA][ACG][TCGA][AG][GA][TCG][AGC][CT][AG][TC][GA][ACGT][TCA][CAT][AG][TACG][GCAT][AGCT][AGCT][TAC]
#REGEX	[CGAT][TGA][G][TC][AG][GA][TCG][G][C][A][T][GA][CGT][TC][CT][AG][TAC][CT][GCT][AGCT][TC]
#PSSMCUT	17
#PSSM=>
#-3.35729907895776	1.36557161644037	-3.70604795762407	-4.1596455514827
#-2.40916018421977	-4.72519607493794	1.35828250595172	-4.95881092611944
#-5.01287814738972	-5.9222484364193	1.38099127452983	-5.22910125585935
#-5.17867040223246	1.37745572935086	-5.11515699651014	-4.08553757932898
#-4.27890897230952	-5.99370740040145	1.38006207914612	-5.60066481229184
#-4.25259166399214	-5.99370740040145	1.37950414719934	-5.57597219970147
#-5.73419620491636	1.3776654193599	-4.76775568935673	-4.11339453383194
#-5.09988952437935	-6.03144772838429	1.38152517117549	-5.2822110811733
#-5.65195810667939	-4.87070365860918	-5.79303670493929	1.3814091309326
#1.38238345072573	-5.88834688474362	-5.31925235285365	-5.88834688474362
#-5.65195810667939	1.38233707606484	-6.15405005047662	-5.31925235285365
#-4.24611914948653	-5.79303670493929	1.3798296453306	-5.85555706192063
#-4.84689300991546	-4.17755647804923	1.37425834054834	-4.48552322167252
#-5.21200682250005	-3.23981081117382	-6.11149043605783	1.3731122622323
#-5.2822110811733	-4.2656637455595	-5.85555706192063	1.37906223020277
#-4.09658741551556	-5.60066481229184	1.37806138056088	-5.76318374178961
#-4.33371720880451	1.36037053613258	-5.19519970418367	-2.62896911656609
#-4.93283543971618	1.3772459953627	-5.46090286991668	-4.39919513818402
#-5.24649299857122	-2.17721682169486	-3.66914340068862	1.34667169177442
#-4.53595407529941	1.35927960968563	-3.10333564250528	-3.13044887791384
#-5.02686438936446	1.37820109414825	-5.62598262027613	-4.25910634501334
#<=PSSM
#<<<<

>>>>
REGION	v7
ORDER	3
TYPE	Eukaryota
#REGEX	[ATCG][GA][ACT][CT][ATCG][TCAG][GATC][CTAG][GCTA][TA][GAC][GATC][AGC][GTCA][ACTG][TCG][TAG][AGT][AG][GA][GACT][AGTC][ATCG]
REGEX	[ATCG][A][ACT][CT][ATCG][TCA][GATC][CTAG][CT][A][A][TC][AG][GCA][AG][TC][AG][AT][AG][GA][CT][AGTC][ATCG]
PSSMCUT	14
PSSM=>
1.26783913444324	-1.93002567048113	-1.2507028541133	-4.56780667573679
1.38227768537677	-5.88510816536973	-5.50211591311362	-5.70278660857577
-4.75370605387863	1.37845501511179	-5.82056964423216	-4.28235924108642
-5.59742609291795	1.3768423188723	-5.67538763438766	-3.78504733648716
-4.21740134481165	-3.48117057811539	-0.469452306404458	1.19998404555774
-3.5433023592224	-3.56927784562566	-5.00963942801583	1.36777228160068
-4.23005974168357	-4.69118569689729	1.37548470431989	-4.49881380424984
0.814063713629529	0.40343169920663	-1.48287049007972	-4.38846574708097
-4.91685769456486	1.37149483796804	-5.29732150046761	-3.2109595159432
1.38190538455341	-5.33506182845046	-5.57273348032758	-5.62274390090224
1.37990188941615	-5.75994502241572	-5.14317082064035	-5.27897236179941
-5.33506182845046	-4.50718205392035	-5.50211591311362	1.38036817684416
-4.023615358127	-5.52510543133832	1.3779177386234	-4.92959672034229
1.35623423992157	-5.27897236179941	-2.33453338263297	-4.44211846057329
1.32706338505536	-4.9425001251782	-1.54303584620288	-5.47964305726156
-5.6487193873055	-3.40856976525224	-5.39448524892126	1.37466456156908
-4.28909327326777	-5.43615794532182	1.36911682754728	-6.45309220297567
1.37910870145902	-4.23005974168357	-5.05219904243462	-5.6487193873055
-4.36632462120376	-5.57273348032758	1.37894531992777	-5.6487193873055
1.38062454228285	-5.75994502241572	-4.49051500143514	-5.82056964423216
-5.45766415054279	-2.03851296526404	-5.00963942801583	1.34890065003929
-4.00819088780137	0.275114142525872	-4.28235924108642	0.972581135938926
-2.52126657025134	0.857182673884878	-2.69326101288945	0.398217211011452
<=PSSM
<<<<




>>>>
REGION	v7
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.major_clade.Excavata
REGEX	[CTAG][A][CTGA][CTA][GC][CTGA][TCGA][TCAG][TC][CA][TAG][CT][TAG][AG][TAG][TC][GAC][GA][TAG][CAG][ACT][GATC][CTAG]
PSSMCUT	13
PSSM=>
-2.88480071284671	-3.80109144472086	1.35508615466605	-3.10794426416092
1.38629436111989	-Inf	-Inf	-Inf
-4.49423862528081	1.36369452920265	-3.80109144472086	-2.88480071284671
-4.49423862528081	1.37505828785296	-Inf	-4.49423862528081
-Inf	-Inf	-2.19165353228676	1.35508615466605
0.731508048432391	-3.10794426416092	-3.80109144472086	0.617749163075734
-3.80109144472086	-3.3956263366127	1.36369452920265	-4.49423862528081
0.948179085240984	-0.938890563791396	-1.7861884241786	-0.163505284994479
-Inf	1.32287253468239	-Inf	-1.49850635172682
1.38069210557122	-Inf	-Inf	-4.49423862528081
1.37222943165249	-4.49423862528081	-4.49423862528081	-Inf
-Inf	-4.49423862528081	-Inf	1.38069210557122
-3.10794426416092	-4.49423862528081	1.37222943165249	-Inf
1.32880727020221	-Inf	-1.54979964611437	-Inf
-1.72164990304103	-4.49423862528081	1.33764385200271	-Inf
-Inf	0.468606004979098	-Inf	0.876399402846853
-4.49423862528081	-Inf	1.38069210557122	-4.49423862528081
1.38069210557122	-Inf	-3.80109144472086	-Inf
-4.49423862528081	-4.49423862528081	1.38069210557122	-Inf
1.37505828785296	-Inf	-4.49423862528081	-4.49423862528081
-4.49423862528081	1.09301003311944	-Inf	-0.0169018108026033
0.206241740511607	0.720697132328176	-3.80109144472086	-0.399894063058709
0.720697132328176	0.509707680664649	-3.80109144472086	-1.49850635172682
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.BD1-5
REGEX	[AT][G][G][G][CT][GAC][T][GATC][AG][A][CG][GATC][AG][AT][GCT][CTA][TCGA][CTA][AC][GAC][GAC][TCA][CTAG][GATC]
PSSMCUT	14
PSSM=>
-2.6479462770325	1.35938690819997	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-2.24248116892434	-Inf	1.35025442463669
-1.5493339883644	-Inf	1.31286689256507	-3.34109345759245
-Inf	1.37740541370264	-Inf	-Inf
1.34103776953177	-3.34109345759245	-3.34109345759245	-2.6479462770325
1.35938690819997	-Inf	-3.34109345759245	-Inf
1.36843674371988	-Inf	-Inf	-Inf
-Inf	-Inf	1.36843674371988	-3.34109345759245
-0.702036127977191	-3.34109345759245	-1.5493339883644	1.1697660489244
-2.6479462770325	-Inf	1.35938690819997	-Inf
0.0601039240697055	1.05335569707999	-Inf	-Inf
-Inf	0.420106658101112	-2.6479462770325	0.863599161798516
-1.5493339883644	0.214254603896964	-Inf	0.921586419448865
-1.26165191591261	-3.34109345759245	1.27402705924881	-2.6479462770325
0.124642445207277	0.570929547835696	-Inf	0.0601039240697055
1.20220132467755	-Inf	-Inf	-0.450721699696285
-2.6479462770325	-Inf	1.35025442463669	-3.34109345759245
-1.95479909647256	-Inf	1.20220132467755	-0.776144100130913
-1.5493339883644	-0.00888894741724604	-Inf	1.02835439487457
-3.34109345759245	0.0262023723940241	1.0656257896718	-3.34109345759245
-1.26165191591261	-0.0452565915881208	0.907401784456909	-1.26165191591261
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.Caldiserica
REGEX	[T][G][G][G][CT][G][T][AG][A][A][G][GC][G][TC][CGA][TC][G][CAT][A][TG][G][CT][TG][ATG]
PSSMCUT	16
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.28621090256291	-Inf	-0.965080896043587
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.28621090256291	-Inf	-0.965080896043587	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.28621090256291	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.33750419695046	-1.65822807660353
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.23214368129263	-Inf	-0.559615787935423
-0.559615787935423	-Inf	0.906721280858004	-0.0487901641694321
-Inf	0.980829253011726	-Inf	0.287682072451781
-Inf	-Inf	1.38629436111989	-Inf
-1.65822807660353	-0.271933715483642	-Inf	1.11436064563625
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-1.65822807660353	1.33750419695046	-Inf
-Inf	-Inf	1.33750419695046	-Inf
-Inf	-0.965080896043587	-Inf	1.28621090256291
-Inf	0.644357016390513	0.739667196194838	-Inf
0.287682072451781	0.826678573184468	-0.965080896043587	-Inf
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.Candidate-division-OD1
REGEX	[TA][TGA][AG][CG][ACT][TG][TC][AG][GAT][AT][GA][CGA][AGT][AGTC][AGTC][TCAG][CTGA][CTGA][AC][AG][CTGA][TCAG][AGTC][TCAG]
PSSMCUT	15
PSSM=>
-3.36729582998647	1.37763629837678	-Inf	-Inf
-3.36729582998647	-2.67414864942653	1.36009198872587	-Inf
-3.36729582998647	-Inf	1.37763629837678	-Inf
-Inf	-Inf	1.36009198872587	-2.67414864942653
-3.36729582998647	-1.42138568093116	-Inf	1.31483539713775
-Inf	-3.36729582998647	1.37763629837678	-Inf
-Inf	1.36890261840802	-Inf	-3.36729582998647
1.36890261840802	-Inf	-3.36729582998647	-Inf
1.35120304130862	-3.36729582998647	-2.26868354131836	-Inf
1.35120304130862	-3.36729582998647	-Inf	-Inf
-2.26868354131836	-Inf	1.36009198872587	-Inf
-0.189241999638528	-Inf	0.524524468124153	0.393904285707088
-1.98100146886658	-2.67414864942653	1.32405205224267	-Inf
-2.67414864942653	1.07535542650384	-3.36729582998647	-0.109199291964992
-1.57553636075842	-0.189241999638528	0.544727175441672	0.18805223150294
-0.109199291964992	0.296265816143172	-2.26868354131836	0.482851771723585
-0.371563556432483	-1.98100146886658	1.02715332468596	-1.06471073699243
0.18805223150294	0.727048732235627	-3.36729582998647	-0.422856850820034
1.33318453580594	-Inf	-Inf	-1.75785791755237
-2.26868354131836	-Inf	1.35120304130862	-Inf
-1.42138568093116	-1.98100146886658	1.2576769832978	-3.36729582998647
-1.06471073699243	0	-1.57553636075842	0.895384047054841
-2.67414864942653	-1.42138568093116	1.28666452017105	-3.36729582998647
-1.06471073699243	-2.26868354131836	1.17599895228353	-1.28785428830664
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.Candidate-division-OP11
REGEX	[T][GT][G][G][GCT][ACGT][CTG][AG][TGA][GA][AG][ATGC][GTA][AGCT][AGTC][CGTA][AGTC][GA][TC][CA][AG][GCA][GCT][TGA][CGTA]
PSSMCUT	15
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-4.00733318523247	1.37716187755662	-Inf
-Inf	-Inf	1.38173854458403	-Inf
-Inf	-Inf	1.38173854458403	-Inf
-Inf	-0.200670695462151	-4.00733318523247	1.15172211398206
-2.21557371600442	-3.31418600467253	1.3445249482436	-4.00733318523247
-Inf	1.37256416830799	-3.31418600467253	-4.00733318523247
1.36330484289519	-Inf	-2.39789527279837	-Inf
1.36330484289519	-2.90872089656436	-3.31418600467253	-Inf
1.37256416830799	-Inf	-4.00733318523247	-Inf
-0.0755075525081452	-Inf	1.1225655296906	-Inf
0	-0.0953101798043249	0.10354067894084	-0.0183491386681965
-4.00733318523247	-4.00733318523247	1.37716187755662	-Inf
-2.06142303617716	1.3253856080329	-4.00733318523247	-2.39789527279837
-0.0560894666510436	-0.369747025506085	-4.00733318523247	-0.178691788743376
-1.6094379124341	-0.962810747509048	0.702197016079863	0.336472236621213
-3.31418600467253	0.269332933783584	-4.00733318523247	0.969400557188103
-4.00733318523247	-Inf	1.38173854458403	-Inf
-Inf	1.36794522245169	-Inf	-2.62103882411258
0.976273436475866	-Inf	-Inf	0.296731907971699
-3.31418600467253	-Inf	1.37716187755662	-Inf
-2.06142303617716	-Inf	1.3253856080329	-3.31418600467253
-Inf	0.0180185055026782	-4.00733318523247	1.08026314999991
-2.90872089656436	-0.675128675057267	1.22910877759748	-Inf
-1.11696142733631	0.458574933422113	0.627395802997165	-1.6094379124341
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.Candidate-division-OP3
REGEX	[GAT][G][G][G][CAT][G][TA][CA][AG][AG][G][GT][AGT][CT][AGC][TACG][GA][TC][A][AGC][G][TC][AGT][GCAT]
PSSMCUT	16
PSSM=>
-2.77258872223978	1.33828514193353	-2.77258872223978	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.37054600415175	-Inf
-2.77258872223978	1.13943428318836	-Inf	-0.287682072451781
-Inf	-Inf	1.38629436111989	-Inf
-2.77258872223978	1.37054600415175	-Inf	-Inf
1.35454566280531	-Inf	-Inf	-2.77258872223978
1.30494872166594	-Inf	-2.77258872223978	-Inf
1.37054600415175	-Inf	-2.77258872223978	-Inf
-Inf	-Inf	1.37054600415175	-Inf
-Inf	-2.77258872223978	1.35454566280531	-Inf
-2.77258872223978	-2.07944154167984	1.33828514193353	-Inf
-Inf	0.0606246218164348	-Inf	1.07755887947028
1.05605267424931	-Inf	-0.133531392624523	-1.38629436111989
0.0606246218164348	-0.575364144903562	0.44628710262842	-0.374693449441411
-0.826678573184468	-Inf	1.27046254559477	-Inf
-Inf	1.37054600415175	-Inf	-2.77258872223978
1.38629436111989	-Inf	-Inf	-Inf
-2.07944154167984	-Inf	1.30494872166594	-2.07944154167984
-Inf	-Inf	1.35454566280531	-Inf
-Inf	0.0606246218164348	-Inf	1.07755887947028
-2.77258872223978	-1.38629436111989	1.30494872166594	-Inf
-2.07944154167984	0.75377180237638	0.485507815781701	-2.77258872223978
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.Candidate-division-SR1
REGEX	[T][AG][G][G][TC][G][T][AT][A][A][GA][ATGC][G][T][CA][CT][G][T][CA][GCT][GCAT][TCG][TGC][GT]
PSSMCUT	16
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
-1.38629436111989	-Inf	1.32175583998232	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-1.38629436111989	-Inf	1.32175583998232
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.32175583998232	-1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-1.38629436111989	-Inf	1.32175583998232	-Inf
-0.693147180559945	0.405465108108164	-0.287682072451781	0.22314355131421
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-0.693147180559945	-Inf	-Inf	1.25276296849537
-Inf	0.22314355131421	-Inf	1.01160091167848
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.17865499634165	-Inf	-Inf	-0.287682072451781
-Inf	-1.38629436111989	1.17865499634165	-1.38629436111989
-1.38629436111989	-1.38629436111989	-1.38629436111989	1.17865499634165
-Inf	-1.38629436111989	-0.693147180559945	1.17865499634165
-Inf	0.22314355131421	0.693147180559945	-0.287682072451781
-Inf	-0.287682072451781	1.17865499634165	-Inf
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.Candidate-division-WS6
REGEX	[TC][G][GT][G][GCT][AG][CT][TA][AGT][GA][CG][AGCT][G][A][TGCA][AG][C][G][TC][A][CGA][AG][CT][TGA][TGCA]
PSSMCUT	15
PSSM=>
-Inf	1.37857231502598	-Inf	-3.48124008933569
-Inf	-Inf	1.37857231502598	-Inf
-Inf	-3.48124008933569	1.37857231502598	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-0.303186258987746	-3.48124008933569	1.17272026082183
-2.78809290877575	-Inf	1.37079017458393	-Inf
-Inf	1.37857231502598	-Inf	-3.48124008933569
1.37857231502598	-3.48124008933569	-Inf	-Inf
0.809219351812699	0.48905182421643	-3.48124008933569	-Inf
1.37857231502598	-Inf	-3.48124008933569	-Inf
-Inf	-Inf	1.37079017458393	-2.78809290877575
1.33904147626935	-2.78809290877575	-2.38262780066758	-3.48124008933569
-Inf	-Inf	1.38629436111989	-Inf
1.37079017458393	-Inf	-Inf	-Inf
-0.436717651612269	0.862565332517992	-2.78809290877575	-1.40179854765586
-2.38262780066758	-Inf	1.33904147626935	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.37857231502598	-Inf	-3.48124008933569
1.38629436111989	-Inf	-Inf	-Inf
-2.78809290877575	-Inf	1.35504181761579	-3.48124008933569
-2.78809290877575	-Inf	1.37079017458393	-Inf
-Inf	-1.28401551199947	-Inf	1.31455045626105
-2.78809290877575	-2.0949457282158	1.33904147626935	-Inf
-1.68948062010764	1.00739628039645	0.0451204352804696	-3.48124008933569
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.NPL-UPA2
REGEX	[CTG][G][G][GCA][TC][G][T][A][CGA][CA][G][CGA][GT][CTG][CGTA][TC][CG][GTCA][AT][CGTA][CG][TC][G][CG]
PSSMCUT	19
PSSM=>
-Inf	1.30291275218084	-1.83258146374831	-1.83258146374831
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-0.7339691750802	-Inf	1.21194097397511	-1.83258146374831
-Inf	0.246860077931526	-Inf	1.00063188030791
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.05779029414785	-Inf	-0.446287102628419	-1.13943428318836
1.30291275218084	-Inf	-Inf	-1.83258146374831
-Inf	-Inf	1.38629436111989	-Inf
-1.83258146374831	-Inf	1.30291275218084	-1.83258146374831
-Inf	-1.13943428318836	1.30291275218084	-Inf
-Inf	0.364643113587909	-0.7339691750802	0.732367893713227
-1.13943428318836	-1.83258146374831	1.21194097397511	-1.83258146374831
-Inf	0.65232518603969	-Inf	0.732367893713227
-Inf	-Inf	1.21194097397511	-0.446287102628419
-0.446287102628419	1.05779029414785	-1.83258146374831	-1.13943428318836
1.34547236659964	-1.83258146374831	-Inf	-Inf
-1.83258146374831	-1.13943428318836	1.11185751541813	-1.83258146374831
-Inf	-Inf	1.30291275218084	-1.83258146374831
-Inf	0.113328685307003	-Inf	1.05779029414785
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.25846098961001	-1.13943428318836
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.SM2F11
REGEX	[T][G][G][G][C][G][T][A][A][A][G][AC][G][T][AGT][AGC][C][GA][A][CTA][TAC][AGC][G][TC][TG][G]
PSSMCUT	15
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-2.81839825827108	-Inf	-Inf	1.37125648375535
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
0.548897571715399	-0.0458095360312942	-2.12525107771113	-Inf
-0.333491608483075	-Inf	-0.73895671659124	1.03174934343898
-Inf	-Inf	-Inf	1.38629436111989
-1.71978596960297	-Inf	1.3404848250886	-Inf
0.942801857422487	-Inf	-Inf	-Inf
0.226124179452348	0.919271360012293	-Inf	-1.43210389715118
0.870481195842861	0.126040720895365	-Inf	-0.73895671659124
-1.02663878904302	-Inf	1.05280275263682	-0.253448900809539
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.24204475227534	-Inf	-0.621173680934856
-Inf	-0.179340928655817	1.15189365528105	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.TA06
REGEX	[T][G][TGA][G][TC][TGC][GT][TAG][A][A][G][GA][AG][GCT][TCGA][TC][G][CT][A][TAGC][AG][TGC][GT][GAT]
PSSMCUT	14
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-2.14006616349627	-2.14006616349627	1.32566973930346	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.03798766685167	-Inf	0.162518929497775
-Inf	-2.14006616349627	0.34484048629173	0.904456274227152
-Inf	1.35644139797021	-2.14006616349627	-Inf
1.29392104098888	-2.14006616349627	-1.44691898293633	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.35644139797021	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-2.14006616349627	-Inf	1.35644139797021	-Inf
-1.44691898293633	-Inf	1.32566973930346	-Inf
-Inf	-1.44691898293633	-1.04145387482816	1.2272296664902
-1.44691898293633	0.950976289862045	-0.0606246218164349	-2.14006616349627
-Inf	-0.348306694268216	-Inf	1.19213834667893
-Inf	-Inf	1.35644139797021	-Inf
-Inf	0.162518929497775	-Inf	1.03798766685167
1.38629436111989	-Inf	-Inf	-Inf
-2.14006616349627	0.80437281567017	0.34484048629173	-2.14006616349627
-2.14006616349627	-Inf	1.29392104098888	-Inf
-Inf	-2.14006616349627	-2.14006616349627	1.32566973930346
-Inf	-2.14006616349627	1.32566973930346	-Inf
-2.14006616349627	-1.44691898293633	1.29392104098888	-Inf
<=PSSM
<<<<

#>>>>
#REGION	v4
#ORDER	500
#TYPE	Bacteria
#TARGET	Bacteria.phylum.Tenericutes
#REGEX	[CATG][GACT][TCAG][AG][TC][GCA][TG][TCA][AT][GA][GA][GTAC][CAG][AT][GTAC][TCG][GACT][ATC][GA][GAC][CATG][CATG][ATG][ACTG]
#PSSMCUT	13
#PSSM=>
#-3.25809653802148	1.35702397881978	-3.95124371858143	-3.25809653802148
#-3.95124371858143	-2.85263142991332	1.35702397881978	-3.95124371858143
#-3.95124371858143	-3.95124371858143	1.36687627526279	-3.95124371858143
#-3.25809653802148	-Inf	1.37176626055698	-Inf
#-Inf	-1.00680473941499	-Inf	1.27986489827316
#-3.95124371858143	-Inf	1.37663245020815	-3.95124371858143
#-Inf	1.38147507468394	-3.95124371858143	-Inf
#1.37663245020815	-3.95124371858143	-Inf	-3.95124371858143
#0.767255152713667	0.602633173019113	-Inf	-Inf
#1.38147507468394	-Inf	-3.95124371858143	-Inf
#-2.15948424935337	-Inf	1.35702397881978	-Inf
#-0.815749502652278	-3.95124371858143	0.916290731874155	0.0190481949706944
#-2.34180580614733	-Inf	1.34707364796661	-2.85263142991332
#-0.815749502652278	1.2691121064969	-Inf	-Inf
#-3.95124371858143	-2.34180580614733	1.17865499634165	-0.485507815781701
#-Inf	-1.55334844578306	-2.85263142991332	1.3166144404819
#-1.00680473941499	-3.25809653802148	1.2691121064969	-3.95124371858143
#-3.25809653802148	1.20204787591635	-Inf	-0.454736157114947
#1.36687627526279	-Inf	-2.56494935746154	-Inf
#-2.85263142991332	-Inf	1.35702397881978	-3.25809653802148
#-1.75401914124521	-3.25809653802148	1.31144647032346	-3.95124371858143
#-1.17865499634165	0.159630145591884	-3.95124371858143	0.90078654533819
#-3.95124371858143	-0.517256514096281	1.21354225534209	-Inf
#-3.25809653802148	-0.655406852577098	1.21924027645672	-3.25809653802148
#<=PSSM
#<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.major_clade.Excavata
REGEX	[TC][ATG][TAC][CTAG][TAGC][GTC][TC][CTAG][TAC][AG][GA][CGA][ATGC][TC][CAT][TC][TG][GTA][ATC][AG][ATC][GTAC][CGTA][CAG][TAC]
PSSMCUT	13
PSSM=>
-Inf	1.36330484289519	-Inf	-2.62103882411258
-1.36827585561721	-2.21557371600442	1.29098418131557	-Inf
-2.21557371600442	-0.510825623765991	-Inf	1.19116384603335
0.0357180826020792	0.905321700503581	-0.749236647210989	-4.00733318523247
-2.39789527279837	-1.81010860789625	1.27078147399805	-1.81010860789625
-Inf	1.36330484289519	-3.31418600467253	-2.90872089656436
-Inf	1.35864282978938	-Inf	-2.90872089656436
1.34925308943954	-4.00733318523247	-2.62103882411258	-4.00733318523247
1.35864282978938	-3.31418600467253	-Inf	-2.62103882411258
1.37256416830799	-Inf	-4.00733318523247	-Inf
1.27078147399805	-Inf	-0.871838969303321	-Inf
-1.92789164355263	-Inf	-1.44238382777093	1.28597163949202
0.912647740595654	-4.00733318523247	0.349375641457121	-2.90872089656436
-Inf	-1.06289420606603	-Inf	1.2959717228266
-2.39789527279837	1.01654733561381	-Inf	0.10354067894084
-Inf	0.969400557188103	-Inf	0.310154928303839
-Inf	-2.90872089656436	1.37256416830799	-Inf
-4.00733318523247	1.35395898047695	-2.39789527279837	-Inf
1.35395898047695	-2.90872089656436	-Inf	-2.62103882411258
-1.92789164355263	-Inf	1.34925308943954	-Inf
-2.90872089656436	1.35395898047695	-Inf	-2.90872089656436
-0.829279354884525	-0.711496319228142	-3.31418600467253	1.11066062718428
-1.52242653544447	0.969400557188103	0	-2.21557371600442
-0.200670695462151	-Inf	0.96248011434353	-4.00733318523247
0.135801541159062	-2.21557371600442	-Inf	0.78845736036427
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.class.Dehalococcoidia
REGEX	[AG][T][AG][AG][T][ACG][C][CA][ATC][AG][TC][TAC][CGTA][TGC][TACG][GA][ATC][CT][TAG][GAT][T][G]
PSSMCUT	15
PSSM=>
-2.484906649788	-Inf	1.33646198737201	-Inf
-Inf	1.3793256918038	-Inf	-Inf
1.3793256918038	-Inf	-3.58351893845611	-Inf
-3.58351893845611	-Inf	1.3793256918038	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-2.19722457733622	-Inf	-1.97408102602201	1.3143208614948
-Inf	-Inf	-Inf	1.37230811914515
1.3793256918038	-Inf	-Inf	-3.58351893845611
-3.58351893845611	-3.58351893845611	-Inf	1.37230811914515
-3.58351893845611	-Inf	1.3793256918038	-Inf
-Inf	-2.484906649788	-Inf	1.36524095192206
-1.97408102602201	1.01160091167848	-Inf	0.0273989741881143
-1.97408102602201	-2.484906649788	1.28401551199947	-1.79175946922805
-Inf	1.30683018976564	-3.58351893845611	-1.50407739677627
1.13497993283898	-1.28093384546206	-2.89037175789616	-0.944461608840851
1.37230811914515	-Inf	-3.58351893845611	-Inf
0.590868331439527	0.679160938585205	-Inf	-1.79175946922805
-Inf	-2.89037175789616	-Inf	1.37230811914515
-2.484906649788	-0.810930216216329	1.24479479884619	-Inf
1.29167838474504	-2.19722457733622	-1.38629436111989	-Inf
-Inf	1.3793256918038	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.Candidate-division-KB1
REGEX	[G][T][A][GA][T][C][C][AT][GAC][AG][CT][TC][TC][TC][A][A][A][C][GT][A][T][G]
PSSMCUT	16
PSSM=>
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-1.94591014905531	-Inf	1.34992671694902	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-1.25276296849537	1.31218638896617	-Inf	-Inf
-1.94591014905531	-Inf	1.27296567581289	-1.25276296849537
-1.25276296849537	-Inf	1.31218638896617	-Inf
-Inf	-1.94591014905531	-Inf	1.34992671694902
-Inf	1.31218638896617	-Inf	-1.25276296849537
-Inf	1.31218638896617	-Inf	-1.25276296849537
-Inf	-1.25276296849537	-Inf	1.31218638896617
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.34992671694902	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-1.94591014905531	1.34992671694902	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.Candidate-division-OD1
REGEX	[GAT][CT][A][TAGC][TC][TC][TC][TAGC][GCTA][AG][TCG][CT][GCTA][ATC][TAC][CTA][CGA][CGT][GCTA][ATC][TC][CG]
PSSMCUT	15
PSSM=>
-3.05635689537043	-1.95774460670232	1.32566973930346	-Inf
-Inf	1.37445990347289	-Inf	-3.05635689537043
1.37445990347289	-Inf	-Inf	-Inf
-1.67006253425054	0.772284501118669	0.470003629245736	-3.05635689537043
-Inf	1.35036235189383	-Inf	-2.36320971481048
-Inf	-3.05635689537043	-Inf	1.37445990347289
-Inf	-1.67006253425054	-Inf	1.33809225930201
1.133297846656	-0.283768173130645	-2.36320971481048	-3.05635689537043
-0.97691535369059	-1.44691898293633	-0.491407537908889	1.02118054853529
-1.67006253425054	-Inf	1.33809225930201	-Inf
-Inf	-3.05635689537043	-1.11044674631511	1.28744852648326
-Inf	-0.348306694268216	-Inf	1.19213834667893
-3.05635689537043	0.12169693497752	0.162518929497775	0.498991166118988
-3.05635689537043	1.36248371242617	-Inf	-3.05635689537043
1.27437644491591	-3.05635689537043	-Inf	-0.97691535369059
1.32566973930346	-3.05635689537043	-Inf	-3.05635689537043
1.35036235189383	-Inf	-3.05635689537043	-3.05635689537043
-Inf	-1.44691898293633	-3.05635689537043	1.3130909570966
-1.67006253425054	-1.67006253425054	1.23410254577797	-1.67006253425054
1.22030922364563	-0.571450245582426	-Inf	-3.05635689537043
-Inf	1.37445990347289	-Inf	-3.05635689537043
-Inf	-Inf	1.28744852648326	-0.97691535369059
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.Candidate-division-OP11
REGEX	[GA][AT][A][GTA][TC][ACT][TCA][ACTG][CGTA][CGA][TC][TC][TGC][GT][GTA][AT][AC][GCT][TGA][GCTA][GTC][ATGC]
PSSMCUT	13
PSSM=>
-4.00277736869661	-Inf	1.38171769409248	-Inf
-4.00277736869661	1.38171769409248	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-3.30963018813666	-2.9041650800285	1.36319864632524	-Inf
-Inf	1.37711998484385	-Inf	-4.00277736869661
-4.00277736869661	-4.00277736869661	-Inf	1.37711998484385
-4.00277736869661	-2.61648300757672	-Inf	1.36319864632524
-0.537041465896884	1.17337236387722	-2.21101789946856	-2.9041650800285
1.30549032870459	-2.61648300757672	-1.80555279136039	-2.9041650800285
-1.36372003908135	-Inf	1.31042861034518	-3.30963018813666
-Inf	-4.00277736869661	-Inf	1.38171769409248
-Inf	-0.447429307207197	-Inf	1.21215838891238
-Inf	-1.43782801123507	0.864757081758972	0.327955971589721
-Inf	1.38171769409248	-4.00277736869661	-Inf
1.37711998484385	-4.00277736869661	-4.00277736869661	-Inf
1.38171769409248	-4.00277736869661	-Inf	-Inf
1.37250103898755	-Inf	-Inf	-3.30963018813666
-Inf	-2.0568672196413	-4.00277736869661	1.34433016202086
-0.391859456052386	-1.00704509514262	1.07862699628785	-Inf
1.13888618780605	-0.601579987034455	-4.00277736869661	-1.23018864645683
-Inf	1.37250103898755	-4.00277736869661	-4.00277736869661
-3.30963018813666	-2.9041650800285	1.0534684366517	0.022574322038539
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.Candidate-division-SR1
REGEX	[TG][CT][A][GA][T][TC][CT][AG][CGAT][GA][CT][CGAT][TG][T][A][TA][A][CT][TG][TA][T][GC]
PSSMCUT	16
PSSM=>
-Inf	-2.19722457733622	1.35812348415319	-Inf
-Inf	1.35812348415319	-Inf	-2.19722457733622
1.38629436111989	-Inf	-Inf	-Inf
-2.19722457733622	-Inf	1.35812348415319	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-0.251314428280906	-Inf	1.17007125265025
-Inf	-1.09861228866811	-Inf	1.29928298413026
1.26851132546351	-Inf	-0.810930216216329	-Inf
1.23676262714893	-1.09861228866811	-2.19722457733622	-2.19722457733622
0.510825623765991	-Inf	0.847297860387204	-Inf
-Inf	-2.19722457733622	-Inf	1.35812348415319
-2.19722457733622	0.287682072451781	-2.19722457733622	0.893817876022097
-Inf	0.105360515657826	1.06087196068526	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.35812348415319	-2.19722457733622	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.35812348415319	-Inf	-2.19722457733622
-Inf	1.26851132546351	-0.810930216216329	-Inf
1.29928298413026	-1.09861228866811	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.17007125265025	-0.251314428280906
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.SM2F11
REGEX	[G][T][A][T][T][C][C][A][C][G][C][CT][GC][T][A][A][A][C][G][TA][T][G]
PSSMCUT	16
PSSM=>
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.32175583998232
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-1.38629436111989	-Inf	1.32175583998232
-Inf	-Inf	-1.38629436111989	1.32175583998232
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
1.25276296849537	-0.693147180559945	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.kingdom.Discoba
REGEX	[GA][TA][GA][AG][ACT][C][TC][ATCG][ATGC][AGCT][TGCA][CA][ACGT][TGCA][CT][ACG][AG][A][CT][TGCA][CGA][GTA][GA]
PSSMCUT	14
PSSM=>
-4.42484663185681	-Inf	1.38028833705968	-Inf
-4.42484663185681	1.38028833705968	-Inf	-Inf
1.38028833705968	-Inf	-4.42484663185681	-Inf
-3.3262343431887	-Inf	1.37424602260372	-Inf
-4.42484663185681	1.37727174352025	-Inf	-4.42484663185681
-Inf	-Inf	-Inf	1.38329585812363
-Inf	-4.42484663185681	-Inf	1.37424602260372
1.22060026578643	-2.81540871942271	-0.687177013573442	-3.73169945129686
-2.4789364828015	-2.22762205452059	-1.05755080187034	1.23811384827914
-0.0181273845925567	-0.533026333746183	-0.92833907039033	-0.787260472130424
1.15864967692489	-2.34540509017697	-0.36440362131039	-4.42484663185681
-4.42484663185681	-Inf	-Inf	1.38028833705968
-3.73169945129686	1.00887537169743	-4.42484663185681	0.19027388498445
0.0860128746600402	-3.3262343431887	1.04742404181466	-4.42484663185681
-Inf	0.779160055219985	-Inf	0.592433204958115
1.33720475092337	-Inf	-2.81540871942271	-2.22762205452059
1.38028833705968	-Inf	-4.42484663185681	-Inf
1.38329585812363	-Inf	-Inf	-Inf
-Inf	-2.63308716262875	-Inf	1.36511353904044
-1.65225790961703	-0.435862585292535	0.773650399409016	-0.0181273845925567
0.995688367415476	-Inf	0.160120846813762	-2.34540509017697
-4.42484663185681	1.37727174352025	-4.42484663185681	-Inf
-4.42484663185681	-Inf	1.38028833705968	-Inf
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.phylum.Euglenozoa
REGEX	[G][AT][AG][AG][TA][C][CT][GCAT][AGCT][TAGC][AGCT][C][TCA][GCAT][TC][GCA][AG][A][CT][CGAT][GCA][TGA][AG]
PSSMCUT	15
PSSM=>
-Inf	-Inf	1.38327776758046	-Inf
-4.4188406077966	1.38025204666393	-Inf	-Inf
1.38025204666393	-Inf	-4.4188406077966	-Inf
-3.32022831912849	-Inf	1.37417300058755	-Inf
-4.4188406077966	1.38025204666393	-Inf	-Inf
-Inf	-Inf	-Inf	1.38327776758046
-Inf	-4.4188406077966	-Inf	1.37417300058755
1.22660628984664	-3.03254624667671	-0.70526854109229	-3.72569342723665
-2.8094026953625	-2.22161603046038	-1.05154477781012	1.24411987233935
-0.0121213605323448	-0.527020309685971	-0.922333046330118	-0.781254448070212
1.16088921818962	-2.33939906611676	-0.375789339962048	-4.4188406077966
-Inf	-Inf	-Inf	1.38327776758046
-3.72569342723665	1.01488139575764	-Inf	0.186329578191494
0.0809690625336671	-3.32022831912849	1.04921953333853	-4.4188406077966
-Inf	0.774116243093612	-Inf	0.598439229018326
1.33690160579031	-Inf	-2.8094026953625	-2.22161603046038
1.38025204666393	-Inf	-4.4188406077966	-Inf
1.38327776758046	-Inf	-Inf	-Inf
-Inf	-2.62708113856854	-Inf	1.36498457453314
-1.64625188555682	-0.429856561232324	0.768545198044157	-0.0121213605323448
0.992805444058442	-Inf	0.166126870873974	-2.33939906611676
-4.4188406077966	1.37721714296877	-4.4188406077966	-Inf
-4.4188406077966	-Inf	1.38025204666393	-Inf
<=PSSM
<<<<

>>>>
REGION	v6
ORDER	500
TYPE	Archaea
TARGET	Archaea.phylum.Ancient-Archaeal-Group-AAG-
REGEX	[T][G][A][G][A][C][G][G][C][C][A][T][G][C][A][C][T][A][C][C][T]
PSSMCUT	20
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.38629436111989	-Inf	-Inf
<=PSSM
<<<<

>>>>
REGION	v6
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.Armatimonadetes
REGEX	[G][AT][TC][G][AG][CTA][ATG][ACG][TAC][CT][CA][GT][G][CT][GTA][ATC][TC][ATC][GATC][ACG][GT]
PSSMCUT	13
PSSM=>
-Inf	-Inf	1.37927678846124	-Inf
1.37220962123815	-2.88340308858007	-Inf	-Inf
-Inf	-3.57655026914002	-Inf	1.37927678846124
-Inf	-Inf	1.37927678846124	-Inf
1.37927678846124	-Inf	-3.57655026914002	-Inf
-3.57655026914002	-3.57655026914002	-Inf	1.37220962123815
1.36509215346929	-3.57655026914002	-3.57655026914002	-Inf
-2.19025590802013	-Inf	1.35070341601719	-3.57655026914002
-3.57655026914002	-3.57655026914002	-Inf	1.37220962123815
-Inf	-2.88340308858007	-Inf	1.37220962123815
1.37927678846124	-Inf	-Inf	-3.57655026914002
-Inf	1.37220962123815	-2.88340308858007	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-3.57655026914002	-Inf	1.37927678846124
1.36509215346929	-3.57655026914002	-3.57655026914002	-Inf
1.34343065668811	-3.57655026914002	-Inf	-2.19025590802013
-Inf	-3.57655026914002	-Inf	1.37927678846124
1.25176346816228	-3.57655026914002	-Inf	-0.743336925083801
0.727514824064153	-3.57655026914002	0.374693449441411	-0.803961546900235
-2.19025590802013	-Inf	1.21094147364203	-0.632111289973576
-Inf	1.36509215346929	-2.88340308858007	-Inf
<=PSSM
<<<<

>>>>
REGION	v6
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.Candidate-division-KB1
REGEX	[G][A][C][G][A][C][A][G][C][TC][A][T][G][CT][A][GA][TC][A][C][C][T]
PSSMCUT	16
PSSM=>
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-1.83258146374831	-Inf	1.34547236659964
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-1.13943428318836	-Inf	1.30291275218084
1.38629436111989	-Inf	-Inf	-Inf
1.30291275218084	-Inf	-1.13943428318836	-Inf
-Inf	1.30291275218084	-Inf	-1.13943428318836
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.38629436111989	-Inf	-Inf
<=PSSM
<<<<

>>>>
REGION	v6
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.Candidate-division-OP11
REGEX	[GAT][TGA][TCAG][CGA][AG][CT][GAT][GAC][C][C][A][T][AG][TC][A][CTAG][CT][AT][TCAG][TCA][GT]
PSSMCUT	14
PSSM=>
-3.96081316959758	-2.01490302054226	1.34745452780363	-Inf
1.37672491010374	-3.96081316959758	-3.96081316959758	-Inf
-3.26766598903763	-2.57451880847769	-2.86220088092947	1.3424917384615
-3.96081316959758	-Inf	1.37672491010374	-3.96081316959758
1.37190562366779	-Inf	-2.86220088092947	-Inf
-Inf	-1.47590651980958	-Inf	1.32745386109696
1.36219680954083	-3.96081316959758	-2.57451880847769	-Inf
-0.349895256953354	-Inf	1.18668130721588	-3.96081316959758
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-3.96081316959758	-Inf	1.38152108236723	-Inf
-Inf	-3.96081316959758	-Inf	1.38152108236723
1.38629436111989	-Inf	-Inf	-Inf
0.315852949418477	-2.35137525716348	0.891217094322039	-2.35137525716348
-Inf	-1.25276296849537	-Inf	1.31218638896617
1.35239280944421	-2.01490302054226	-Inf	-Inf
-2.35137525716348	-2.57451880847769	1.19824212961695	-0.741937344729377
-3.96081316959758	-3.96081316959758	-Inf	1.37672491010374
-Inf	1.36219680954083	-2.35137525716348	-Inf
<=PSSM
<<<<

>>>>
REGION	v6
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.Candidate-division-WS6
REGEX	[GT][A][C][GT][AG][CG][GA][G][TAC][C][AG][T][G][C][A][ATG][CAT][A][TC][C][T]
PSSMCUT	21
PSSM=>
-Inf	-1.25276296849537	1.31218638896617	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-1.25276296849537	1.31218638896617	-Inf
1.145132304303	-Inf	-0.154150679827258	-Inf
-Inf	-Inf	-1.25276296849537	1.31218638896617
0.826678573184468	-Inf	0.356674943938732	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-1.25276296849537	-1.25276296849537	-Inf	1.23214368129263
-Inf	-Inf	-Inf	1.38629436111989
1.145132304303	-Inf	-0.154150679827258	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.31218638896617	-Inf	-Inf	-Inf
0.133531392624523	-0.559615787935423	0.693147180559945	-Inf
-1.25276296849537	0.133531392624523	-Inf	0.826678573184468
1.31218638896617	-Inf	-Inf	-Inf
-Inf	-1.25276296849537	-Inf	1.145132304303
-Inf	-Inf	-Inf	1.31218638896617
-Inf	1.31218638896617	-Inf	-Inf
<=PSSM
<<<<

>>>>
REGION	v6
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.SM2F11
REGEX	[G][A][C][G][GA][C][GTA][A][GC][C][G][T][G][C][A][GT][TC][GA][CT][C][CT]
PSSMCUT	16
PSSM=>
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
1.30625165344635	-Inf	-1.17865499634165	-Inf
-Inf	-Inf	-Inf	1.38629436111989
0.430782916092454	-1.87180217690159	0.836248024200619	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-1.87180217690159	1.34707364796661
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	0.836248024200619	0.526093095896779	-Inf
-Inf	0.430782916092454	-Inf	0.90078654533819
1.17272026082183	-Inf	-0.262364264467491	-Inf
-Inf	0.836248024200619	-Inf	0.526093095896779
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.34707364796661	-Inf	-1.87180217690159
<=PSSM
<<<<

#>>>>
#REGION	v6
#ORDER	500
#TYPE	Eukaryota
#TARGET	Eukaryota.major_clade.Excavata
#REGEX	[TCGA][AGCT][ACG][ACTG][GA][TCA][AG][ATCG][GC][TCA][A][CTA][GA][CT][AGCT][GTC][TCA][CTGA][CG][TCGA][AGTC]
#PSSMCUT	16
#PSSM=>
#1.17949994780721	-2.7191000372888	-0.485507815781701	-3.12456514539696
#0.032435275753154	-3.12456514539696	0.325422400434628	0.416394178640355
#0.242730684589515	-Inf	0.114113306767421	0.444967551084411
#1.35277166908125	-3.12456514539696	-3.12456514539696	-3.8177123259569
#0.714887167196351	-Inf	0.659624488521302	-Inf
#-2.7191000372888	-2.2082744135228	-Inf	1.33557926854087
#-3.12456514539696	-Inf	1.36967347988385	-Inf
#-1.51512723296286	-3.8177123259569	1.30028148645985	-3.8177123259569
#-Inf	-Inf	-3.12456514539696	1.36407122433518
#-3.8177123259569	-3.12456514539696	-Inf	1.36407122433518
#1.38078470530892	-Inf	-Inf	-Inf
#-3.12456514539696	1.35843740661692	-Inf	-3.12456514539696
#-3.8177123259569	-Inf	1.36967347988385	-Inf
#-Inf	-3.8177123259569	-Inf	1.36407122433518
#1.35843740661692	-3.8177123259569	-3.8177123259569	-3.8177123259569
#-Inf	-2.7191000372888	-3.12456514539696	1.35277166908125
#-3.8177123259569	-1.10966212485469	-Inf	1.28823314794368
#1.35277166908125	-3.8177123259569	-3.12456514539696	-3.8177123259569
#-Inf	-Inf	-3.8177123259569	1.37524452493331
#-3.8177123259569	-1.73827078427707	-3.8177123259569	1.32395123054576
#-0.726669872598589	-1.87180217690159	0.325422400434628	0.670924043775235
#<=PSSM
#<<<<

>>>>
REGION	v7
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.BD1-5
REGEX	[GCA][AG][TG][T][C][CA][GTA][ACT][GTCA][TA][TA][GTC][G][TA][AG][CT][GA][CGA][A][TA][C][C][CT]
PSSMCUT	15
PSSM=>
1.17272026082183	-Inf	-0.955511445027436	-0.955511445027436
1.36687627526279	-Inf	-2.56494935746154	-Inf
-Inf	-1.87180217690159	1.34707364796661	-Inf
-Inf	1.36687627526279	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
0.836248024200619	-Inf	-Inf	0.479573080261886
-0.955511445027436	-2.56494935746154	1.24171313230878	-Inf
-1.87180217690159	0.613104472886409	-Inf	0.693147180559945
-0.955511445027436	-0.167054084663166	0.961411167154625	-1.87180217690159
1.36687627526279	-2.56494935746154	-Inf	-Inf
1.34707364796661	-1.87180217690159	-Inf	-Inf
-Inf	-1.46633706879343	-2.56494935746154	1.30625165344635
-Inf	-Inf	1.38629436111989	-Inf
1.36687627526279	-2.56494935746154	-Inf	-Inf
-2.56494935746154	-Inf	1.36687627526279	-Inf
-Inf	-1.87180217690159	-Inf	1.34707364796661
-1.87180217690159	-Inf	1.34707364796661	-Inf
-1.17865499634165	-Inf	-2.56494935746154	1.28519824424852
1.36687627526279	-Inf	-Inf	-Inf
1.36687627526279	-2.56494935746154	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-2.56494935746154	-Inf	1.36687627526279
<=PSSM
<<<<

>>>>
REGION	v7
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.Candidate-division-OD1
REGEX	[ATC][GA][AGTC][TGA][AGTC][AGTC][TCAG][GATC][AGCT][GA][TGA][TCA][GAC][AGT][AGC][GAC][GA][CTGA][A][CA][TC][C][CTA]
PSSMCUT	12
PSSM=>
1.25661653781136	-2.22462355152433	-Inf	-0.971860583028966
1.37951467413451	-Inf	-3.61091791264422	-Inf
0.719815427642107	-0.838329190404443	0.320907720080101	-2.00148000021012
-3.61091791264422	1.37268870906411	-3.61091791264422	-Inf
-2.51230562397611	-1.81915844341617	1.08042996958492	-0.209720530982069
-2.51230562397611	-3.61091791264422	1.12528053575027	-0.24362208265775
-3.61091791264422	-1.53147637096439	1.27943121557753	-1.81915844341617
-1.30833281965018	-1.21302263984585	1.19310313208903	-2.00148000021012
-0.114410351177744	0.984201937490366	-2.51230562397611	-1.04596855518269
1.36581582977635	-Inf	-2.51230562397611	-Inf
1.32355602048647	-1.66500776358891	-2.91777073208428	-Inf
-3.61091791264422	-3.61091791264422	-Inf	1.37268870906411
0.260283098263667	-Inf	0.532216813747308	0
0.563469357251413	0.783531242028214	-2.91777073208428	-Inf
-0.519875459285909	-Inf	1.20936365296081	-2.91777073208428
-3.61091791264422	-Inf	-3.61091791264422	1.37268870906411
-2.22462355152433	-Inf	1.35889538693178	-Inf
-1.12601126285622	-2.91777073208428	-2.91777073208428	1.27188400994215
1.37951467413451	-Inf	-Inf	-Inf
1.37268870906411	-Inf	-Inf	-2.91777073208428
-Inf	-3.61091791264422	-Inf	1.37951467413451
-Inf	-Inf	-Inf	1.38629436111989
-3.61091791264422	-0.902867711542014	-Inf	1.27188400994215
<=PSSM
<<<<

>>>>
REGION	v7
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.Candidate-division-OP11
REGEX	[CA][A][G][T][GTA][CGAT][AGC][CGTA][CGTA][AT][A][TC][ATGC][A][GA][TC][GC][ATC][AC][AC][C][CT][CTA]
PSSMCUT	16
PSSM=>
1.31960298662122	-Inf	-Inf	-2.04769284336526
1.37003384024811	-Inf	-Inf	-Inf
-Inf	-Inf	1.37003384024811	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-0.0327898228229908	-0.949080554697146	0.948039430188735	-Inf
-2.7408400239252	-2.04769284336526	1.15098027418543	-0.794929874869888
-0.438254930931155	-Inf	1.08780137256389	-0.949080554697146
0.25489224962879	-0.34294475112683	0.660357357736954	-2.7408400239252
-0.0327898228229908	0.25489224962879	-0.543615446588982	0.149531733970964
1.37003384024811	-2.7408400239252	-Inf	-Inf
1.37003384024811	-Inf	-Inf	-Inf
-Inf	-2.04769284336526	-Inf	1.3535045382969
-0.255933374137201	-2.7408400239252	1.13036098698269	-2.7408400239252
1.38629436111989	-Inf	-Inf	-Inf
0.0317486983145803	-Inf	1.08780137256389	-Inf
-Inf	-0.255933374137201	-Inf	1.17118298150295
-Inf	-Inf	1.37003384024811	-2.7408400239252
-2.04769284336526	-2.04769284336526	-Inf	1.31960298662122
1.37003384024811	-Inf	-Inf	-2.7408400239252
1.33669741998052	-Inf	-Inf	-2.7408400239252
-Inf	-Inf	-Inf	1.37003384024811
-Inf	-2.7408400239252	-Inf	1.37003384024811
-2.7408400239252	-1.35454566280531	-Inf	1.30221124390935
<=PSSM
<<<<

>>>>
REGION	v7
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.Candidate-division-SR1
REGEX	[AT][A][TG][T][C][CT][TAG][AG][GAT][AG][A][C][GA][GA][AG][C][G][C][ATC][A][C][C][AC]
PSSMCUT	16
PSSM=>
1.27506872600967	-0.864997437486605	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	0.92676203174145	0.387765531008763	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.00680473941499	-Inf	0.233614851181505
0.387765531008763	-1.55814461804655	0.839750654751821	-Inf
0.233614851181505	-Inf	1.00680473941499	-Inf
0.233614851181505	0.63907995928967	-0.171850256926659	-Inf
1.33222713984961	-Inf	-1.55814461804655	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-0.864997437486605	-Inf	1.27506872600967	-Inf
1.14990558305566	-Inf	-0.171850256926659	-Inf
-0.45953232937844	-Inf	1.21444410419323	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.27506872600967	-1.55814461804655	-Inf	-1.55814461804655
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-1.55814461804655	-Inf	-Inf	1.33222713984961
<=PSSM
<<<<

>>>>
REGION	v7
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.TM6
REGEX	[GA][A][G][CT][C][C][TC][TCGA][TC][AT][A][CT][G][GA][G][TC][G][AC][A][A][C][CT][C]
PSSMCUT	15
PSSM=>
1.34782808029209	-Inf	-1.89085037187229	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.37363596424797	-Inf	-2.9894626605404
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.37998519192663	-Inf	-3.68260984110034
-2.58399755243223	0.10157979281792	-2.9894626605404	1.01787052469208
-Inf	1.3672461661492	-Inf	-2.58399755243223
1.37998519192663	-3.68260984110034	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-3.68260984110034	-Inf	1.37998519192663
-Inf	-Inf	1.38629436111989	-Inf
1.37998519192663	-Inf	-3.68260984110034	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-3.68260984110034	-Inf	1.3672461661492
-Inf	-Inf	1.38629436111989	-Inf
-3.68260984110034	-Inf	-Inf	1.37998519192663
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.34782808029209	-Inf	-2.07317192866624
-Inf	-Inf	-Inf	1.38629436111989
<=PSSM
<<<<

>>>>
REGION	v7
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.kingdom.Discoba
REGEX	[GA][A][TGC][TA][CG][CT][TAG][TAGC][CT][AC][TGA][C][GA][AG][TGA][TC][AG][AG][G][AG][TAC][CA][CT]
PSSMCUT	11
PSSM=>
-2.10413415427021	-Inf	1.35533213551592	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.36783229828016	-3.02042488614436	-3.71357206670431
-3.71357206670431	1.37402426852808	-Inf	-Inf
-Inf	-Inf	-2.32727770558442	1.36160174852952
-Inf	-2.32727770558442	-Inf	1.36160174852952
-3.71357206670431	-2.6149597780362	1.35533213551592	-Inf
1.09861228866811	-0.187211542088146	-2.32727770558442	-3.02042488614436
-Inf	1.28364020705981	-Inf	-1.07451473708905
1.37402426852808	-Inf	-Inf	-3.71357206670431
1.35533213551592	-3.71357206670431	-3.71357206670431	-Inf
-Inf	-Inf	-Inf	1.38017813410245
-2.6149597780362	-Inf	1.36783229828016	-Inf
1.27686052007443	-Inf	-0.880358722648092	-Inf
-1.0055218656021	-3.71357206670431	1.28364020705981	-Inf
-Inf	1.24225499089695	-Inf	-0.622529613345992
-3.71357206670431	-Inf	1.38017813410245	-Inf
1.37402426852808	-Inf	-3.02042488614436	-Inf
-Inf	-Inf	1.38629436111989	-Inf
1.38017813410245	-Inf	-3.71357206670431	-Inf
-3.71357206670431	0.808216510344733	-Inf	0.549107810337008
0.986908299088109	-Inf	-Inf	0.275411979859967
-Inf	1.28364020705981	-Inf	-1.0055218656021
<=PSSM
<<<<

>>>>
REGION	v7
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.Candidate-division-OP3
REGEX	[A][A][GT][CT][CGA][GC][CGT][TAG][TAC][GA][A][C][GA][A][G][C][G][C][AG][AG][C][C][CA]
PSSMCUT	14
PSSM=>
1.38629436111989	-Inf	-Inf	-Inf
1.38101730401905	-Inf	-Inf	-Inf
-Inf	-3.8607297110406	1.38101730401905	-Inf
-Inf	1.38101730401905	-Inf	-3.8607297110406
-3.8607297110406	-Inf	-1.08814098880081	1.29256188345718
-Inf	-Inf	-3.16758253048065	1.37571225178935
-Inf	-2.47443534992071	-3.8607297110406	1.35962611403773
-0.864997437486605	-3.16758253048065	1.26323426836266	-Inf
-2.2512917986065	-3.16758253048065	-Inf	1.3432769760362
1.37571225178935	-Inf	-3.8607297110406	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-3.8607297110406	-Inf	1.38101730401905	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.37571225178935	-Inf	-3.8607297110406	-Inf
1.38101730401905	-Inf	-3.8607297110406	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
1.36501696267261	-Inf	-Inf	-2.47443534992071
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.class.Pla3-lineage
REGEX	[T][G][G][G][C][CA][T][AG][GAC][A][G][GCA][G][C][AG][C][G][CT][A][GC][G][CT][G][G]
PSSMCUT	15
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.29098418131557	-Inf	-Inf	-1.01160091167848
-Inf	1.38629436111989	-Inf	-Inf
1.29098418131557	-Inf	-1.01160091167848	-Inf
-0.318453731118535	-Inf	-1.01160091167848	1.06784063000136
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-1.01160091167848	-Inf	1.18562366565774	-1.01160091167848
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.18562366565774	-Inf	-0.318453731118535	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.06784063000136	-Inf	0.0870113769896297
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.29098418131557	-1.01160091167848
-Inf	-Inf	1.38629436111989	-Inf
-Inf	0.780158557549575	-Inf	0.59783700075562
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.class.Agaricostilbomycetes
REGEX	[T][G][TG][CG][G][T][T][A][A][A][A][A][G][C][T][C][G][T][A][G][T][C][G][A][A]
PSSMCUT	15
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-1.17865499634165	1.30625165344635	-Inf
-Inf	-Inf	-1.17865499634165	1.30625165344635
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.30625165344635	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.phylum.Microsporidia
REGEX	[T][G][C][TG][G][T][T][A][A][A][GA][TGCA][G][T][CG][C][G][T][CA][G][T][CTA][AGT]
PSSMCUT	15
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.36567507391715
-Inf	-1.11923157587085	1.30113655277958	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.1833535171232	-Inf	-0.308301359654517	-Inf
-0.4260843953109	-0.20294084399669	-1.11923157587085	0.790310929013593
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.30113655277958	-1.11923157587085
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.30113655277958	-Inf	-Inf	-1.11923157587085
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-1.11923157587085	-1.81237875643079	-Inf	1.07799300146537
-1.11923157587085	0.752570601030746	-0.0206192872027357	-Inf
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.Candidate-division-OP11
REGEX	[AG][AT][A][TGA][T][TAC][CAT][CAT][TCGA][CAG][TC][TC][TGC][T][AG][TA][AC][GCT][TGA][TC][GACT][GT][TCAG]
PSSMCUT	14
PSSM=>
-3.63758615972639	-Inf	1.37969367708854	-Inf
-3.63758615972639	1.37969367708854	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-2.94443897916644	-3.63758615972639	1.36636014621907	-Inf
-Inf	1.37969367708854	-Inf	-Inf
-3.63758615972639	-3.63758615972639	-Inf	1.37304913436987
-3.63758615972639	-2.2512917986065	-Inf	1.35284642705235
-1.84582669049833	1.33222713984961	-Inf	-3.63758615972639
1.31117373065178	-2.2512917986065	-2.2512917986065	-2.94443897916644
-1.84582669049833	-Inf	1.33222713984961	-2.94443897916644
-Inf	-3.63758615972639	-Inf	1.37969367708854
-Inf	-0.418710334858185	-Inf	1.20660092673221
-Inf	-1.07263680226485	0.56710645966458	0.63907995928967
-Inf	1.38629436111989	-Inf	-Inf
1.37969367708854	-Inf	-3.63758615972639	-Inf
1.37969367708854	-3.63758615972639	-Inf	-Inf
1.37304913436987	-Inf	-Inf	-3.63758615972639
-Inf	-3.63758615972639	-3.63758615972639	1.36636014621907
-2.94443897916644	-2.2512917986065	1.34602046198195	-Inf
-Inf	-0.641853886172395	-Inf	0.652873281422005
1.36636014621907	-3.63758615972639	-3.63758615972639	-3.63758615972639
-Inf	1.37969367708854	-3.63758615972639	-Inf
-2.94443897916644	-3.63758615972639	1.32525847053352	-1.84582669049833
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.class.Kinetoplastea
REGEX	[G][AT][A][G][TA][C][C][GA][CT][GCTA][C][ATC][GCA][C][A][GA][A][C][GC][GA][TGA][G]
PSSMCUT	15
PSSM=>
-Inf	-Inf	1.37806386198338	-Inf
-3.41772668361337	1.36976505916868	-Inf	-Inf
1.37806386198338	-Inf	-Inf	-Inf
-Inf	-Inf	1.37806386198338	-Inf
-3.41772668361337	1.36976505916868	-Inf	-Inf
-Inf	-Inf	-Inf	1.37806386198338
-Inf	-Inf	-Inf	1.36139680949816
1.20724612967091	-Inf	-0.473287704446925	-Inf
-Inf	-2.72457950305342	-Inf	1.36139680949816
1.31847176478113	-3.41772668361337	-1.80828877117927	-3.41772668361337
-Inf	-Inf	-Inf	1.37806386198338
-3.41772668361337	0.0480092191863607	-Inf	1.05961013086484
1.05961013086484	-Inf	0.0480092191863607	-3.41772668361337
-Inf	-Inf	-Inf	1.37806386198338
1.37806386198338	-Inf	-Inf	-Inf
1.36976505916868	-Inf	-3.41772668361337	-Inf
1.37806386198338	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.37806386198338
-Inf	-Inf	1.28275368217905	-1.019831410815
0.0162605208717803	-Inf	1.07090968611877	-Inf
-3.41772668361337	1.36139680949816	-3.41772668361337	-Inf
-Inf	-Inf	1.37806386198338	-Inf
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.class.Microbotryomycetes
REGEX	[G][CT][AT][G][T][C][T][TC][AT][AT][C][AT][G][T][A][A][A][C][GT][A][T][G]
PSSMCUT	15
PSSM=>
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.37499480586596	-Inf	-3.10234200861225
1.37499480586596	-3.10234200861225	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.37499480586596	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-3.10234200861225	-Inf	1.37499480586596
-3.10234200861225	1.37499480586596	-Inf	-Inf
-3.10234200861225	1.37499480586596	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-3.10234200861225	1.37499480586596	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.37499480586596	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.37499480586596	-3.10234200861225	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.phylum.Microsporidia
REGEX	[GA][T][A][TG][T][ACT][C][TC][CT][AT][GT][CT][TA][G][T][CA][A][A][C][AG][A][T][G]
PSSMCUT	15
PSSM=>
-2.60268968544438	-Inf	1.36760222810774	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-2.60268968544438	1.36760222810774	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-2.60268968544438	1.34855403313704	-Inf	-2.60268968544438
-Inf	-Inf	-Inf	0.980829253011726
-Inf	-2.60268968544438	-Inf	1.36760222810774
-Inf	1.00822822719984	-Inf	0.230523658611832
-1.21639532432449	1.30933331998376	-Inf	-Inf
-Inf	-2.60268968544438	1.36760222810774	-Inf
-Inf	-2.60268968544438	-Inf	1.36760222810774
1.36760222810774	-2.60268968544438	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
0.616186139423817	-Inf	-Inf	0.76460614454209
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-0.117783035656384	-Inf	1.13497993283898	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.36760222810774	-Inf
<=PSSM
<<<<

>>>>
REGION	v6
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.class.Aquificae
REGEX	[G][A][AC][AG][A][CA][CAG][AG][TC][GC][A][T][G][GCT][A][C][C][A][C][C][T]
PSSMCUT	15
PSSM=>
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-2.2512917986065	-Inf	-Inf	1.35962611403773
-0.864997437486605	-Inf	1.27506872600967	-Inf
1.35962611403773	-Inf	-Inf	-Inf
-2.2512917986065	-Inf	-Inf	1.35962611403773
-2.2512917986065	-Inf	1.30405626288292	-2.2512917986065
-1.15267950993839	-Inf	1.30405626288292	-Inf
-Inf	-2.2512917986065	-Inf	1.30405626288292
-Inf	-Inf	-2.2512917986065	1.35962611403773
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.18269540587865	-2.2512917986065	-0.45953232937844
1.35962611403773	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.38629436111989	-Inf	-Inf
<=PSSM
<<<<

>>>>
REGION	v6
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.class.Eurotiomycetes
REGEX	[AGT][A][CGA][TA][AT][CTA][GCTA][AGT][TC][ATC][ATCG][AT][AGT][ACGT][ATG][CTA][CGT][AT][AGCT][ACGT][AGT]
PSSMCUT	17
PSSM=>
1.36760222810774	-3.29583686600433	-3.29583686600433	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-1.09861228866811	-Inf	1.27887411249905	-3.29583686600433
1.37699196845758	-3.29583686600433	-Inf	-Inf
1.36760222810774	-3.29583686600433	-Inf	-Inf
-2.60268968544438	0.980829253011726	-Inf	0.200670695462151
0.994622575144062	-3.29583686600433	0.169899036795397	-3.29583686600433
-1.50407739677627	-2.19722457733622	1.28913061266624	-Inf
-Inf	-1.09861228866811	-Inf	1.29928298413026
-3.29583686600433	1.23676262714893	-Inf	-0.65677953638907
1.35812348415319	-3.29583686600433	-3.29583686600433	-3.29583686600433
-2.60268968544438	1.36760222810774	-Inf	-Inf
0.341749293722057	-3.29583686600433	0.93826963859293	-Inf
-2.19722457733622	-0.0769610411361283	-2.60268968544438	1.06087196068526
1.35812348415319	-3.29583686600433	-2.60268968544438	-Inf
-3.29583686600433	-1.50407739677627	-Inf	1.30933331998376
-Inf	0.863046217355343	-3.29583686600433	0.465363249689233
1.36760222810774	-2.60268968544438	-Inf	-Inf
-2.60268968544438	-1.50407739677627	-3.29583686600433	1.29928298413026
-3.29583686600433	1.09861228866811	-3.29583686600433	-0.0769610411361283
1.35812348415319	-2.60268968544438	-3.29583686600433	-Inf
<=PSSM
<<<<

>>>>
REGION	v7
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.class.Eurotiomycetes
REGEX	[CA][AC][T][TCGA][GA][CAT][CGA][AC][TG][CA][A][CT][GCA][A][AG][CT][TAG][AT][GA][GA][TC][GCT][CT]
PSSMCUT	20
PSSM=>
1.37548344501567	-Inf	-Inf	-3.14630513203337
1.37548344501567	-Inf	-Inf	-3.14630513203337
-Inf	1.38629436111989	-Inf	-Inf
-3.14630513203337	1.34233123769877	-3.14630513203337	-2.45315795147342
0.823986781518757	-Inf	0.542574322080571	-Inf
-3.14630513203337	0.409042929456048	-Inf	0.896746135801185
0.823986781518757	-Inf	0.517256514096281	-3.14630513203337
1.37548344501567	-Inf	-Inf	-3.14630513203337
-Inf	1.37548344501567	-3.14630513203337	-Inf
1.37548344501567	-Inf	-Inf	-3.14630513203337
1.38629436111989	-Inf	-Inf	-Inf
-Inf	0.25489224962879	-Inf	0.996829594358167
0.964568732139946	-Inf	0.25489224962879	-2.45315795147342
1.36455437448348	-Inf	-Inf	-Inf
1.3535045382969	-Inf	-3.14630513203337	-Inf
-Inf	0.350202429433115	-Inf	0.948039430188735
0.896746135801185	-2.45315795147342	0.0317486983145803	-Inf
1.37548344501567	-3.14630513203337	-Inf	-Inf
-0.949080554697146	-Inf	1.24814402263907	-Inf
1.37548344501567	-Inf	-3.14630513203337	-Inf
-Inf	-1.35454566280531	-Inf	1.31960298662122
-Inf	-0.581355774571829	-3.14630513203337	1.22314272043366
-Inf	1.36455437448348	-Inf	-2.45315795147342
<=PSSM
<<<<

#>>>>
#REGION	v7
#ORDER	500
#TYPE	Eukaryota
#TARGET	Eukaryota.class.Sordariomycetes
#REGEX	[AGTC][AC][AGTC][GTAC][TGC][GAC][GTC][AGTC][CTGA][AGC][CGTA][AGC][TGAC][CTA][CAGT][CAGT][CGT][AGTC][CAG][ATC][TGC][CATG][GTAC]
#PSSMCUT	19
#PSSM=>
#1.31139305294677	-2.49526943682355	-2.49526943682355	-2.08980432871538
#1.34418287576976	-Inf	-Inf	-2.08980432871538
#-3.18841661738349	1.28892019709471	-2.49526943682355	-1.8021222562636
#-2.49526943682355	-0.703509967595492	-1.8021222562636	1.18103123508353
#-Inf	-2.08980432871538	1.32244288913336	-3.18841661738349
#-2.49526943682355	-Inf	-2.08980432871538	1.33337195966555
#-Inf	-2.08980432871538	1.34418287576976	-3.18841661738349
#1.30021975234865	-2.49526943682355	-1.57897870494939	-3.18841661738349
#-2.08980432871538	1.27749150127109	-1.8021222562636	-3.18841661738349
#1.32244288913336	-Inf	-3.18841661738349	-1.57897870494939
#1.31139305294677	-2.08980432871538	-3.18841661738349	-3.18841661738349
#-2.08980432871538	-Inf	-1.8021222562636	1.31139305294677
#-3.18841661738349	-2.08980432871538	1.30021975234865	-2.08980432871538
#1.27749150127109	-1.57897870494939	-Inf	-2.08980432871538
#1.33337195966555	-2.49526943682355	-3.18841661738349	-2.49526943682355
#-2.08980432871538	-3.18841661738349	-2.08980432871538	1.27749150127109
#-Inf	-3.18841661738349	1.30021975234865	-3.18841661738349
#1.27749150127109	-1.8021222562636	-1.57897870494939	-3.18841661738349
#-1.8021222562636	-Inf	1.33337195966555	-3.18841661738349
#1.30021975234865	-2.49526943682355	-Inf	-1.8021222562636
#-Inf	-3.18841661738349	-1.8021222562636	1.33337195966555
#-2.08980432871538	-2.49526943682355	-3.18841661738349	1.32244288913336
#-3.18841661738349	1.27749150127109	-1.8021222562636	-1.8021222562636
#<=PSSM
#<<<<

>>>>
REGION	v7
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.phylum.Microsporidia
REGEX	[A][GA][TA][T][ACT][ATC][GT][TCGA][ATC][A][A][CG][CGT][TCA][G][T][G][A][G][GCA][GCT][ATGC][GCT]
PSSMCUT	12
PSSM=>
1.38629436111989	-Inf	-Inf	-Inf
1.30751348326678	-Inf	-1.19392246847243	-Inf
1.08845991720409	0.0298529631496811	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-2.80336038090653	-2.80336038090653	-Inf	1.35552270245314
-2.11021320034659	0.780158557549575	-Inf	0.528844129268669
-Inf	-2.80336038090653	1.3710268889891	-Inf
1.20397280432594	-1.70474809223843	-0.857450231851222	-2.80336038090653
-2.80336038090653	1.29098418131557	-Inf	-1.19392246847243
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-1.19392246847243	1.30751348326678
-Inf	-2.11021320034659	1.30751348326678	-1.70474809223843
-2.80336038090653	-2.11021320034659	-Inf	1.339774345485
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
1.06784063000136	-Inf	0.0298529631496811	-2.80336038090653
-Inf	-2.80336038090653	0.723000143709626	0.630626823578611
-2.11021320034659	-2.11021320034659	0.751987680582879	0.415515443961666
-Inf	0.751987680582879	-2.11021320034659	0.492476485097794
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.class.Foraminifera
REGEX	[G][T][ATC][G][T][C][C][TC][A][T][T][AT][AGT][AT][CT][A][C][A][T][C][A][AG][A][C][GT][A][T][G]
PSSMCUT	15
PSSM=>
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
0.946927701336045	-2.42036812865043	-Inf	0.287682072451781
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	0.946927701336045	-Inf	0.352220593589352
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
0.287682072451781	0.144581228811107	-Inf	-Inf
0.144581228811107	0.980829253011726	-1.72722094809048	-Inf
-2.42036812865043	1.36382150526783	-Inf	-Inf
-Inf	1.36382150526783	-Inf	-2.42036812865043
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
1.36382150526783	-Inf	-2.42036812865043	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.01361907583472	0.218689200964829	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.phylum.Microsporidia
REGEX	[GA][T][A][TG][T][CAT][C][TC][TA][TG][CT][AT][G][T][A][A][A][C][GA][A][T][G]
PSSMCUT	15
PSSM=>
-1.50407739677627	-Inf	1.32913594727994	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-1.50407739677627	1.32913594727994	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-1.50407739677627	1.26851132546351	-Inf	-1.50407739677627
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-0.810930216216329	-Inf	1.26851132546351
-1.50407739677627	1.32913594727994	-Inf	-Inf
-Inf	-1.50407739677627	1.32913594727994	-Inf
-Inf	-1.50407739677627	-Inf	1.32913594727994
1.32913594727994	-1.50407739677627	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-1.50407739677627	-Inf	1.32913594727994	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.32913594727994	-Inf
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.phylum.Parabasalia
REGEX	[GA][T][A][GAT][GT][GTCA][TCG][CT][CTG][GTCA][C][TAC][GT][TC][CA][A][A][GAC][ATG][A][T][G]
PSSMCUT	15
PSSM=>
-2.14006616349627	-Inf	1.35644139797021	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-2.14006616349627	-1.44691898293633	1.29392104098888	-Inf
-Inf	1.35644139797021	-2.14006616349627	-Inf
-2.14006616349627	1.26113121816588	-2.14006616349627	-1.44691898293633
-Inf	-1.44691898293633	0.567984037605939	0.693147180559945
-Inf	-2.14006616349627	-Inf	1.35644139797021
-Inf	0.750305594399894	0.498991166118988	-1.44691898293633
1.03798766685167	-2.14006616349627	-0.0606246218164349	-2.14006616349627
-Inf	-Inf	-Inf	1.38629436111989
-1.04145387482816	-0.53062825106217	-Inf	1.07880966137193
-Inf	1.07880966137193	0.0571584138399486	-Inf
-Inf	1.35644139797021	-Inf	-2.14006616349627
1.2272296664902	-Inf	-Inf	-0.53062825106217
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-1.04145387482816	-Inf	-2.14006616349627	1.26113121816588
-0.194156014440958	0.498991166118988	0.424883193965266	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.phylum.Retaria
REGEX	[AG][T][CAT][CAG][T][GTC][CT][GTC][A][T][T][TGA][AT][TAC][AT][CT][GTA][T][C][A][GA][GA][CT][TGC][A][T][GA]
PSSMCUT	15
PSSM=>
-2.84781214347737	-Inf	1.37169556169874	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.12247977007475	-2.84781214347737	-Inf	-0.139761942375159
-1.46151778235748	-Inf	1.3110709398823	-2.84781214347737
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-2.84781214347737	-2.84781214347737	1.3568804759136
-Inf	0.287682072451781	-Inf	0.980829253011726
-Inf	0.519483686509105	-2.84781214347737	0.815749502652278
0.958850346292951	-Inf	-Inf	-Inf
-Inf	0.958850346292951	-Inf	-Inf
-Inf	0.958850346292951	-Inf	-Inf
-0.282862786015832	0.553385238184787	-2.15466496291742	-Inf
-2.84781214347737	0.936377490440892	-Inf	-Inf
0.287682072451781	0.936377490440892	-Inf	-2.84781214347737
1.37169556169874	-2.84781214347737	-Inf	-Inf
-Inf	-1.46151778235748	-Inf	1.32657512641827
1.27932224156772	-2.15466496291742	-1.23837423104327	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	0.958850346292951
1.38629436111989	-Inf	-Inf	-Inf
1.37169556169874	-Inf	-2.84781214347737	-Inf
1.3568804759136	-Inf	-2.84781214347737	-Inf
-Inf	-2.84781214347737	-Inf	1.37169556169874
-Inf	1.14117190308691	-0.20875481386211	-2.84781214347737
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
0.243230309880947	-Inf	1.00233545823269	-Inf
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.class.Incertae-sedis
REGEX	[T][G][C][C][G][T][T][A][A][A][A][C][G][C][G][C][T][G][A][G][T][C][G][A][A]
PSSMCUT	16
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.phylum.Fornicata
REGEX	[T][G][C][AG][AG][T][T][A][A][A][A][CA][G][TC][AC][C][G][GT][CA][G][CT][C][G]
PSSMCUT	15
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
0.8754687373539	-Inf	0.470003629245736	-Inf
0.470003629245736	-Inf	0.8754687373539	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
0.470003629245736	-Inf	-Inf	0.8754687373539
-Inf	-Inf	1.38629436111989	-Inf
-Inf	0.8754687373539	-Inf	0.470003629245736
0.470003629245736	-Inf	-Inf	0.8754687373539
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	0.470003629245736	0.8754687373539	-Inf
0.8754687373539	-Inf	-Inf	0.470003629245736
-Inf	-Inf	1.38629436111989	-Inf
-Inf	0.8754687373539	-Inf	0.470003629245736
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.class.Diplomonadida
REGEX	[G][T][A][T][T][C][C][C][G][GA][CG][C][G][T][A][A][A][C][G][AG][T][TG]
PSSMCUT	15
PSSM=>
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
0.538996500732687	-Inf	0.826678573184468	-Inf
-Inf	-Inf	0.133531392624523	1.04982212449868
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-0.559615787935423	-Inf	1.23214368129263	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-0.559615787935423	1.23214368129263	-Inf
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.class.Euglenida
REGEX	[G][T][GA][AG][T][C][C][GT][G][CT][C][ATG][C][CT][TG][T][A][A][A][CT][GCT][AC][T][G]
PSSMCUT	15
PSSM=>
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.34184259854906	-Inf	-1.74919985480926	-Inf
-0.650587566141149	-Inf	1.24653241874473	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-0.362905493689368	1.19523912435718	-Inf
-Inf	-Inf	0.958850346292951	-Inf
-Inf	0.196710294246054	-Inf	1.02338886743052
-Inf	-Inf	-Inf	0.958850346292951
0.958850346292951	0.196710294246054	-1.74919985480926	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.24653241874473	-Inf	-0.650587566141149
-Inf	-0.650587566141149	1.24653241874473	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.34184259854906	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	0.0425596144187959	-Inf	1.08401348924696
-Inf	0.196710294246054	0.44802472252696	0.196710294246054
0.958850346292951	-Inf	-Inf	0.330241686870577
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.phylum.Fornicata
REGEX	[G][T][A][TC][T][TC][C][TC][GA][AG][GC][CT][AG][T][A][A][A][C][GT][GA][T][GAT]
PSSMCUT	15
PSSM=>
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.29098418131557	-Inf	-1.01160091167848
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-0.318453731118535	-Inf	1.18562366565774
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-1.01160091167848	-Inf	1.29098418131557
0.374693449441411	-Inf	0.934309237376833	-Inf
0.0870113769896297	-Inf	1.06784063000136	-Inf
-Inf	-Inf	-0.318453731118535	1.18562366565774
-Inf	-1.01160091167848	-Inf	1.29098418131557
0.0870113769896297	-Inf	1.06784063000136	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-0.318453731118535	1.18562366565774	-Inf
0.59783700075562	-Inf	0.780158557549575	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-1.01160091167848	-0.318453731118535	1.06784063000136	-Inf
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.phylum.RT5iin25
REGEX	[G][T][A][G][T][T][C][G][C][A][C][A][G][T][A][A][A][C][G][A][T][G]
PSSMCUT	15
PSSM=>
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v6
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.class.Euamoebida
REGEX	[A][A][A][A][TA][C][G][G][C][C][A][T][G][C][A][C][C][G][G][C][T]
PSSMCUT	15
PSSM=>
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.25276296849537	-0.693147180559945	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.38629436111989	-Inf	-Inf
<=PSSM
<<<<

>>>>
REGION	v6
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.phylum.Microsporidia
REGEX	[AG][A][GC][AG][A][C][G][G][C][C][A][T][G][C][A][C][C][TA][C][G][TGC]
PSSMCUT	15
PSSM=>
0.798507696217772	-Inf	0.575364144903562	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.26851132546351	-0.810930216216329
1.26851132546351	-Inf	-0.810930216216329	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
0.798507696217772	0.575364144903562	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	0.575364144903562	-0.810930216216329	0.575364144903562
<=PSSM
<<<<

>>>>
REGION	v6
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.phylum.Tubulinea
REGEX	[A][A][A][A][AT][C][G][G][C][C][A][T][G][C][A][C][C][G][G][C][T]
PSSMCUT	15
PSSM=>
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.25276296849537	-0.693147180559945	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.38629436111989	-Inf	-Inf
<=PSSM
<<<<

>>>>
REGION	v7
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.phylum.Fornicata
REGEX	[CT][A][TC][T][G][C][G][A][CT][A][A][C][TG][AG][GA][C][G][A][G][A][C][C][CT]
PSSMCUT	15
PSSM=>
-Inf	-0.22314355131421	-Inf	1.16315080980568
1.38629436111989	-Inf	-Inf	-Inf
-Inf	0.470003629245736	-Inf	0.8754687373539
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-0.22314355131421	-Inf	1.16315080980568
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-0.22314355131421	1.16315080980568	-Inf
1.16315080980568	-Inf	-0.22314355131421	-Inf
-0.22314355131421	-Inf	1.16315080980568	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-0.22314355131421	-Inf	1.16315080980568
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.order.Rickettsiales
REGEX	[GTA][T][TA][GA][T][CTG][CT][TA][AGTC][ATGC][C][ATC][GC][GAT][ATGC][TA][AGTC][CTA][CGT][TAC][GT][CG]
PSSMCUT	16
PSSM=>
-1.25276296849537	-2.7191000372888	1.28215410186729	-3.8177123259569
-3.8177123259569	1.36967347988385	-3.8177123259569	-Inf
1.36967347988385	-3.12456514539696	-Inf	-Inf
-2.7191000372888	-Inf	1.36407122433518	-Inf
-3.8177123259569	1.37524452493331	-Inf	-Inf
-Inf	-3.12456514539696	-3.12456514539696	1.35277166908125
-3.8177123259569	-0.180126166230519	-Inf	1.09494255977915
1.18623397998855	-0.416514944294749	-3.8177123259569	-Inf
0.873635556272239	-0.180126166230519	-3.12456514539696	-0.383725121471758
-3.12456514539696	-2.7191000372888	1.34707364796661	-3.12456514539696
-3.8177123259569	-Inf	-3.8177123259569	1.37524452493331
1.08756245248152	-1.3328056761689	-3.8177123259569	-0.351976423157178
-3.8177123259569	-3.8177123259569	1.32978215085655	-1.87180217690159
0.873635556272239	0.430782916092454	-3.12456514539696	-3.8177123259569
1.17272026082183	-3.12456514539696	-2.7191000372888	-0.416514944294749
1.36967347988385	-3.12456514539696	-Inf	-Inf
1.30028148645985	-3.12456514539696	-3.12456514539696	-2.7191000372888
-1.51512723296286	1.06508959662947	-Inf	-0.154150679827258
-Inf	-0.984498981900689	1.26988400927548	-2.7191000372888
1.32978215085655	-2.7191000372888	-3.8177123259569	-2.02595285672885
-Inf	1.36967347988385	-2.7191000372888	-Inf
-3.8177123259569	-Inf	1.36967347988385	-3.12456514539696
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.order.Verrucomicrobiales
REGEX	[GCT][T][AT][GT][CT][CT][CT][GTC][GTA][GC][C][ATC][ACTG][CT][TGA][A][AGTC][GC][TGA][TGC][AGCT][AGTC]
PSSMCUT	13
PSSM=>
-Inf	-2.69968195143169	1.34336931640286	-2.69968195143169
-Inf	1.36934480280612	-3.39282913199164	-3.39282913199164
1.3167010693207	-1.60106966276358	-Inf	-3.39282913199164
-3.39282913199164	-1.78339121955754	1.32566973930346	-3.39282913199164
-Inf	1.36934480280612	-Inf	-2.69968195143169
-Inf	-2.29421684332353	-Inf	1.36076105911473
-3.39282913199164	-0.684778930889429	-Inf	1.241899856238
-Inf	1.25156176714973	-2.00653477087175	-0.994933859193268
-0.907922482203638	-2.29421684332353	1.25156176714973	-Inf
-3.39282913199164	-Inf	1.27999970247027	-0.994933859193268
-Inf	-Inf	-3.39282913199164	1.37785549247403
1.32566973930346	-2.29421684332353	-Inf	-2.00653477087175
-2.00653477087175	-2.69968195143169	1.30765123380078	-2.69968195143169
-3.39282913199164	1.36076105911473	-Inf	-2.69968195143169
1.3167010693207	-2.00653477087175	-2.29421684332353	-3.39282913199164
1.36076105911473	-Inf	-3.39282913199164	-Inf
1.27060996212043	-2.69968195143169	-2.29421684332353	-1.44691898293633
-Inf	-Inf	-2.69968195143169	1.36934480280612
-2.00653477087175	-2.69968195143169	1.32566973930346	-3.39282913199164
-3.39282913199164	-2.69968195143169	1.30765123380078	-2.00653477087175
-1.60106966276358	0.950976289862045	-0.620240409751858	-0.684778930889429
-2.29421684332353	-2.69968195143169	1.0958072377405	-0.397096858437648
<=PSSM
<<<<

>>>>
REGION	v6
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.major_clade.Excavata
REGEX	[GATC][TCGA][AGC][AGT][AG][ATC][AG][GA][GC][TC][A][TCA][G][C][A][TCG][CT][GA][C][CT][AGCT]
PSSMCUT	15
PSSM=>
1.18251517698747	-2.70247915605275	-0.46888693454566	-3.10794426416092
0.0275499517682306	-3.10794426416092	0.326042940324227	0.433015059876395
0.241959823113686	-3.80109144472086	0.0907288533897622	0.461588432320451
1.35796385449366	-3.10794426416092	-3.10794426416092	-3.80109144472086
0.720697132328176	-Inf	0.664816673933719	-Inf
-2.70247915605275	-2.19165353228676	-Inf	1.3405721117818
-3.10794426416092	-Inf	1.37505828785296	-Inf
-1.49850635172682	-3.80109144472086	1.31089634363568	-3.80109144472086
-Inf	-Inf	-3.10794426416092	1.36939255031729
-3.80109144472086	-3.10794426416092	-Inf	1.36939255031729
1.38629436111989	-Inf	-Inf	-Inf
-3.10794426416092	1.36369452920265	-Inf	-3.10794426416092
-3.80109144472086	-Inf	1.37505828785296	-Inf
-Inf	-3.80109144472086	-Inf	1.36939255031729
1.36939255031729	-3.80109144472086	-3.80109144472086	-3.80109144472086
-Inf	-2.70247915605275	-3.10794426416092	1.35796385449366
-3.80109144472086	-1.09304124361865	-Inf	1.2926587560859
1.36369452920265	-3.80109144472086	-3.10794426416092	-3.80109144472086
-Inf	-Inf	-3.80109144472086	1.38069210557122
-3.80109144472086	-1.85518129566555	-3.80109144472086	1.3347069923294
-0.710048991362549	-2.00933197549281	0.326042940324227	0.687544925011275
<=PSSM
<<<<

>>>>
REGION	v7
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.order.Rickettsiales
REGEX	[TCA][ATC][TCGA][GT][TC][C][TCA][TCGA][GATC][TA][TA][CT][CTG][GA][TAG][GATC][GAT][CTA][CA][A][CTAG][TC][CT]
PSSMCUT	15
PSSM=>
1.09703126067079	-1.02112479318974	-3.96556377235618	-1.56766849955781
1.20492022268198	-2.57926941123629	-3.27241659179623	-2.17380430312812
-2.35612585992208	-0.227894154072808	-0.0737434742455492	0.577731009913828
-3.27241659179623	1.33275359419186	-1.88612223067634	-Inf
-3.96556377235618	-1.76833919501996	-3.96556377235618	1.32270325833836
-3.27241659179623	-3.96556377235618	-3.96556377235618	1.35255622148804
-0.115416170646117	0.870718134595302	-3.27241659179623	-0.439203247740015
0.428885382316263	0.268542732241083	-0.32797761262979	-0.830069556427026
-0.181374138437915	0.556224804692864	-0.469056210889696	-0.227894154072808
1.34270392504503	-2.57926941123629	-3.27241659179623	-3.27241659179623
1.34270392504503	-2.57926941123629	-3.96556377235618	-3.96556377235618
-Inf	1.00424952721982	-3.96556377235618	0.208823497539461
-3.96556377235618	0.917238150230195	0.324895668792215	-2.57926941123629
1.23293325890965	-Inf	-0.830069556427026	-3.96556377235618
1.0111699700644	-2.86695148368807	0.145310091817135	-3.27241659179623
-2.35612585992208	-2.86695148368807	-1.48065712256818	1.28670965569045
-1.66297867936213	-2.17380430312812	1.29712641654871	-3.27241659179623
0.961689912801029	-1.19297505011639	-3.27241659179623	0.0417694128762951
1.34764220668561	-3.27241659179623	-3.96556377235618	-2.57926941123629
1.36715502090919	-3.27241659179623	-Inf	-3.96556377235618
0.743966428956158	-0.669726906351847	-2.86695148368807	0.282931469693183
-3.96556377235618	-0.830069556427026	-Inf	1.25479205272215
-3.27241659179623	-2.01965362330086	-3.27241659179623	1.32270325833836
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Archaea
TARGET	Archaea.class.AB64A-17
REGEX	[T][G][G][G][C][C][T][A][A][A][G][C][A][T][C][C][G][T][A][C][C][C][G][G]
PSSMCUT	15
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Archaea
TARGET	Archaea.phylum.Marine-Hydrothermal-Vent-Group-2-MHVG-2-
REGEX	[T][G][G][G][C][T][T][A][A][A][G][C][A][T][C][C][G][T][A][C][C][G][G]
PSSMCUT	15
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.38629436111989	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.order.B10-SB3A
REGEX	[T][G][G][G][C][G][T][C][A][A][G][C][G][C][G][CT][G][T][A][G][G][C][G][G]
PSSMCUT	15
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	0.980829253011726	-Inf	0.287682072451781
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.order.W27
REGEX	[T][A][G][G][C][G][T][A][A][A][G][T][G][C][A][G][G][T][A][G][G][C][G][G]
PSSMCUT	15
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.phylum.Candidate-division-WS6
REGEX	[T][G][TG][G][CT][G][CT][A][T][A][GC][A][G][A][GA][C][G][T][A][CGA][AG][C][G][TG]
PSSMCUT	15
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-1.50407739677627	1.32913594727994	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.13497993283898	-Inf	-0.117783035656384
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.32913594727994	-Inf	-1.50407739677627
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.20397280432594	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.26851132546351	-0.810930216216329
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
1.26851132546351	-Inf	-Inf	-Inf
-0.810930216216329	-Inf	1.06087196068526	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-1.50407739677627	-Inf	1.26851132546351	-1.50407739677627
-1.50407739677627	-Inf	1.32913594727994	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	0.893817876022097	0.441832752279039	-Inf
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Archaea
TARGET	Archaea.class.AB64A-17
REGEX	[G][T][A][G][T][C][C][C][A][G][C][T][G][T][A][A][A][C][C][G][A][T][G]
PSSMCUT	15
PSSM=>
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.order.PBS-18
REGEX	[G][T][A][G][T][C][C][G][C][A][C][A][G][T][A][A][A][C][G][A][T][A]
PSSMCUT	15
PSSM=>
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.class.Classiculomycetes
REGEX	[G][T][A][A][T][C][T][T][A][C][C][A][G][T][A][A][A][C][T][A][T][G]
PSSMCUT	15
PSSM=>
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.38629436111989	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v5
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.class.Dictyochales
REGEX	[G][T][A][G][T][C][T][T][A][T][A][C][C][A][T][A][A][A][C][T][A][T][G]
PSSMCUT	15
PSSM=>
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.38629436111989	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v6
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.class.P2-11E
REGEX	[G][A][C][G][A][C][GAT][G][C][C][G][T][G][C][A][A][C][A][GC][C][GA]
PSSMCUT	15
PSSM=>
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.13497993283898	-0.810930216216329	-0.810930216216329	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-0.810930216216329	1.26851132546351
-Inf	-Inf	-Inf	1.38629436111989
1.26851132546351	-Inf	-0.810930216216329	-Inf
<=PSSM
<<<<

>>>>
REGION	v7
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.class.Foraminifera
REGEX	[A][A][T][T][G][C][G][T][AT][T][C][A][CGA][CAT][TA][TA][GAT][ATG][TAG][ATC][ATGC][ATC][TAC]
PSSMCUT	15
PSSM=>
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-1.53147637096439	1.33072450996508	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-0.838329190404443	-Inf	0.771108722029657	0.340325805937203
-1.12601126285622	1.27188400994215	-Inf	-2.22462355152433
1.07121331448	0.0779615414697119	-Inf	-Inf
1.35889538693178	-2.22462355152433	-Inf	-Inf
0.819898886199089	-0.615185639090233	0.173271721274037	-Inf
0.260283098263667	0.260283098263667	0.340325805937203	-Inf
0.260283098263667	0.0779615414697119	0.483426649577876	-Inf
0.953430278823612	-2.22462355152433	-Inf	0.260283098263667
0.866418901833982	-2.22462355152433	-1.53147637096439	0.260283098263667
0.819898886199089	0.483426649577876	-Inf	-2.22462355152433
0.866418901833982	0.340325805937203	-Inf	-1.53147637096439
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.order.Lineage-IIc
REGEX	[T][A][G][G][CT][G][T][A][A][A][G][CG][AG][C][A][G][G][T][A][G][AG][T][G][G]
PSSMCUT	15
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	0.693147180559945	-Inf	0.693147180559945
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.09861228866811	0
0	-Inf	1.09861228866811	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
0	-Inf	1.09861228866811	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Bacteria
TARGET	Bacteria.order.MVP-88
REGEX	[T][A][AG][G][C][G][T][A][A][A][AG][C][G][T][G][G][G][GC][A][G][GC][GC][G][G]
PSSMCUT	15
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
0.287682072451781	-Inf	0.980829253011726	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
0.287682072451781	-Inf	0.980829253011726	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	0.287682072451781	0.980829253011726
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	0.980829253011726	0.287682072451781
-Inf	-Inf	0.287682072451781	0.980829253011726
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
<=PSSM
<<<<

>>>>
REGION	v4
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.phylum.Phaeothamniophyceae
REGEX	[T][G][C][A][G][T][A][A][A][A][G][C][T][C][G][T][A][G][T][T][G][G][A]
PSSMCUT	15
PSSM=>
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
1.38629436111989	-Inf	-Inf	-Inf
<=PSSM
<<<<

>>>>
REGION	v6
ORDER	500
TYPE	Eukaryota
TARGET	Eukaryota.phylum.Rhodellophyceae
REGEX	[A][A][A][GA][C][C][G][G][C][C][A][T][G][C][A][C][C][A][C][C][A]
PSSMCUT	15
PSSM=>
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
1.38629436111989	-Inf	-Inf	-Inf
0	-Inf	1.09861228866811	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	1.38629436111989	-Inf	-Inf
-Inf	-Inf	1.38629436111989	-Inf
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
-Inf	-Inf	-Inf	1.38629436111989
-Inf	-Inf	-Inf	1.38629436111989
1.38629436111989	-Inf	-Inf	-Inf
<=PSSM
<<<<
