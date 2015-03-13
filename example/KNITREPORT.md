To generate PCOA report run the following within the examples folder

```
Rscript -e “library(knitr); opts_knit\$set(root.dir=getwd()); spin(‘../pcoa.r’)” out/my.sample.tab out/my.sample.pcoa knit
```
