#./script/ribotagger.pl --print-tag --print-head --se 0 -i data/gg_13_5/gg_13_5.fasta.gz -o temp -r v4 > dict/raw/greengenes.v4
#./script/dict.builder/greengenes.pl dict/raw/greengenes.v4 > dict/greengenes.tag.v4
#./script/ribotagger.pl --print-long --print-head --se 0 -i data/gg_13_5/gg_13_5.fasta.gz -o temp -r v4 > dict/raw/greengenes.v4.long
#./script/dict.builder/greengenes.pl dict/raw/greengenes.v4.long > dict/greengenes.long.v4
#
#./script/ribotagger.pl --print-tag --print-head --se 0 -i data/gg_13_5/gg_13_5.fasta.gz -o temp -r v5 > dict/raw/greengenes.v5
#./script/dict.builder/greengenes.pl dict/raw/greengenes.v5 > dict/greengenes.tag.v5
#./script/ribotagger.pl --print-long --print-head --se 0 -i data/gg_13_5/gg_13_5.fasta.gz -o temp -r v5 > dict/raw/greengenes.v5.long
#./script/dict.builder/greengenes.pl dict/raw/greengenes.v5.long > dict/greengenes.long.v5
#
#./script/ribotagger.pl --print-tag --print-head --se 0 -i data/gg_13_5/gg_13_5.fasta.gz -o temp -r v6 > dict/raw/greengenes.v6
#./script/dict.builder/greengenes.pl dict/raw/greengenes.v6 > dict/greengenes.tag.v6
#./script/ribotagger.pl --print-long --print-head --se 0 -i data/gg_13_5/gg_13_5.fasta.gz -o temp -r v6 > dict/raw/greengenes.v6.long
#./script/dict.builder/greengenes.pl dict/raw/greengenes.v6.long > dict/greengenes.long.v6
#
#./script/ribotagger.pl --print-tag --print-head --se 0 -i data/gg_13_5/gg_13_5.fasta.gz -o temp -r v7 > dict/raw/greengenes.v7
#./script/dict.builder/greengenes.pl dict/raw/greengenes.v7 > dict/greengenes.tag.v7
#./script/ribotagger.pl --print-long --print-head --se 0 -i data/gg_13_5/gg_13_5.fasta.gz -o temp -r v7 > dict/raw/greengenes.v7.long
#./script/dict.builder/greengenes.pl dict/raw/greengenes.v7.long > dict/greengenes.long.v7
#

./script/dict.builder/lite.pl dict/greengenes.tag.v4 > script/dict/greengenes.tag.v4
./script/dict.builder/lite.pl dict/greengenes.tag.v5 > script/dict/greengenes.tag.v5
./script/dict.builder/lite.pl dict/greengenes.tag.v6 > script/dict/greengenes.tag.v6
./script/dict.builder/lite.pl dict/greengenes.tag.v7 > script/dict/greengenes.tag.v7
./script/dict.builder/lite.pl dict/greengenes.long.v4 > script/dict/greengenes.long.v4
./script/dict.builder/lite.pl dict/greengenes.long.v5 > script/dict/greengenes.long.v5
./script/dict.builder/lite.pl dict/greengenes.long.v6 > script/dict/greengenes.long.v6
./script/dict.builder/lite.pl dict/greengenes.long.v7 > script/dict/greengenes.long.v7
