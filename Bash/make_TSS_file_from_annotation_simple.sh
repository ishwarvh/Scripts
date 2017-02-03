#!/bin/bash

# make_TSS_file_from_annotation_simple.sh
# same as make_TSS_file_from_annotation_with_confidence_better.sh
# except that does not include tr biotype neither confidence and is made for any gtf file
# not necesarily gencode
# - it only takes as input an annotation gtf file
# - it produces files where the program is launched
# - important differences with make_TSS_file_from_annotation_with_confidence_better.sh is that it writes the gene id and tr id
#   surrounded by double quotes and ending with semi colon as in the annotation, it only considers exons that are stranded!!!
#   and also the output file is named a bit differently ($annotbase\_capped_sites_nr.gff)

# Be careful: this script cannot be launched several times in the same directory
# because it is writing files not indexed by the input file like tmp and exp_fld1_fld2.txt for example

# - uses awk scripts
# on dec15th 2015 able to take a gtf file with gene_id and transcript_id at any location
# on feb3rd 2017 able to take as input a file named gff as well

# Usage:
########
# make_TSS_file_from_annotation_simple.sh annot.gtf 2> make_TSS_file_from_annotation_simple.err &


# Check it has all it needs
###########################
if [ ! -n "$1" ]
then
    echo "" >&2
    echo Usage: make_TSS_file_from_annotation_simple.sh annot.gtf >&2
    echo Be careful: the input file must have at least exon rows and contain gene_id and transcript_id information for them >&2
    echo Be careful: it is not possible to run two instances at the same time \in the same directory since produces intermediate files not indexed >&2
    echo "" >&2
    exit 1
fi

# Initialize variables
######################
path="`dirname \"$0\"`" # relative path
rootDir="`( cd \"$path\" && pwd )`" # absolute path

annotation=$1
annotbasetmp=`basename ${annotation%.gtf}`
annotbase=${annotbasetmp%.gff}

# Programs
###########
MAKEOK=$rootDir/../Awk/make_gff_ok.awk
EXTRACT5p=$rootDir/../Awk/extract_most_5p.awk
CUTGFF=$rootDir/../Awk/cutgff.awk
GFF2GFF=$rootDir/../Awk/gff2gff.awk


##########################################################
# Make the TSS file for the asked transcript biotypes    #
##########################################################


# a. Extract most 5' exons of transcripts
#########################################
echo I am extracting the most 5\' exons of transcripts from the annotation file >&2
awk '(($3=="exon")&&(($7=="+")||($7=="-")))' $annotation | awk -f $MAKEOK | awk -v fldno=12 -f $EXTRACT5p > $annotbase\_exons_most5p.gff
echo done >&2

# b. Then the most 5' bp of each transcript for each gene
#########################################################
echo I am extracting the most 5\' bp of each transcript for each gene, >&2
awk '{($7=="+") ? tsspos=$4 : tsspos=$5; print $1, ".", "TSS", tsspos, tsspos, ".", $7, ".", "gene_id", $10, "tr_id", $12}' $annotbase\_exons_most5p.gff | awk -f $GFF2GFF > $annotbase\_capped_sites.gff
echo done >&2

# c. Finally collapse per gene
##############################
echo I am collapsing all TSSs per gene >&2
cat $annotbase\_capped_sites.gff | awk -v to=10 -f $CUTGFF | sort -n | uniq -c | awk '{$1=""; print $0}' | awk -f $GFF2GFF | awk -v fileRef=$annotbase\_capped_sites.gff 'BEGIN{while (getline < fileRef >0){split($12,a,"\""); trlist[$1":"$4":"$5":"$7,$10]=(trlist[$1":"$4":"$5":"$7,$10])(a[2])(",");}} {$11="trlist"; $12="\""(trlist[$1":"$4":"$5":"$7,$10])"\"\;"; print $0}' | awk -f $GFF2GFF > $annotbase\_capped_sites_nr.gff
echo done >&2

# d. Clean
###########
echo I am cleaning >&2
rm $annotbase\_exons_most5p.gff
echo done >&2
