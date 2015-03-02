#!/usr/bin/env Rscript

library(seqLogo)
load('primer.rda')
library(reshape)
m <- cast(data, pos ~ nt, value = 'count', fill = 0)
m <- m[order(m$pos), ]
m <- m[, -1]
m <- as.matrix(data.frame(m))
m <- m[nrow(m):1, ]
m[,c('A', 'T', 'G', 'C')] <- m[,c('T', 'A', 'C', 'G')]
m2 <- apply(m, 1, function(v) v / sum(v))
pdf('logo.rc.pdf', w = 6, h = 2.5)
seqLogo(m2)
dev.off()

x <- read.table('pssm.txt')
x <- x[nrow(x):1, ]
colnames(x) <- c('A', 'T', 'G', 'C')
x[c('A', 'T', 'G', 'C')] <- x[c('T', 'A', 'C', 'G')]
write.table(x, file = 'pssm.rc.txt', row = F, col = F, sep = '\t')
