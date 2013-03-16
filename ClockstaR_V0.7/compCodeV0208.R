# Created Feb 8 2013
# A test for a user friendly version of clockstar
#First load clockstar in R
source("/Users/sebastianduchene/Dropbox/BRScore/ClockstaR_V0.7/run.clocksterV7.R")

#Once clockstar is loaded the following functions are available:
#[1] "convert.to.fasta"   "cut.trees.beta"     "get.all.groups"
#[4] "get.all.groups.k"   "min.dist.topo"      "min.dist.topo.mat"
#[7] "optim.edge.lengths" "run.clockster"


# readline() gives user a prompt to input data as text
# To run in batch mode:
# An input file such as this can be used:

                                        #tr <- commandArgs(TRUE)
#print(paste(tr, "srhgwsg"))
#fil <- file.choose()
#writeLines(paste(tr, "sgrda"), con="our.R.prommpt.txt")

                                        # And run like this:
#R CMD BATCH '--args add_Arguments_Here' name_of_output_file
# This will produce an output file called name_of_output_file with the lines written in it


# Ideally the user can input a number of things:
# Parameters file
# Folder with the alignments for eaach partition
# Tree

# For the parameters file

# Mode to run clockstar (full with k or beta, only for a fixed k, several values of k)
# value or values for K (if being run in k mode)
# output files name
# partitions file name



