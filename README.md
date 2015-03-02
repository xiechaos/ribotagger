# RiboTagger

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
You need to downaload and unpack the <a href="files/samples.tar.gz">sample data files</a>. You should see 5 fastq files in the "test" folder. 
### Test Runs

```
> mkdir out
> ribotagger.pl -r v4 -i test/samp1.fq -o out/samp1.v4 
```

The structure of the output
```
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
```

The output is a table file with the following fields:
-  *tag*: the tag sequence for the variable region
-  *n*: the number of reads that contains this tag
-  *npos*: the number of different locations of the tag on their source reads (big value of column "n" with small value of "npos" indicates duplicated reads or amplicon sequencing data)
-  *fp*: the number of reads you would expect to see this tag due to sequencing errors alone
-  *long.total.count*: the number of reads containing a longer sequence of this tag (see the -long option)
-  *long1.count*, *long2.count*, *long3.count*: number of reads containing the most abundant variants of this tag's long sequences (low long1.count/long.total.count ratio indicates that this tag is very likely repressenting a mixture of "species")
-  *long1*, *long2*: the most abundant long representive sequences of this tag

If you have more than one files composing one sample (say pair end reads), and you want to make one ribotag report for this sample, you can supply multiple files for the -i or -in option:
```
> ribotagger.pl -r v4 -i test/samp2_1.fq test/samp2_2.fq -o out/samp2.v4 
```

You can also use compressed files as input. Both gzip and bzip2 are supported. However, tar.gz or tar are NOT supported.
```
> ribotagger.pl -r v4 -i test/samp3.fq.gz -o out/samp3.v4
> ribotagger.pl -r v4 -i test/samp4.fq.gz -o out/samp4.v4
```

Make summary table files and a BIOM file for all your four samples:
```
> ls -lh out
	total 252K
	-rw-r--r-- 1 xiechao xiechao 64K 2014-08-23 20:23 samp1.v4
	-rw-r--r-- 1 xiechao xiechao 67K 2014-08-23 20:25 samp2.v4
	-rw-r--r-- 1 xiechao xiechao 57K 2014-08-23 20:26 samp3.v4
	-rw-r--r-- 1 xiechao xiechao 60K 2014-08-23 20:27 samp4.v4

> biom.pl -r v4 -i out/samp*.v4 -o out/my.sample
```

Then you will see 4 files in your out folder:
```
-rw-r--r-- 1 xiechao xiechao  56K 2014-09-04 17:05 my.sample.anno
-rw-r--r-- 1 xiechao xiechao 132K 2014-09-04 17:05 my.sample.biom
-rw-r--r-- 1 xiechao xiechao  16K 2014-09-04 17:05 my.sample.tab
-rw-r--r-- 1 xiechao xiechao  71K 2014-09-04 17:05 my.sample.xls
```

The *.tab file contains the ribotag abundance (raw count) in each sample. 
The *.anno file contains the annotation of each ribotag (only available if you are using default -tag and -long option for ribotagger.pl). The fileds in this file are as follows:
- *tag*: the ribotag sequence
- *use*: "tag" or "long", whether the annotation was based on the short tag or long representive sequence
- *taxon_level*: taxa rank of this annotation of this tag
- *taxon_data*: taxa rank of the most specific annotation appeared in the database (silva or greengenes) for this tag
- *long*: the long representive sequence of this tag
- *long_total*: the number of samples having any long representive sequence
- *long_this*: the number of samples having this long sequence as its major representive of this tag
- *support*: the number of database sequences having this this tag or long sequence
- *confidence*: the proportion of the database sequences agreed on this annotation
- *k, p, c, o, f, g, s*: annotation for each of the taxa ranks - kingdom/domain, phylum, class, order, family, genus, and species
The *.xls file is the combination of the *.tab and *.anno files. <br>
The *.biom file can be used by QIIME. 

From the above files, you can carry on with your usual community profiling routine. For example, PCoA analysis using the provided R script:
```
> pcoa.r out/my.sample.tab out/my.sample.pcoa
```
We also provide a batch script to do all the above steps after ribotagger.pl:
```
batch.pl -r v4 -i out/samp*.v4 -o out/my.sample
```
Then check your folder out/my.sample.

There are many options can be tweaked for both ribotagger.pl and biom.pl (see the last section of this page for detailed references).
Or if you want to use RiboTagger to do more creative things, the following commands for ribotagger.pl might be useful for you:
```
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
```

## Command line options for the main scripts

### ribotagger.pl
```
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
```

### biom.pl
```
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
```

### batch.pl
```
Usage: batch.pl -in infiles -out outdir -region REGION [options]
     
     -in      the output files from ribotagger.pl
              accepts multiple files, one for each sample
     -out     output directory
     -region  variable regions [v4|v5|v6|v7]
     -prefix  prefix for output files
              default = ribotag
     -name    perl regex to rename your sample names
              default = 's/\.v\d\b//ig'

```

