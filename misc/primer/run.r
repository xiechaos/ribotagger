#!/usr/bin/env Rscript

freq <- read.table('freq')
colnames(freq) <- c('pos', 'nt', 'count')
library(plyr)
freq <- ddply(freq, 'pos', transform, prop = count / sum(count))
freq <- subset(freq, nt %in% c('A', 'T', 'G', 'C'))
summ <- ddply(freq, 'pos', summarize, count = sum(count))
summ <- subset(summ, count > max(count)/2)
data <- subset(freq, pos %in% summ$pos)

save(data, file = 'primer.rda')

library(seqLogo)
library(reshape)

m <- cast(data, pos ~ nt, value = 'count', fill = 0)
m <- m[order(m$pos), ]
m <- m[, -1]
m <- as.matrix(data.frame(m))
m2 <- apply(m, 1, function(v) v / sum(v))
pdf('logo.pdf', w = 6, h = 2.5)
seqLogo(m2)
dev.off()

m <- cast(data, pos ~ nt, value = 'prop', fill = 0)
m <- m[, -1]
pssm <- log(m/0.25)
pssm <- pssm[, c('A', 'T', 'G', 'C')]
write.table(pssm, col = F, row = F, sep = '\t', file = 'pssm.txt')
