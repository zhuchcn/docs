## ---------------------------------------------------------
library(stringr);library(reshape2);library(plyr);library(dplyr)
library(dada2); library(Biostrings);library(tibble)
## ---------------------------------------------------------
rm(list=ls())
setwd("/Users/chenghaozhu/sequence_data/FF/fastq")
load('dada2_v16/dada2_run.Rdata') # this is the Rdata saved after dada2.

## ---------------------------------------------------------
samples.out <- rownames(seqtab.nochim)

pdata = read.table("2017_AZ_map_FF_final.txt",header=T, comment.char = "",
                   sep="\t",stringsAsFactors = F)
pdata = column_to_rownames(pdata, 'SampleID')
pdata = pdata[samples.out,]

## --------------------------------------------------------
seqs = DNAStringSet(colnames(seqtab.nochim))
edata = as.matrix(t(seqtab.nochim))
edata = as.data.frame(edata)
rownames(edata) = NULL
fdata = as.data.frame(taxa)
rownames(fdata) = NULL

## ------------------ collapse rc -------------------------
#
# Because of the way that our samples were prepared and sequenced, some 
# sequences have barcodes at the 5' end, and some sequences have barcodes at 
# the 3' end. That means for the same species, some of its sequence are 
# oriented normally, but some of them are reversed complement. This defined
# will look through all feature sequences generated by dada2, and look for the 
# reverse complement sequence. If the reverse complement sequence is also
# picked up by dada2 as a feature, it will combine the 2 features as one.
#
collapse_rc = function(data){
    edata = data$edata
    pdata = data$pdata
    fdata = data$fdata
    seqs = data$seqs
    
    edata_2 = NULL
    fdata_2 = NULL
    seqs_2 = DNAStringSet()
    
    for(i in 1:length(seqs)){
        if (!reverseComplement(seqs[i]) %in% seqs){ # if RC isn't a feature
            
            edata_2 = rbind(edata_2, edata[i,])
            fdata_2 = rbind(fdata_2, fdata[i,])
            seqs_2 = c(seqs_2, seqs[i])
            
        } else{ # if RC is a feature
            iloc_rc = which(seqs == reverseComplement(seqs[i]))
            if(!seqs[i] %in% seqs_2 & !seqs[iloc_rc] %in% seqs_2){
                # if not feature i or rc alrday in new data
                if(sum(is.na(fdata[i,])) <= sum(is.na(fdata[iloc_rc,]))){
                    edata_2 = rbind(edata_2, edata[i,] + edata[iloc_rc,])
                    seqs_2 = c(seqs_2, seqs[i])
                    fdata_2 = rbind(fdata_2, fdata[i,])
                }else{
                    edata_2 = rbind(edata_2, edata[iloc_rc,] + edata[i,])
                    seqs_2 = c(seqs_2, seqs[iloc_rc])
                    fdata_2 = rbind(fdata_2, fdata[iloc_rc,])
                }
            }
        }
    }
    return(list(edata=edata_2, fdata=fdata_2, seqs=seqs_2, pdata=pdata))
}

data = collapse_rc(list(edata=edata, pdata=pdata, fdata=fdata, seqs=seqs))

## --------- remove features with abnormal length ---------
#
# This function removes features with abnormal length. Sequences that are too 
# short are mostly those with their R1 and R2 failed to merge. Sequences that 
# are too long are also something similar.
#
filterByLength = function(data, lower=220, upper=260){
    edata=data$edata
    pdata=data$pdata
    fdata=data$fdata
    seqs=data$seqs
    
    features_to_keep=which(width(seqs)>=lower & width(seqs)<=upper)
    edata = edata[features_to_keep,]
    fdata = fdata[features_to_keep,]
    seqs = seqs[features_to_keep]
    return(list(edata=edata,fdata=fdata,pdata=pdata,seqs=seqs))
}
data = filterByLength(data)

edata = data$edata
fdata = data$fdata
pdata = data$pdata
seqs = data$seqs
## --------------------------------------------------------
names(seqs) = str_pad(1:length(seqs), width = 4, pad='0')
rownames(edata) = names(seqs)
edata = rownames_to_column(edata, var = 'feature_id')
rownames(fdata) = names(seqs)
fdata = rownames_to_column(fdata, var = 'feature_id')
pdata = rownames_to_column(pdata, var='sample_id')

writeXStringSet(seqs, "dada2_v16/rep_seqs.fasta", format='fasta', width=10000)
write.table(edata,file="dada2_v16/feature_table.tsv",sep="\t",
            col.names=T,row.names=F,quote=F)
write.table(fdata,file="dada2_v16/taxonomy.tsv",sep="\t",
            col.names=T,row.names=F,quote=F)
write.table(pdata,file='dada2_v16/sample_metadata.tsv',sep='\t',
            col.names=T,row.names = F, quote=F)
