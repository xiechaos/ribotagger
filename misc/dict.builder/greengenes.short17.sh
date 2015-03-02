./script/ribo.pl --nnt 17 --print_tag --print_head --nofp -i data/greengenes.microbio.me/greengenes_release/gg_12_10/gg_12_10.fasta -o temp -r v4 > dict/raw/greengenes.v4.short17
./script/dict.builder/greengenes.pl dict/raw/greengenes.v4.short17 > dict/greengenes.short17.v4

./script/ribo.pl --nnt 17 --print_tag --print_head --nofp -i data/greengenes.microbio.me/greengenes_release/gg_12_10/gg_12_10.fasta -o temp -r v5 > dict/raw/greengenes.v5.short17
./script/dict.builder/greengenes.pl dict/raw/greengenes.v5.short17 > dict/greengenes.short17.v5

./script/ribo.pl --nnt 17 --print_tag --print_head --nofp -i data/greengenes.microbio.me/greengenes_release/gg_12_10/gg_12_10.fasta -o temp -r v6 > dict/raw/greengenes.v6.short17
./script/dict.builder/greengenes.pl dict/raw/greengenes.v6.short17 > dict/greengenes.short17.v6

./script/ribo.pl --nnt 17 --print_tag --print_head --nofp -i data/greengenes.microbio.me/greengenes_release/gg_12_10/gg_12_10.fasta -o temp -r v7 > dict/raw/greengenes.v7.short17
./script/dict.builder/greengenes.pl dict/raw/greengenes.v7.short17 > dict/greengenes.short17.v7

