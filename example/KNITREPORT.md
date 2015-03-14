To generate PCOA report run the following within the examples folder


Tested with the following package versions
* Knitr knitr_1.9.4
* rgl rgl_0.95.1227

```
Rscript -e “library(knitr); knit_hooks\$set(webgl = hook_webgl); opts_knit\$set(root.dir=getwd()); spin(‘../pcoa.r’)” out/my.sample.tab out/my.sample.pcoa knit
```
