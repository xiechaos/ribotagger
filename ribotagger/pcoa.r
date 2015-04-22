#!/usr/bin/env Rscript

args <- commandArgs(T);
if(length(args) != 2)
{
	cat("usage: pcoa.r ribotag.tab output.dir\n");
	q()
}

library(vegan)
library(ggplot2)
theme_set(theme_bw())

in.file <- args[1]
out.dir <- args[2]
dir.create(out.dir)
top <- as.numeric(args[3]) # 0..1, default 1
factor <- as.numeric(args[4]) # default 10
if(is.na(factor)) factor <- 10

table <- read.delim(in.file, check.names = F)
rownames(table) <- as.character(table[, 1])
table <- table[, -1, drop = F]

ncols <- ncol(table)
if(ncols < 3)
{
	cat("you must have at least 3 samples to do PCoA analysis\n");
	q()
}

prop <- apply(table, 2, function(v) 100 * v / sum(v))

if(!is.na(top))
{
	cum <- prop
	for(i in 1:ncol(cum)){cum <- cum[order(-cum[, i]), ]; cum[, i] <- cumsum(cum[, i]) / sum(cum[, i])}
	cmin <- apply(cum, 1, min)
	good <- names(cmin[cmin <= top])
	prop <- prop[rownames(prop) %in% good, ]
}

data <- prop

di <- vegdist(t(data), method = 'bray')

kdim <- ifelse(ncols <= 3, 2, 3)

pcoa <- cmdscale(di, k = kdim, eig = T)
pco <- data.frame(pcoa$points)
pco$sample <- rownames(pco)
eig <- pcoa$eig

		Y <- t(data)
		plot.axes <- 1:kdim
        n <- nrow(Y)
        points.stand <- scale(pco[, plot.axes])
        S <- cov(Y, points.stand)
        U <- S %*% diag((eig[plot.axes]/(n - 1))^(-0.5))
        colnames(U) <- colnames(pco[, plot.axes])
        U <- data.frame(U)
        U$tag <- rownames(U)
		fact <- max(abs(U[, 1:kdim])) / max(abs(pco[, 1:kdim])) * 2
		U$X1 <- U$X1 / fact
		U$X2 <- U$X2 / fact
		if(kdim == 3) U$X3 <- U$X3 / fact
		U$good <- F
		U[abs(U$X1) >= max(abs(pco$X1))/factor, 'good'] <- T
		U[abs(U$X2) >= max(abs(pco$X2))/factor, 'good'] <- T
		if(kdim == 3) U[abs(U$X3) >= max(abs(pco$X3))/factor, 'good'] <- T

explained <- 100 * eig / sum(eig)

pdf(sprintf('%s/pcoa.12.pdf', out.dir))
qplot(X1, X2, data = pco, label = sample, geom = 'text', size = I(4)) + 
	scale_x_continuous(sprintf("MDS1 (%.2f%%)", explained[1])) + 
	scale_y_continuous(sprintf("MDS2 (%.2f%%)", explained[2]))  
dev.off()

if(kdim == 3)
{
	q <- qplot(X1, X3, data = pco, label = sample, geom = 'text', size = I(4)) +
		scale_x_continuous(sprintf("MDS1 (%.2f%%)", explained[1])) + 
		scale_y_continuous(sprintf("MDS3 (%.2f%%)", explained[3]))  
	pdf(sprintf('%s/pcoa.13.pdf', out.dir))
	print(q)
	dev.off()
}

pdf(sprintf('%s/pcoa.biplot.12.pdf', out.dir))
ggplot(pco, aes(X1, X2)) + geom_text(aes(label = sample), size = 4)+ 
	scale_x_continuous(sprintf("MDS1 (%.2f%%)", explained[1])) + 
	scale_y_continuous(sprintf("MDS2 (%.2f%%)", explained[2])) +
	geom_segment(aes(xend = 0, yend = 0), U) +
	geom_text(aes(label = tag), subset(U, good), size = 1.5)
dev.off()

if(kdim == 3)
{
	q <- ggplot(pco, aes(X1, X3)) + geom_text(aes(label = sample), size = 4)+ 
		scale_x_continuous(sprintf("MDS1 (%.2f%%)", explained[1])) + 
		scale_y_continuous(sprintf("MDS3 (%.2f%%)", explained[3])) + 
		geom_segment(aes(xend = 0, yend = 0), U) +
		geom_text(aes(label = tag), subset(U, good), size = 1.5)
	pdf(sprintf('%s/pcoa.biplot.13.pdf', out.dir))
	print(q)
	dev.off()
}

save(data, pco, pcoa, U, explained, file = sprintf('%s/data.rda', out.dir))
