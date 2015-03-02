#!/usr/bin/env Rscript

args <- as.numeric(commandArgs(T));
load('primer.rda')
library(plyr)
cuts <- args[1]
primer <- paste('[', ddply(data, 'pos', summarize, nt = paste(nt[prop >= cuts], collapse = ''))$nt, ']', sep = '', collapse = '')
print(primer)
