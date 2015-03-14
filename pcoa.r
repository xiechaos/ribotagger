#!/usr/bin/env Rscript

#' # Introduction 
#' Some text


#+ Library, echo=FALSE, message=FALSE, warning=FALSE
library(vegan)
library(ggplot2)
theme_set(theme_bw())
invisible(dev.off())

#+ Arguments, echo=FALSE
args <- commandArgs(T);
if(args[3] == 'knit'){
    in.file <- args[1]
    out.dir <- args[2]
    #in.file <- 'out/my.sample.tab'
    #out.dir <- 'out/my.sample.pcoa'
}else{
    if(length(args) < 2)
    {
        cat("usage: pcoa.r ribotag.tab output.dir\n");
        q()
    }else{
        in.file <- args[1]
        out.dir <- args[2]
    }
}


#+ echo=FALSE, warning=FALSE
dir.create(out.dir)
top                      <- as.numeric(args[4])      # 0..1, default 1
factor                   <- as.numeric(args[5])      # default 10
if(is.na(factor)) factor <- 10

#+ readData, echo=FALSE
table           <- read.delim(in.file, check.names = F)
rownames(table) <- as.character(table[, 1])
table           <- table[, -1, drop = F]


#+ SampleCheck, echo=FALSE
ncols <- ncol(table)
if(ncols < 3)
{
	cat("you must have at least 3 samples to do PCoA analysis\n");
	q()
}

#+ echo=FALSE
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

#' ## PCoA plots

#+ pcoa.12, echo=FALSE, message=FALSE
oneVtwo = qplot(X1, X2, data = pco, label = sample, geom = 'text', size = I(4)) + 
	scale_x_continuous(sprintf("MDS1 (%.2f%%)", explained[1])) + 
	scale_y_continuous(sprintf("MDS2 (%.2f%%)", explained[2]))  
ggsave(oneVtwo, file=sprintf('%s/pcoa.12.pdf', out.dir))
oneVtwo

#+ pcoa.13,echo=FALSE, message=FALSE
if(kdim == 3)
{
	oneVthree <- qplot(X1, X3, data = pco, label = sample, geom = 'text', size = I(4)) +
		scale_x_continuous(sprintf("MDS1 (%.2f%%)", explained[1])) + 
		scale_y_continuous(sprintf("MDS3 (%.2f%%)", explained[3]))  
	ggsave(oneVthree, file=sprintf('%s/pcoa.13.pdf', out.dir))
    oneVthree;
}

#' ## Biplots

#+ pcoa.biplot.12,echo=FALSE, message=FALSE
biplot = ggplot(pco, aes(X1, X2)) + geom_text(aes(label = sample), size = 4)+ 
	scale_x_continuous(sprintf("MDS1 (%.2f%%)", explained[1])) + 
	scale_y_continuous(sprintf("MDS2 (%.2f%%)", explained[2])) +
	geom_segment(aes(xend = 0, yend = 0), U) +
	geom_text(aes(label = tag), subset(U, good), size = 1.5)
ggsave(biplot, file=sprintf('%s/pcoa.biplot.12.pdf', out.dir))
biplot;

#+ pca.biplot.13,echo=FALSE, message=FALSE
if(kdim == 3)
{
	biplot2 <- ggplot(pco, aes(X1, X3)) + geom_text(aes(label = sample), size = 4)+ 
		scale_x_continuous(sprintf("MDS1 (%.2f%%)", explained[1])) + 
		scale_y_continuous(sprintf("MDS3 (%.2f%%)", explained[3])) + 
		geom_segment(aes(xend = 0, yend = 0), U) +
		geom_text(aes(label = tag), subset(U, good), size = 1.5)
    ggsave(biplot2, file=sprintf('%s/pcoa.biplot.13.pdf', out.dir))
    biplot2;
}

#+ saveData, echo=FALSE
save(data, pco, pcoa, U, explained, file = sprintf('%s/data.rda', out.dir))

# echo=FALSE
sessionInfo()
