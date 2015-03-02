./script/ribo.pl --long 60 --print_long --print_head --nofp -i data/greengenes.microbio.me/greengenes_release/gg_12_10/gg_12_10.fasta -o temp -r v4 > dict/raw/greengenes.v4.long60
./script/dict.builder/greengenes.pl dict/raw/greengenes.v4.long60 > dict/greengenes.long60.v4

./script/ribo.pl --long 60 --print_long --print_head --nofp -i data/greengenes.microbio.me/greengenes_release/gg_12_10/gg_12_10.fasta -o temp -r v5 > dict/raw/greengenes.v5.long60
./script/dict.builder/greengenes.pl dict/raw/greengenes.v5.long60 > dict/greengenes.long60.v5

./script/ribo.pl --long 60 --print_long --print_head --nofp -i data/greengenes.microbio.me/greengenes_release/gg_12_10/gg_12_10.fasta -o temp -r v6 > dict/raw/greengenes.v6.long60
./script/dict.builder/greengenes.pl dict/raw/greengenes.v6.long60 > dict/greengenes.long60.v6

./script/ribo.pl --long 60 --print_long --print_head --nofp -i data/greengenes.microbio.me/greengenes_release/gg_12_10/gg_12_10.fasta -o temp -r v7 > dict/raw/greengenes.v7.long60
./script/dict.builder/greengenes.pl dict/raw/greengenes.v7.long60 > dict/greengenes.long60.v7

