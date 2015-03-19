library(ggplot2)
theme_set(theme_bw(base_size = 8))
library(scales)
library(plyr)

n <- 5

v4 <- read.delim('dict/greengenes.tag.v4', h = F)
colnames(v4) <- c('tag', 'all', 'total', 'major', 'rank', 'consistent', 'taxa', 'lineage', 'taxa.total')
v4$region <- 'v4'

v4$rank <- factor(v4$rank, level = c('domain', 'phylum', 'class', 'order', 'family', 'genus', 'species'))
ddply(v4, .(rank), summarize, all.100 = sum(major == total)/length(total), gn.100 = sum(major == total & total >= n)/sum(total >= n), all.99 = sum(major/total>=0.99)/length(total), gn.99 = sum(major/total>=0.99 & total>=n)/sum(total>=n))

pdf('concordance.greengenes.v4.pdf', pointsize = 8, w = 5, h = 2)
qplot(major / total, 
	data = subset(v4, major/total >= 0.95 & total >= n & rank %in% c('family', 'genus', 'species')), 
	xlab = 'Tag assignment concordance rate (Not showing tags with concordance rate < 95%)',
	ylab = 'Number of tags',
	geom = 'histogram', 
	colour = I('white'), size = I(0.2), 
	breaks = seq(0.95, 1, by = 0.002)
	) + 
	scale_x_continuous(label = percent) +
	facet_wrap(~rank, scale = 'free_y', ncol = 3) 
dev.off()
pdf('concordance.greengenes.v4.left.pdf', pointsize = 8, w = 5, h = 2)
qplot(major / total, 
	data = subset(v4, major/total < 1 & total >= n & rank %in% c('family', 'genus', 'species')), 
	xlab = 'Tag assignment concordance rate (Not showing tags with concordance rate of 100%)',
	ylab = 'Number of tags',
	geom = 'histogram', 
	colour = I('white'), size = I(0.2), 
	breaks = seq(0.2, 1, by = 0.03)
	) + 
	scale_x_continuous(label = percent) +
	facet_wrap(~rank, scale = 'free_y', ncol = 3) 
dev.off()

v5 <- read.delim('dict/greengenes.tag.v5', h = F)
colnames(v5) <- c('tag', 'all', 'total', 'major', 'rank', 'consistent', 'taxa', 'lineage', 'taxa.total')
v5$region <- 'v5'

v5$rank <- factor(v5$rank, level = c('domain', 'phylum', 'class', 'order', 'family', 'genus', 'species'))
ddply(v5, .(rank), summarize, all.100 = sum(major == total)/length(total), gn.100 = sum(major == total & total >= n)/sum(total >= n), all.99 = sum(major/total>=0.99)/length(total), gn.99 = sum(major/total>=0.99 & total>=n)/sum(total>=n))

pdf('concordance.greengenes.v5.pdf', pointsize = 8, w = 5, h = 2)
qplot(major / total, 
	data = subset(v5, major/total >= 0.95 & total >= n & rank %in% c('family', 'genus', 'species')), 
	xlab = 'Tag assignment concordance rate (Not showing tags with concordance rate < 95%)',
	ylab = 'Number of tags',
	geom = 'histogram', 
	colour = I('white'), size = I(0.2), 
	breaks = seq(0.95, 1, by = 0.002)
	) + 
	scale_x_continuous(label = percent) +
	facet_wrap(~rank, scale = 'free_y', ncol = 3) 
dev.off()
pdf('concordance.greengenes.v5.left.pdf', pointsize = 8, w = 5, h = 2)
qplot(major / total, 
	data = subset(v5, major/total < 1 & total >= n & rank %in% c('family', 'genus', 'species')), 
	xlab = 'Tag assignment concordance rate (Not showing tags with concordance rate of 100%)',
	ylab = 'Number of tags',
	geom = 'histogram', 
	colour = I('white'), size = I(0.2), 
	breaks = seq(0.2, 1, by = 0.03)
	) + 
	scale_x_continuous(label = percent) +
	facet_wrap(~rank, scale = 'free_y', ncol = 3) 
dev.off()

v6 <- read.delim('dict/greengenes.tag.v6', h = F)
colnames(v6) <- c('tag', 'all', 'total', 'major', 'rank', 'consistent', 'taxa', 'lineage', 'taxa.total')
v6$region <- 'v6'

v6$rank <- factor(v6$rank, level = c('domain', 'phylum', 'class', 'order', 'family', 'genus', 'species'))
ddply(v6, .(rank), summarize, all.100 = sum(major == total)/length(total), gn.100 = sum(major == total & total >= n)/sum(total >= n), all.99 = sum(major/total>=0.99)/length(total), gn.99 = sum(major/total>=0.99 & total>=n)/sum(total>=n))

pdf('concordance.greengenes.v6.pdf', pointsize = 8, w = 5, h = 2)
qplot(major / total, 
	data = subset(v6, major/total >= 0.95 & total >= n & rank %in% c('family', 'genus', 'species')), 
	xlab = 'Tag assignment concordance rate (Not showing tags with concordance rate < 95%)',
	ylab = 'Number of tags',
	geom = 'histogram', 
	colour = I('white'), size = I(0.2), 
	breaks = seq(0.95, 1, by = 0.002)
	) + 
	scale_x_continuous(label = percent) +
	facet_wrap(~rank, scale = 'free_y', ncol = 3) 
dev.off()
pdf('concordance.greengenes.v6.left.pdf', pointsize = 8, w = 5, h = 2)
qplot(major / total, 
	data = subset(v6, major/total < 1 & total >= n & rank %in% c('family', 'genus', 'species')), 
	xlab = 'Tag assignment concordance rate (Not showing tags with concordance rate of 100%)',
	ylab = 'Number of tags',
	geom = 'histogram', 
	colour = I('white'), size = I(0.2), 
	breaks = seq(0.2, 1, by = 0.03)
	) + 
	scale_x_continuous(label = percent) +
	facet_wrap(~rank, scale = 'free_y', ncol = 3) 
dev.off()

v7 <- read.delim('dict/greengenes.tag.v7', h = F)
colnames(v7) <- c('tag', 'all', 'total', 'major', 'rank', 'consistent', 'taxa', 'lineage', 'taxa.total')
v7$region <- 'v7'

v7$rank <- factor(v7$rank, level = c('domain', 'phylum', 'class', 'order', 'family', 'genus', 'species'))
ddply(v7, .(rank), summarize, all.100 = sum(major == total)/length(total), gn.100 = sum(major == total & total >= n)/sum(total >= n), all.99 = sum(major/total>=0.99)/length(total), gn.99 = sum(major/total>=0.99 & total>=n)/sum(total>=n))

pdf('concordance.greengenes.v7.pdf', pointsize = 8, w = 5, h = 2)
qplot(major / total, 
	data = subset(v7, major/total >= 0.95 & total >= n & rank %in% c('family', 'genus', 'species')), 
	xlab = 'Tag assignment concordance rate (Not showing tags with concordance rate < 95%)',
	ylab = 'Number of tags',
	geom = 'histogram', 
	colour = I('white'), size = I(0.2), 
	breaks = seq(0.95, 1, by = 0.002)
	) + 
	scale_x_continuous(label = percent) +
	facet_wrap(~rank, scale = 'free_y', ncol = 3) 
dev.off()
pdf('concordance.greengenes.v7.left.pdf', pointsize = 8, w = 5, h = 2)
qplot(major / total, 
	data = subset(v7, major/total < 1 & total >= n & rank %in% c('family', 'genus', 'species')), 
	xlab = 'Tag assignment concordance rate (Not showing tags with concordance rate of 100%)',
	ylab = 'Number of tags',
	geom = 'histogram', 
	colour = I('white'), size = I(0.2), 
	breaks = seq(0.2, 1, by = 0.03)
	) + 
	scale_x_continuous(label = percent) +
	facet_wrap(~rank, scale = 'free_y', ncol = 3) 
dev.off()
