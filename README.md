# RiboTagger
fast and unbiased 16S/18S profiling of shotgun metagenome and metatranscriptome data

## Overview
		RiboTagger is composed of a few scripts. The main script is called ribotagger.pl, 
		which scans one or more fastq/fasta files to extract sequences from a particular variable 
		region and report estimated observations for each reported sequences due to sequencing error. 
		Each of your samples need to be scanned individually by this script. 
		Then there is a script biom.pl to combine the output files from ribotagger.pl and produces a number
		of output files, including a few tabular files and a BIOM formated file.
		The tabular files can be used for your 16S/18S profiling analysis, while the BIOM file can be directly
		used by tools like QIIME.

## Example Runs
### Sample data
		You need to downaload and unpack the <a href="files/samples.tar.gz">sample data files</a>.
### Test Runs

		After unpacking the sample data, you should have
```
> ls -lh test/
	total 131M
	-rw-r--r-- 1 xiechao xiechao 47M 2014-08-23 17:12 samp1.fq
	-rw-r--r-- 1 xiechao xiechao 29M 2014-08-23 17:12 samp2_1.fq
	-rw-r--r-- 1 xiechao xiechao 29M 2014-08-23 17:12 samp2_2.fq
	-rw-r--r-- 1 xiechao xiechao 14M 2014-08-23 17:12 samp3.fq.gz
	-rw-r--r-- 1 xiechao xiechao 14M 2014-08-23 17:12 samp4.fq.gz
> mkdir out
'''

The simplest way of calling ribotagger.pl
<pre>
> ribotagger.pl -r v4 -i test/samp1.fq -o out/samp1.v4 
</pre>

The structure of the output
<pre>
> head out/samp1.v4 
	#By:    RiboTagger v0.8.0 (PSSM: 2014-08-01)
	#Date:  2014-08-23T20:23:05
	#CMD:   -r v4 -i test/samp1.fq -o out/samp1.v4
	#nreads=200000
	#ntagreads=1327
	#ntags=546
	#tag    n       npos    fp      long.total.count        long1.count     long2.count     long3.count     long1   long2
	TTGACTAAGTCGGATGTGAAAGCTCCTGGCTTA       68      28      0.0001  44      43      1       0       TGGGCGTAAAGCGCATGTAGGCGGTTGACTAAGTCGGATGTGAAAGCTCCTGGCTTAACTGGGAGAGGCCATTCGAAACTAGTC  TGGGCGTAAAGCGCATGTAGGCGGTTGACTAAGTCGGATGTGAAAGCTCCTGGCTTAGCTGGGAGAGGCCATTCGAAACTAGTC
	TTGGGTAAGTCAGATGTGAAATCCCCGGGCTCA       48      24      0.0034  30      21      8       1       TGGGCGTAAAGCGTGCGCAGGCGGTTGGGTAAGTCAGATGTGAAATCCCCGGGCTCAACCTGGGAACTGCATTTGAGACTGCCC  TGGGCGTAAAGCGTGCGCAGGCGGTTGGGTAAGTCAGATGTGAAATCCCCGGGCTCAACCTGGGAACTGCATTTGAGACTGTCC
	CACGTTAAGTCAGGTGTGAAACCCCCGGGCTCA       32      20      0.0000  15      15      0       0       TGGGCGTAAAGCGCACGTAGGCGGCACGTTAAGTCAGGTGTGAAACCCCCGGGCTCAACCTGGGAATGGCATTTGATACTGGCG  
</pre>

The output is a table file with the following fields:
<ul>
	<li> <b>tag</b>: the tag sequence for the variable region
	<li> <b>n</b>: the number of reads that contains this tag
	<li> <b>npos</b>: the number of different locations of the tag on their source reads (big value of column "n" with small value of "npos" indicates duplicated reads or amplicon sequencing data)
	<li> <b>fp</b>: the number of reads you would expect to see this tag due to sequencing errors alone
	<li> <b>long.total.count</b>: the number of reads containing a longer sequence of this tag (see the -long option)
	<li> <b>long1.count, long2.count, long3.count</b>: number of reads containing the most abundant variants of this tag's long sequences (low long1.count/long.total.count ratio indicates that this tag is very likely repressenting a mixture of "species")
	<li> <b>long1, long2</b>: the most abundant long representive sequences of this tag
</ul>


If you have more than one files composing one sample (say pair end reads), and you want to make one ribotag report for this sample, you can supply multiple files for the -i or -in option:
<pre>
> ribotagger.pl -r v4 -i test/samp2_1.fq test/samp2_2.fq -o out/samp2.v4 
</pre>

You can also use compressed files as input. Both gzip and bzip2 are supported. However, tar.gz or tar are NOT supported.
<pre>
> ribotagger.pl -r v4 -i test/samp3.fq.gz -o out/samp3.v4
> ribotagger.pl -r v4 -i test/samp4.fq.gz -o out/samp4.v4
</pre>

Make summary table files and a BIOM file for all your four samples:
<pre>
> ls -lh out
	total 252K
	-rw-r--r-- 1 xiechao xiechao 64K 2014-08-23 20:23 samp1.v4
	-rw-r--r-- 1 xiechao xiechao 67K 2014-08-23 20:25 samp2.v4
	-rw-r--r-- 1 xiechao xiechao 57K 2014-08-23 20:26 samp3.v4
	-rw-r--r-- 1 xiechao xiechao 60K 2014-08-23 20:27 samp4.v4

> biom.pl -r v4 -i out/samp*.v4 -o out/my.sample
</pre>

Then you will see 4 files in your out folder:
<pre>
-rw-r--r-- 1 xiechao xiechao  56K 2014-09-04 17:05 my.sample.anno
-rw-r--r-- 1 xiechao xiechao 132K 2014-09-04 17:05 my.sample.biom
-rw-r--r-- 1 xiechao xiechao  16K 2014-09-04 17:05 my.sample.tab
-rw-r--r-- 1 xiechao xiechao  71K 2014-09-04 17:05 my.sample.xls
</pre>

The *.tab file contains the ribotag abundance (raw count) in each sample. 
<a id="anno"/>
The *.anno file contains the annotation of each ribotag (only available if you are using default -tag and -long option for ribotagger.pl). The fileds in this file are as follows:
<ul>
	<li><b>tag</b>: the ribotag sequence
	<li><b>use</b>: "tag" or "long", whether the annotation was based on the short tag or long representive sequence
	<li><b>taxon_level</b>: taxa rank of this annotation of this tag
	<li><b>taxon_data</b>: taxa rank of the most specific annotation appeared in the database (silva or greengenes) for this tag
	<li><b>long</b>: the long representive sequence of this tag
	<li><b>long_total</b>: the number of samples having any long representive sequence
	<li><b>long_this</b>: the number of samples having this long sequence as its major representive of this tag
	<li><b>support</b>: the number of database sequences having this this tag or long sequence
	<li><b>confidence</b>: the proportion of the database sequences agreed on this annotation
	<li><b>k, p, c, o, f, g, s</b>: annotation for each of the taxa ranks - kingdom/domain, phylum, class, order, family, genus, and species
</ul>
The *.xls file is the combination of the *.tab and *.anno files. <br>
The *.biom file can be used by QIIME. 
<br>
<br>

From the above files, you can carry on with your usual community profiling routine. For example, PCoA analysis using the provided R script:
<pre>
pcoa.r out/my.sample.tab out/my.sample.pcoa
</pre>

We also provide a batch script to do all the above steps after ribotagger.pl:
<pre>
batch.pl -r v4 -i out/samp*.v4 -o out/my.sample
</pre>
Then check your folder out/my.sample.
<br>
<br>

There are many options can be tweaked for both ribotagger.pl and biom.pl (see the last section of this page for detailed references).
<br><br>
Or if you want to use RiboTagger to do more creative things, the following commands for ribotagger.pl might be useful for you:
<pre>
> ribotagger.pl -r v4 -i test/samp1.fq -o /dev/null --print-head --print-tag --print-long | head

SOURCE: @HWI-ST884:58:1:1101:14005:33196#0/1
TAG:    CTTCGTAAGACAGAGGTGAAATCCCCGGGCTCA
LONG:   
SOURCE: @HWI-ST884:58:1:1101:14598:33076#0/1
TAG:    CCTGTTAAGTCAGATGTGAAAGCTCTGGGCTCA
LONG:   TGGGCGTAAAGGGCGCGTAGGCGGCCTGTTAAGTCAGATGTGAAAGCTCTGGGCTCAACCCAGGAATTGCATTTGATACTGGCA
SOURCE: @HWI-ST884:58:1:1101:16245:33219#0/1
TAG:    TTAGTCGCGTCGTAAGTGCAAACTCAGGGCTTA
LONG:   TGGGCGTAAAGAGCTTGTAGGCGGTTAGTCGCGTCGTAAGTGCAAACTCAGGGCTTAACCCTGAGCCTGCTTTCGATACGGGCT
SOURCE: @HWI-ST884:58:1:1101:16444:33060#0/1

> ribotagger.pl -r v4 -i test/samp1.fq -o /dev/null --print-head --print-seq | head

SOURCE: @HWI-ST884:58:1:1101:14005:33196#0/1
RAW:    GCCGCGGTAATACGTAGGGTGCAAGCGTTAATCGGAATTACTGGGCGTAAAGCGTGCGCAGGCGGCTTCGTAAGACAGAGGTGAAATCCCCGGGCTCAACC
SOURCE: @HWI-ST884:58:1:1101:14598:33076#0/1
RAW:    GAATTATTGGGCGTAAAGGGCGCGTAGGCGGCCTGTTAAGTCAGATGTGAAAGCTCTGGGCTCAACCCAGGAATTGCATTTGATACTGGCAGGCTTGAGTT
SOURCE: @HWI-ST884:58:1:1101:16245:33219#0/1
RAW:    CCGGATTTATTGGGCGTAAAGAGCTTGTAGGCGGTTAGTCGCGTCGTAAGTGCAAACTCAGGGCTTAACCCTGAGCCTGCTTTCGATACGGGCTGACTAGA
SOURCE: @HWI-ST884:58:1:1101:16444:33060#0/1
RAW:    CTTCCGTACTCAAGCCCGCCAGTTTCGGATGCACTTCCTCGGTTAAGCCGAGGGCTTTCACATCCGACATAGCGAACCGCCTACGTGCGCTTTACGCCCAA
SOURCE: @HWI-ST884:58:1:1101:18755:33044#0/1
RAW:    GCGTTGTTCGGAATCATTGGGCGTAAAGCGGGTGTAGGTTGCTCTATAAGTCAGATGTGAAAGCCCTGGGCTTAACCCAGGAAGTGCATTTGATACTGCAG

> ribotagger.pl -r v4 -i test/samp1.fq -o /dev/null --print-head --print-seq --print-no-prefix | head
@HWI-ST884:58:1:1101:14005:33196#0/1
GCCGCGGTAATACGTAGGGTGCAAGCGTTAATCGGAATTACTGGGCGTAAAGCGTGCGCAGGCGGCTTCGTAAGACAGAGGTGAAATCCCCGGGCTCAACC
@HWI-ST884:58:1:1101:14598:33076#0/1
GAATTATTGGGCGTAAAGGGCGCGTAGGCGGCCTGTTAAGTCAGATGTGAAAGCTCTGGGCTCAACCCAGGAATTGCATTTGATACTGGCAGGCTTGAGTT
@HWI-ST884:58:1:1101:16245:33219#0/1
CCGGATTTATTGGGCGTAAAGAGCTTGTAGGCGGTTAGTCGCGTCGTAAGTGCAAACTCAGGGCTTAACCCTGAGCCTGCTTTCGATACGGGCTGACTAGA
@HWI-ST884:58:1:1101:16444:33060#0/1
CTTCCGTACTCAAGCCCGCCAGTTTCGGATGCACTTCCTCGGTTAAGCCGAGGGCTTTCACATCCGACATAGCGAACCGCCTACGTGCGCTTTACGCCCAA
@HWI-ST884:58:1:1101:18755:33044#0/1
GCGTTGTTCGGAATCATTGGGCGTAAAGCGGGTGTAGGTTGCTCTATAAGTCAGATGTGAAAGCCCTGGGCTTAACCCAGGAAGTGCATTTGATACTGCAG

</pre>

<h3>Command line options for the main scripts</h3>

		<h4>ribotagger.pl</h4>
		<pre>
usage: ribotagger.pl [options] -region v4|v5|v6|v7 -out OUTFILE -in INFILE1 [INFILE2 ...]

  Required:

	-in INFILE1 INFILE2 ...    one or more input files, 
	                           can be compressed by gz or bz2, but not tar
	                           files must be in fastq, fasta, or plain sequence format
	-out OUTFILE               output file
	-region [v4|v5|v6|v7]      variable region

  Optional:

	-min-score INT             minimum score at each position of 
	                           the tag or long sequences
	                           default = 30
	-min-pos INT               minimum number of different start positions 
	                           for a tag to be reported
	                           default = 1

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
	                           default = 33
	-se INT                    number of sequencing errors used to 
	                           estimate expected number of observations of a tag
	                           due to sequencing erros
	                           default = 1

	-tag INT                   length of tag to report   
	                           default = 33
	-long INT                  length of long sequence to report
	                           (probe sequence is included in long, 
	                           but not counted to this length) 
	                           default = 60
	-before-tag INT            length of sequence before the probe
	                           to be included in the reported long sequence
	                           default = 0

	-help
	</pre>
		<h4>biom.pl</h4>
		<pre>

usage: biom.pl [options] -region v4|v5|v6|v7 -out OUTFILE -in INFILE1 [INFILE2 ...]

  Required:

	-in INFILE1 INFILE2 ...    one or more files generated from ribotagger.pl 
	-out OUTFILE               output biom file
	-region [v4|v5|v6|v7]      variable region

  Optional:

	-min-pos INT               minimum number of different start positions 
	                           for a tag to be reported
	                           default = 2
	-fp minus|nothing          report abundance as observed count minus estimated false positive,
	                           or do nothing,
	                           default = minus
	
  For taxa annotation (only works with default -tag, -long, and -before-tag):

	-taxonomy TYPE             which taxonomy to use for tag annotation, available:
	                           greengenes, silva
	                           default = silva
	-long FLOAT                a long sequence is called a short tag's representive if
	                           >= FLOAT proportion of the tags have this long sequence
	                           default = 0.7
	-use-long FLOAT            try to use long sequence for annotation for a tag if 
	                           number of samples sharing the same long sequence representative
	                           for the tag / total number of samples >= FLOAT
	                           default = 0.8
	-like                      if no exact tag annotation found in the dictionary,
	                           find alike taxa annotation from tags with one base difference
	</pre>
	<h4>batch.pl</h4>
	<pre>
Usage: batch.pl -in infiles -out outdir -region REGION [options]
     
     -in      the output files from ribotagger.pl
              accepts multiple files, one for each sample
     -out     output directory
     -region  variable regions [v4|v5|v6|v7]
     -prefix  prefix for output files
              default = ribotag
     -name    perl regex to rename your sample names
              default = 's/\.v\d\b//ig'

	</pre>


	</div>
	
<script>
  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

  ga('create', 'UA-4722341-3', 'auto');
  ga('send', 'pageview');

</script>
	</body>
</html>

