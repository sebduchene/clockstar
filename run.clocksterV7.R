# Funcions for branch distance score estimation, minimization etc...

# Created Monday October 8 2012
# Sebastian Duchene...
# Modified Fridat November 30 2012:
# NOTES PENDING !!FILL OUT
# Modified Wednesday Nov 28 2012:
# Changed the setwd call at the end of the run.clockster function. This should resolve problems in changing directories.
# Modified Tuesday Nov 27 2012:
# Now all results are saved to a single output file in the data file
# Fixed a bug that was producing this error:
#Warning message:
#In max(dist.to.node) : no non-missing arguments to max; returning -Inf
# this was mainly due to selecting a node to prune that didn't exist. This is commented in function cut.trees.beta in the section of  if(length(taxa.prune)==length(tree$tip.label) & length(tree$tip.label)==3)
# Added <= in funtion get.all.groups
# Fixed a bug that came up when several branches in the dendrogram had thesame length and happened to be the longest

# Modified Monday October 15 2012:
# Trees are scaled for min bds and by mean edge length of both trees = 0.01


# Modified Wednesday October 10 2012:
#		A bug in min.dist.topo has been fixed.
#		optim.edge.weight now outputs a list with the trees and the models selected for each dataset
# 		min.dist.topo now outputs a vector with the minimum branch distance and the corresponding scaling factor
# 		min.dist.topo.mat can now extract all the the values from min.dist.topo and now returns a list with the distances and scaling factors for all pairs of trees.
#		min.dist.topo.mat has been imroved to avoid repetitive estimation





#
require(ape)
require(phangorn)

################################
################################
################################
# Model test for alignments in a directory
################################
################################
################################
optim.edge.lengths <- function(directory, fixed.tree ,form="fasta", model.criteria="BIC", save.trees=F, tree.file.names="output"){
### fasta or nexus
	options(warn=-1)
	directory = paste(directory, "/", sep="")
	file.names <- dir(directory)

	file.names <- file.names[grep(form, file.names)]

	model.table <- matrix(NA, nrow=length(file.names), ncol=3)
	colnames(model.table) <- c("file", model.criteria, "model")
	model.table[,1] <- file.names
	data.files <- list()
	trees.opt <- list()
	print("reading files")
	for(a in 1:length(file.names)){
		data.files[[a]] <- read.dna(paste(directory, file.names[a], sep=""), format=form)
	}

	for(b in 1:length(file.names)){
		tax.keep.temp <- fixed.tree$tip.label %in% rownames(data.files[[b]])
		trees.opt[[b]] <- drop.tip(fixed.tree, as.character(fixed.tree$tip.label[!tax.keep.temp]))
		#Now test the model, save to model.table, and optimize branch lengths and save trees in trees.opt
		pml.temp <- pml(trees.opt[[b]], phyDat(data.files[[b]]),inv=0, shape=1, k=1)
		print(paste("model testing dataset", b, "of", length(file.names)))
		model.temp <-  modelTest(pml.temp, model=c("JC", "F81", "K80", "HKY", "SYM", "GTR"), G = TRUE, I = TRUE)
		model.table[b,2:3] <- c(model.temp$BIC[model.temp$BIC==min(model.temp$BIC)], model.temp$Model[model.temp$BIC==min(model.temp$BIC)])
		best.model.temp <- model.temp$Model[model.temp$BIC==min(model.temp$BIC)]

		if(length(grep("+G" ,best.model.temp))==0 && length(grep("+I", best.model.temp))==0){
			pml.temp <- pml(trees.opt[[b]], phyDat(data.files[[b]]))
			trees.opt[[b]] <- optim.pml(pml.temp, optEdge=T)$tree
		}else if(length(grep("+G", best.model.temp))==1 && length(grep("+I", best.model.temp))==0){
				pml.temp <- pml(trees.opt[[b]], phyDat(data.files[[b]]), optInv=T)
				trees.opt[[b]] <- optim.pml(pml.temp, optEdge=T, optGamma=T)$tree
			}else if(length(grep("+G", best.model.temp))==0 && length(grep("+I", best.model.temp))==1){
				pml.temp <- pml(trees.opt[[b]], phyDat(data.files[[b]]),optGamma=T )
				trees.opt[[b]] <- optim.pml(pml.temp, optEdge=T, optInv=T)$tree
				}else if(length(grep("+G", best.model.temp))==1 && length(grep("+I", best.model.temp))==1){
					pml.temp <- pml(trees.opt[[b]], phyDat(data.files[[b]]), optInv=T, optGamma=T)
					trees.opt[[b]] <- optim.pml(pml.temp, optEdge=T, optGamma=T, optInv=T)$tree
					}
	print(paste("optimized edge lengths for tree", b ,"of", length(file.names)))
	}
	options(warn=1)
	for(i in 1:length(trees.opt)){
			names(trees.opt)[i] <- substr(file.names[i], 1, (nchar(file.names[i])-nchar(form)-1))
	}


	if(save.trees==T){
		print("saving trees")
		for(d in 1:length(trees.opt)){
			write.tree(trees.opt[[d]] , file=paste(tree.file.names,".trees" ,sep=""), append=T)
		}
	}
	l.res <- list()
	l.res[[1]] <- trees.opt
	l.res[[2]] <- model.table
	return(l.res)
}

################################
################################
################################
# Minimize branch score function
################################
################################
################################

min.dist.topo <- function(tree1 , tree2, min.scaling=0.01, max.scaling=20, by.scaling=0.05){

	#This section sets the shortest tree to be rescaled every time. It can be deleted, the min bsd shouldn't change much...
	list.tr <- list()
	list.tr[[1]] <- tree1
	list.tr[[2]] <- tree2
	lens <- c(sum(tree1$edge.length), sum(tree2$edge.length))
	tree1 <- list.tr[lens==max(lens)][[1]]
	tree2 <- list.tr[lens==min(lens)][[1]]

	bdi <- vector()
	scaling <- seq(from=min.scaling, to=max.scaling, by=by.scaling)
	bdi <- sapply(scaling, function(x){tree3 <- tree2 ; tree3$edge.length <- tree2$edge.length*x ; dist.topo(tree1, tree3, method="score")})
	min.bdi <- min(bdi)


	tree2.scaled <- tree2
	tree2.scaled$edge.length <- tree2$edge.length * scaling[bdi==min(bdi)]

	#scaling for mean root height =1
	#	root.scaling <- 1/mean(c(max(branching.times(tree1)),max(branching.times(tree2.scaled))))

	#scaling for mean tree length =1
	#root.scaling <- 1/mean(c(sum(tree1$edge.length) , sum(tree2.scaled$edge.length)))

	#scaling for mean branch length = 0.1 for each tree: a scaling factor is obtained for each tree, where branch lengths are multipled by 1/mean(tr$edge.length)

	#root.scaling.1 <- 0.05/mean(tree1$edge.length)

	#root.scaling.2 <- 0.05/mean(tree2.scaled$edge.length)


	#scaling for mean branch length of the two trees = 0.05: A single scaling facor is obtained to multiply both trees

	root.scaling <- 0.05/mean(c(tree1$edge.length[tree1$edge.length>0.00001] , tree2.scaled$edge.length[tree2.scaled$edge.length>0.00001]))
	#Now only non 0 branch lengths are taken into account when calculating the mean branch length this is because these affect the scaling but not the actual bsd values

	tree1.root.scaled <- tree1
	tree2.root.scaled <- tree2.scaled


	tree1.root.scaled$edge.length <- tree1$edge.length * root.scaling
	tree2.root.scaled$edge.length <- tree2.scaled$edge.length * root.scaling


	min.bdi.root.scaled <- dist.topo(tree1.root.scaled, tree2.root.scaled, method="score")


	# NON VECTORIZED IMPLEMENTATION OF THE MIN BDI ESTIMATION
	#for(a in 1:length(scaling)){
	#	tree3 <- tree2
	#	tree3$edge.length <- tree2$edge.length*scaling[a]
	#	bdi[a] <- 	dist.topo(tree1, tree3, method="score")
	#}

	#res.list <- list()
	#res.list[[1]] <- scaling[bdi==min(bdi)]
	#res.list[[2]] <- min(bdi)


	res.vect <- c(min.bdi.root.scaled , scaling[bdi==min(bdi)], min.bdi)
	#return(res.vect)

	#return(bdi)


}
################################
################################
################################
# Estimate minimun branch score for a list of trees
################################
################################
################################

min.dist.topo.mat <- function(tree.list){

	d.mat <- matrix(NA, nrow=length(tree.list), ncol=length(tree.list))
	rownames(d.mat) <- names(tree.list)
	colnames(d.mat) <- names(tree.list)

	s.mat <- d.mat
	print("Estimating tree distances")

#	for(a in 1:nrow(d.mat)){ # NON VECTORIZED IMPLEMENTATION OF THE CODE BELLOW
#		tr <- tree.list[[a]]
#		d.mat[a,] <- unlist(lapply(tree.list, function(y){min.dist.topo(tree1=y, tree2=tr)}))
	#print(paste("executing row", a))
#		}
	if(length(tree.list) >2){
		d.mat.lin <- vector()
		d.mat.lin <- sapply(2:nrow(d.mat), function(a){print(paste("estimating distances",a-1, "of", nrow(d.mat)-1)); lapply(tree.list[1:(a-1)], function(y){min.dist.topo(tree1=y, tree2=tree.list[[a]]) })  })

		for(a in 1:length(d.mat.lin)){
			vec.temp.dist <- vector()
			vec.temp.scale <- vector()
			for(b in 1:length(d.mat.lin[[a]])){
				vec.temp.dist[b] <- d.mat.lin[[a]][[b]][1]
				vec.temp.scale[b] <- d.mat.lin[[a]][[b]][2]
			}
			d.mat[a+1,1:length(vec.temp.dist)] <- vec.temp.dist
			s.mat[a+1,1:length(vec.temp.dist)] <- vec.temp.scale
		}


		}else if(length(tree.list)==2){
			d.mat.lin <- min.dist.topo(tree.list[[1]], tree.list[[2]])
			d.mat[2,1] <- d.mat.lin[1]
			s.mat[2,1] <-  d.mat.lin[2]
		}else{
			print("there was only one tree in the list or the objects are not of class 'phylo'")
		}
		res.list <- list()
		res.list[[1]] <- as.dist(d.mat)
		res.list[[2]] <- s.mat

		return(res.list)

}





#######function to convert to fasta format

convert.to.fasta <- function(directory){
	d <- getwd()
	setwd(directory)
	files <- grep(".nex", dir(directory), value=T)
	for(i in 1:length(files)){
	file.temp <- read.nexus.data(files[i])
	write.dna(as.DNAbin(file.temp),file=paste(substr(files[i], 1,nchar(files[i])-4), ".fasta", sep=""),  format="fasta", nbcol=-1, colsep="")
	system(paste("rm", files[i]))
	setwd(d)
	}
}
###################

# Implementation of clustering algorithm for nj clustering

library(ape)
library(geiger)
# VERSION 7 OF cut.trees.beta function
cut.trees.beta <- function(tree, beta=0.05){
	# Calculate tree diameter
	if(length(tree$tip.label)>=3){
		tree <- unroot(tree)
   }
    tree.diam <- max(cophenetic(tree))

	# Create a list to store the pruned trees
    pruned.trees <- list()
	# If the diameter of the input tree is larger than beta, and it has more than 2 tips
    if(tree.diam>beta & (length(tree$tip.label)>2)){


#############################################
#############################################

di.nodes <- dist.nodes(tree)
max.edge <- max(tree$edge.length)

tips <- 1:length(tree$tip.label)
nodes <- 1:nrow(di.nodes)
nodes <- nodes[-tips]

connect.longest.edge <- which(di.nodes==max.edge, arr.ind=T)[1,]

if((connect.longest.edge[1] %in% nodes) & (connect.longest.edge[2] %in% nodes)){#If it is a node - node connection
	#in this case get the node.leaves from both the nodes and pick the one with the fewest. This should get around problems when the chosen node is at the base of the tree
	taxa.cut1 <- node.leaves(tree, connect.longest.edge[1])
	taxa.cut2 <- node.leaves(tree, connect.longest.edge[2])
	len.tax <- c(length(taxa.cut1), length(taxa.cut2))
	node.cut <- connect.longest.edge[len.tax==min(len.tax)]
	taxa.cut <- node.leaves(tree, node.cut)
	#node.cut <- connect.longest.edge[1]
	#taxa.cut <- node.leaves(tree, node.cut)

}else if(sum(connect.longest.edge %in% nodes)==1){#If it is a node - tip connection
	node.cut <- connect.longest.edge[connect.longest.edge %in% nodes]
	taxa.cut <- tree$tip.label[connect.longest.edge[connect.longest.edge %in% tips]]
}

taxa.prune <- taxa.cut

#############################################
#############################################

# HERE ENDS THE SECTION FOR SELECTING THE NODE AND TAXA TO BE PRUNED
		# After defining the tips to be pruned, create the subtree1. If the number of tips left is >=2
		# then this works just by pruning out the taxa. Otherwise an the object is the tip labels left
        if((length(tree$tip.label)-length(taxa.prune))>=2){
            subtree1 <- drop.tip(tree, taxa.prune)
            if(length(subtree1$tip.label)>=3){
	           	subtree1 <- unroot(subtree1)
  	         }
        }else{
            subtree1 <- tree$tip.label[!(tree$tip.label %in% taxa.prune)]
        }
		# Create the second subtree2 which is the tips that were not included in subtree1
        if(length(taxa.prune) >= 2){
            subtree2 <- drop.tip(tree, tree$tip.label[!(tree$tip.label %in% taxa.prune)])
            if(length(subtree2$tip.label)>=3){
            	subtree2 <- unroot(subtree2)
            }
#
        }else{
            subtree2 <- taxa.prune
        }

        pruned.trees[[1]] <- subtree1
        pruned.trees[[2]] <- subtree2

    }else if(tree.diam < beta){
        pruned.trees[[1]] <- tree
    }else{
    	pruned.trees[[1]] <- tree$tip.label[1]
    	pruned.trees[[2]] <- tree$tip.label[2]
    }
    return(pruned.trees)
}
#END cut.trees.beta funciton version 7
####################
#################### START
#NEW FUNCTION TO RUN CLOCKSTAR IN K MODE (AS OPPOSED TO BEATA MODE)
####################
####################
####################
get.all.groups.k <- function(tree, k=2, save.partitions=F, file.name="partitions.txt"){
tree.list <- list()
tree.list[[1]] <- tree
while(length(tree.list) < k){
	diams <- sapply(tree.list, function(tr){if(class(tr)=="phylo"){ return(max(cophenetic(tr)))}else{return(0)}})
	tree.to.cut <- tree.list[[which(diams==max(diams))]]
	tree.list <- tree.list[-which(diams==max(diams))]
	tree.list[c(length(tree.list)+1,length(tree.list)+2)] <- cut.trees.beta(tree.to.cut, beta=0)
}
for(l in 1:length(tree.list)){
	if(class(tree.list[[l]])=="phylo"){
    	tips <- tree.list[[l]]$tip.label
        tree.list[[l]] <- tips
    }
}
names(tree.list) <- paste("Partition_", 1:length(tree.list))

if(save.partitions==T){
	cat(paste("partitions with selected k =", k, "\n"), file=file.name)
    	for(m in 1:length(tree.list)){
	    	cat(names(tree.list[m]), file=file.name, sep="\n",append=T)
	    	cat(tree.list[[m]], file=file.name,append=T)
	    	cat("\n", file=file.name,append=T)
    	}
    }
    return(tree.list)
}
####################
#################### END
#NEW FUNCTION TO RUN CLOCKSTAR IN K MODE (AS OPPOSED TO BEATA MODE)
####################
####################
####################
####################
####################
####################
####################
get.all.groups <- function(tree, beta=0.05, save.partitions=F, file.name="partitions.txt"){
    temp.list <- list()
    min.list <- list()

    temp.list[[1]] <- tree

    get.diameter <- function(tr){if(class(tr)=="phylo"){return(max(cophenetic(tr)))}else{return(0) }}
    diams <- sapply(temp.list, get.diameter) #get diameter for all trees in temp.list

    if(any(diams>beta)){
        while(length(temp.list)!=0){
            #######
            #####

            diams <- sapply(temp.list, get.diameter) #get diameter for all trees in temp.list

            if(sum(diams <= beta)>0){# If any of the trees have a diameter <= beta then these are saved in min.list
                diams.beta <- seq(from=1, to=length(diams))[diams <= beta]
                for(i in diams.beta){
                    min.list[[length(min.list)+1]] <- temp.list[[i]]
                }
            }else{
                diams.beta=0
            }# If no trees have diameters < beta, then diams.beta  <- 0

            if(sum(diams > beta)>0){
                diams.non.beta <-  seq(from=1, to=length(diams))[diams > beta]
                temp.list.non.beta <- list()# If any trees have diamters> beta create temp.list.non.beta

                for(j in 1:length(diams.non.beta)){
                    temp.list.non.beta[[j]] <- temp.list[[diams.non.beta[j]]]
                }#save all the trees with diameter > beta to temp.list (rewrite temp.list)
                temp.list <- temp.list.non.beta

                sub.list <- list()#create a sublist to store all the cut trees

        ######
        #######

                for(k in 1:length(temp.list)){
                    cut.temp <- cut.trees.beta(temp.list[[k]], beta)
                    sub.list[[length(sub.list)+1]] <- cut.temp[[1]]
                    if(length(cut.temp)==2){
                        sub.list[[length(sub.list)+1]] <- cut.temp[[2]]
                    }
                }

                temp.list=sub.list[1:length(sub.list)]



            }else{
                temp.list <- list()
            }

        }

    # Format the output list so that it only contains the partition names


    }else{
        min.list <- temp.list
    }
        for(l in 1:length(min.list)){
        	if(class(min.list[[l]])=="phylo"){
            	tips <- min.list[[l]]$tip.label
            	min.list[[l]] <- tips
        	}

    	}
    	names(min.list) <- paste("Partition_", 1:length(min.list))

    	if(save.partitions==T){
    		cat(paste("partitions with selected beta =", beta, "\n"), file=file.name)
    		for(m in 1:length(min.list)){
	    		cat(names(min.list[m]), file=file.name, sep="\n",append=T)
	    		cat(min.list[[m]], file=file.name,append=T)
	    		cat("\n", file=file.name,append=T)
    		}
    	}

    return(min.list)
}

##############################






run.clockster <- function(files.directory ,mode.run="k", k=2, beta.min=0.1,...){


 	files <- dir(files.directory)
	files.format <- files[-grep(".tre", files)][1]
	files.format <- substr(files.format, regexpr("[.]", files.format)[1]+1,nchar(files.format))

	if(files.format=="nex"){
    	convert.to.fasta(files.directory)
	}

        # We now want all the output into a single file. This may only work in unix-like OS
        init.dir <- getwd()
        setwd(files.directory)
        system("mkdir clockstar.output")
        setwd("./clockstar.output")


	fix.tree <- read.tree(paste(files.directory, files[grep(".tre", files)[1]], sep="/"))
	fix.tree$edge.length <- runif(length(fix.tree$tip.label)*2-1)
	print("OPTIMISING BRANCH LENGTHS")
	opt.trees <- optim.edge.lengths(files.directory, fix.tree, save.trees=T, tree.file.names="optimized")
	write.table(opt.trees[[2]], file="models.csv" ,sep=",", row.names=F)
	opt.trees.only <- opt.trees[[1]]
	print("FINISHED OPTIMISING BRANCH LENGTHS")
	print("CALCULATING BSD")
	bsd.matrix <- min.dist.topo.mat(opt.trees.only)
	print("FINISHED CALCULATING BSD")
	write.table(as.matrix(bsd.matrix[[1]]), file="bsd.distances.csv", sep=",")
	write.table(as.matrix(bsd.matrix[[2]]), file="scaling.factors.csv", sep=",")

	#some data manipulation to bypass errors generated in 2 partition analyses
	if(ncol(bsd.matrix[[2]]) > 2){
		bsd.dendrogram <- nj(bsd.matrix[[1]])
		write.tree(bsd.dendrogram, file="bsd.dendrogram.tre")
	}else if(ncol(bsd.matrix[[2]])==2){
		bsd.matrix[[1]] <- as.matrix(bsd.matrix[[1]])
		bsd.matrix[[1]] <- cbind(c(0.5, 0.5), bsd.matrix[[1]])
		bsd.matrix[[1]] <- rbind(c(0.5,0.5, 0.5), bsd.matrix[[1]])
		colnames(bsd.matrix[[1]])[1] <- 3
		rownames(bsd.matrix[[1]])[1] <- 3
		bsd.matrix[[1]] <- as.dist(bsd.matrix[[1]])
		bsd.dendrogram <- nj(bsd.matrix[[1]])
		bsd.dendrogram <- drop.tip(bsd.dendrogram, "3")
		write.tree(bsd.dendrogram, file="bsd.dendrogram.tre")
	}else{
		print("ERROR IN DENDROGRAM OF TREE DISTANCES")
	}

	print("CALCULATING NUMBER OF GROUPS")
	if(mode.run=="beta"){
       	groups <- get.all.groups(bsd.dendrogram, beta=beta.min, save.partitions=T)
	}else if(mode.run=="k"){
		groups <- get.all.groups.k(bsd.dendrogram, k=k, save.partitions=T)
	}
	print("FINISHED CALCULATING NUMBER OF GROUPS")
	#for multiple values of K
	print("CALCULATING K FOR DIFFERENT VALUES OF BETA")
	k <- vector()
	beta.expe <- seq(from=beta.min/10, to=beta.min*10, by=0.001)

	for(i in 1:length(beta.expe)){
    	k[i] <- length(get.all.groups(bsd.dendrogram, beta=beta.expe[i]))
    	print(paste("Estimating groups for values of", beta.expe[i]))
	}
	print("PLOTTING")

	#Now plotting all the above

	pdf("bsd.plots.pdf")
	par(mfrow=c(3,1))
	hist(as.dist(bsd.matrix[[1]]), xlab="BSD", main="Histogram for BSD", freq=T)
	plot(bsd.dendrogram, "unrooted", main="Dendrogram of BSD among partitions")
	plot(beta.expe, k, type="l", xlab="Beta", ylab="K", main="K groups for Beta values")
	dev.off()
	setwd(init.dir)
	print("FINISHED RUN")
}
