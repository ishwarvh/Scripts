#!/bin/bash

# make_TTS_file_from_annotation_simple.sh
# same as make_TTS_file_from_annotation_with_confidence_better.sh
# except that does not include tr biotype neither confidence and is made for any gtf file
# not necesarily gencode
# - it only takes as input an annotation gtf file
# - it produces files where the program is launched
# - important differences with make_TTS_file_from_annotation_with_confidence_better.sh is that it writes the gene id and tr id
#   surrounded by double quotes and ending with semi colon as in the annotation, it only considers exons that are stranded!!!
#   and also the output file is named a bit differently ($annotbase\_capped_sites_nr.gff)

# Be careful: this script cannot be launched several times in the same directory
# because it is writing files not indexed by the input file like tmp and exp_fld1_fld2.txt for example
# This script supposes that the annotation file contains gene name of exon features in $10 and tr name in $12

# - uses awk scripts

# Usage:
########
# make_TTS_file_from_annotation_simple.sh annot.gff [tr_bt_list] 2> make_TTS_file_with_confidence_better_from_annotation.err &

# Check it has all it needs
###########################
if [ ! -n "$1" ]
then
    echo "" >&2
    echo Usage: make_TTS_file_from_annotation_simple.sh annot.gtf [tr_biotypes.txt] >&2
    echo Be careful: it is not possible to run two instances at the same time \in the same directory since produces intermediate files not indexed >&2
    echo Be careful: the gene id and the transcript id of exon features have to be \in column no 10 and 12 respectively >&2
    echo "" >&2
    exit 0
fi

# Initialize variables
######################
annotation=$1
annotbase=`basename ${annotation%.gtf}`
 
# Programs
###########
EXTRACT3p=../Awk/extract_most_3p.awk
CUTGFF=../Awk/cutgff.awk
GFF2GFF=../Awk/gff2gff.awk


##########################################################
# Make the TTS file for the asked transcript biotypes    #
##########################################################

# a. Extract most 3' exons of transcripts
#########################################
echo I am extracting the most 3\' exons of transcripts >&2
awk '(($3=="exon")&&(($7=="+")||($7=="-")))' $annotation | awk -v fldno=12 -f $EXTRACT3p > $annotbase\_exons_most3p.gff
echo done >&2

# b. Then the most 3' bp of each transcript for each gene
#########################################################
echo I am extracting the most 3\' bp of each transcript for each gene >&2
awk '{($7=="+") ? ttspos=$4 : ttspos=$5; print $1, ".", "TTS", ttspos, ttspos, ".", $7, ".", "gene_id", $10, "tr", $12}' $annotbase\_exons_most3p.gff | awk -f $GFF2GFF > $annotbase\_tts_sites.gff
echo done >&2

# c. Finally collapse per gene
##############################
echo I am collapsing all TTSs per gene >&2
cat $annotbase\_tts_sites.gff | awk -v to=10 -f $CUTGFF | sort -n | uniq -c | awk '{$1=""; print $0}' | awk -f $GFF2GFF | awk -v fileRef=$annotbase\_tts_sites.gff 'BEGIN{while (getline < fileRef >0){split($12,a,"\""); trlist[$1"_"$4"_"$5"_"$7,$10]=(trlist[$1"_"$4"_"$5"_"$7,$10])(a[2])(",");}} {$11="trlist"; $12="\""(trlist[$1"_"$4"_"$5"_"$7,$10])"\"\;"; print $0}' | awk -f $GFF2GFF > $annotbase\_tts_sites_nr.gff
echo done >&2

# d. Clean
##########
echo I am cleaning >&2
rm $annotbase\_exons_most3p.gff
echo done >&2