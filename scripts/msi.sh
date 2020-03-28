#!/bin/env bash
# =========================================================
# Copyright 2019-2020,  Nuno A. Fonseca (nuno dot fonseca at gmail dot com)
#
#
# This is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this file.  If not, see <http://www.gnu.org/licenses/>.
#
#
# =========================================================

PATH2SCRIPT=$(dirname "${BASH_SOURCE[0]}" )
## load shell functions
source $PATH2SCRIPT/msi_shared.sh

PATH=$PATH:$PATH2SCRIPT/

## 2019-06-03
set -eu
#set -e
set -o pipefail
# perform some checks on the fastq files and performs incremental analysis

set +u
if [ "$MSI_DIR-" == "-" ]; then
    echo "Unable to continue: MSI_DIR variable not set" > /dev/stderr
    exit 1
fi
set -u
################
# Default values
MIN_LEN=40
MAX_LEN=400000
MIN_QUAL=9
OUT_FOLDER=msi_out
CD_HIT_CLUSTER_THRESHOLD=0.99
MIN_ID=70
EVALUE=0.001
CONF_FILE=
GEN_FASTQC_REPORT="N"
SKIP_BLAST="N"
IGNORE_UNCLASSIFIED=0 ;## process (1) or not (0) the file with unclassified reads (no barcodes)
## minimum number of reads that a cluster must have to  pass the classification step (blastnig)
CLUSTER_MIN_READS=1

## workind directory
TL_DIR=$PWD
# if no db is provided then a remote blast is performed
LOCAL_BLAST_DB=~/blastdb/nt
TAXONOMY_DATA_DIR=$MSI_DIR/db

THREADS=2

PRIMER_MAX_ERROR=0.2

METADATAFILE=
# used to filter the entries in metadata file
EXPERIMENT_ID=.
LAZY=y
#################################################
## commands
FASTQ_INFO_CMD=fastq_info
FASTQ_QC_CMD=fastqc
CUTA_CMD=cutadapt
#FASTQ_QUAL_TRIMMER=fastq_quality_trimmer
BLAST_CMD=blastn
CLUSTER_ADD_SIZE=msi_clustr_add_size.pl
TIME=/usr/bin/time

## TODO
## check for commands

COMMANDS_NEEDED="$FASTQ_INFO_CMD $FASTQ_QC_CMD $BLAST_CMD $CLUSTER_ADD_SIZE"
# 
# 
for cmd in $COMMANDS_NEEDED; do
    command -v $cmd  >/dev/null 2>&1 || { echo "ERROR: $cmd  does not seem to be installed.  Aborting." >&2; exit 1; }
done

#taxdb.tar.gz ftp://ftp.ncbi.nlm.nih.gov/blast/db/taxdb.tar.gz
##   ftp://ftp.ncbi.nlm.nih.gov/blast/db/FASTA/nt.gz  (50GB)
## ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz
#######################################################################################
#

function usage {
    echo "msi.sh [ -s  -t root_dir  -V -r  -p prot -d data_dir -c -X min_reads -h -I metadata_file -c param_file] -i raw_data_toplevel_folder"
    cat <<EOF
 -i tl_dir - toplevel directory with the nanopore data. fastq files will be searched in \$tl_dir/*.fastq.gz. It is expected one file per library/barcode.
 -m min_len    - minimum length of the reads
 -M max_len    - maximum length of the reads
 -q min_qual   - minimum quality
 -I metadata   - metadata file*
 -C min_reads  - minimum number of reads that a cluster should have (Default=1)
 -o out_folder -  output folder
 -b blast_database - path to the blast database
 -B blast_min_id   - value passed to blast (minimum % id - value between 0 and 100)
 -E blast_evalue   - value passed to blast (minimum e-value - value < 1)
 -T min_cluster_id2- minimum cluster identity (sequences with a value greater or equal are clustered together - value between 0 and 1) 
 -t threads        - maximum number of threads
 -c param_file      - file with default parameters values (overrides values passed in the command line)
 -r                 - run fastqc to generate qc reports for the fastq files
 -S                 - stop execution before running blast
 -V                 - increase verbosity
 -h  - provides usage information

*metadata file: tsv file were the file name should be found in one column and the column names (first line of the file) X, Y, Z should exist.
EOF
}

function run_blast {

    query=$1
    out=$2
    # -use_index true
    params="-max_hsps  1  -task megablast -max_target_seqs 1 -evalue $EVALUE -perc_identity $MIN_ID"
    if [ "$LOCAL_BLAST_DB-" == "-" ]; then
	params+=" -remote -db nt"
	pinfo "Remote blast query (this may take a while)"
    else
	params+=" -db $LOCAL_BLAST_DB -num_threads $THREADS  "
    fi
    # BLASTDB=
    # BATCH_SIZE=
    ## Subject Scientific Name(s) are separated by a ';'
    $BLAST_CMD $params  -query $query  -out $out.tmp -outfmt '6 qseqid sseqid evalue bitscore pident nident mismatch qlen length sgi sacc staxids ssciname scomnames stitle'
    pinfo "blast query complete."
    mv $out.tmp $out
}

#######################################################################################
# 
while getopts "I:B:T:E:C:c:n:i:m:M:e:q:o:b:t:hdrSV"  Option; do
    case $Option in
	i ) TL_DIR=$OPTARG;;
	d ) set -x;;
	C ) CLUSTER_MIN_READS=$OPTARG;;
	c ) CONF_FILE=$OPTARG;;
	T ) CD_HIT_CLUSTER_THRESHOLD=$OPTARG;;
	B ) MIN_ID=$OPTARG;;
	e ) EXPERIMENT_ID=$OPTARG;;
	E ) EVALUE=$OPTARG;;
	m ) MIN_LEN=$OPTARG;;
	M ) MAX_LEN=$OPTARG;;
	q ) MIN_QUAL=$OPTARG;;
	o ) OUT_FOLDER=$OPTARG;;
	I ) METADATAFILE=$OPTARG;;
	r ) GEN_FASTQC_REPORT="Y";;
	b ) LOCAL_BLAST_DB=$OPTARG;;
	S ) SKIP_BLAST="Y";;
	V ) set -x;;
	t ) THREADS=$OPTARG;;
	h) usage; exit;;
    esac
done

## Check and validate arguments
if [ "$TL_DIR-" == "-" ]; then
    perror "no value given to parameter -i"
    usage
    exit 1
fi
if [ ! -d $TL_DIR ]; then
    perror "invalud value given to -i: $TL_DIR should be a readable folder"
    usage
    exit 1
fi


if [ "$LOCAL_BLAST_DB-" != "-" ]; then
    if [ ! -e $LOCAL_BLAST_DB.nal ]; then
	perror "Blast database '$LOCAL_BLAST_DB.nal' not found or not readable"
	exit 1
    fi
else
    pinfo "No local blast database provided in -b. Blast queries will be performed remotely. "
fi


if [ "$CONF_FILE-" != "-" ]; then
    if [ ! -e $CONF_FILE ]; then
	perror "$CONF_FILE not found or not readable"
	exit 1
    fi
    pinfo "Loading $CONF_FILE..."
    set +u
    source $CONF_FILE
    set -u
    pinfo "Loading $CONF_FILE...done."
fi

if [ "$METADATAFILE-" != "-" ]; then
    validate_metadata_file $METADATAFILE
fi

################################################################################
## start working....
##set +e
# FASTQ_DIRS=$(ls -q -d $TL_DIR/*/|sort)
FASTQ_DIRS=$TL_DIR
pinfo "Looking for fastq.gz files in $FASTQ_DIRS"

set +e
FASTQ_FILES=$(find  $FASTQ_DIRS -name "*.fastq.gz" | sort -n)
set -e
if [ "$FASTQ_FILES-" == "-" ]; then
    perror "No fastq.gz files found in $FASTQ_DIRS"
    exit 1
fi
FASTQ_FILESA=($FASTQ_FILES)
NFILES=${#FASTQ_FILESA[@]}
pinfo "Found $NFILES fastq.gz files in $FASTQ_DIRS."

####################################
## filter the fastq files
## each top level directory corresponds to a sample
FASTQ_FILES2=""
set +e
for ddd in $FASTQ_FILES; do
    $(file_in_metadata_file $METADATAFILE $(basename $ddd))
    D=$?
    if [ $D == 0 ]; then
	FASTQ_FILES2="$FASTQ_FILES2 $ddd"
    fi
done
set -e
FASTQ_FILESA=($FASTQ_FILES2)
FASTQ_FILES=$FASTQ_FILES2
NFILES=${#FASTQ_FILESA[@]}
pinfo "Found $NFILES fastq.gz files in $FASTQ_DIRS and in $METADATAFILE."


## create top level folder to hold the results
pinfo "Ouput folder: $OUT_FOLDER"
mkdir -p $OUT_FOLDER


## Record the time and memory needed to process  the data
##LOGFILE=$OUT_FOLDER/time_mem_log.tsv


# arg:
# 1-level (1,2,3,...)
# 2-filename (prefix) - suffix will be .stats.$level.tsv
function get_stats_filename {
    level=$1
    filename=$2
    echo $filename.stats.$level.tsv
}
function polish_sequences {
    representatives=$1
    out2=$2
    
    if [ -e $representatives ] && [ "$LAZY-" == "y-" ]; then
	pinfo "Skipping polishing sequences"
	return
    fi
    ## OK, we have the clusters so now correct/polish the sequences of the representatives
    rm -f $representatives
    pinfo "Polishing sequences"
    cat $out2/final_clusters_size.csv | while read c_and_s; do
	## polish a sequence
	## get all reads from a cluster
	cluster_id=$(echo $c_and_s|cut -f 2 -d\ )
	cluster_size=$(echo $c_and_s|cut -f 1 -d\ )
	
	pinfo "Polishing cluster $cluster_id (# $cluster_size)"
	
	##LN - sequence length
	##RC - number of reads used for polishing the sequence
	##XC - percentage of polished windows in the sequnce
	## reference
	grep -E "^$cluster_id\s" $out2/final_cluster_origins.csv |cut -f 2,3,4| sed "1s/^/@/;1s/\t/:size=$cluster_size\n/;s/\t/\n+\n/" > $out2/$cluster_id.fastq
	
	if [ $cluster_size == 1 ]; then
		ref=$out2/$cluster_id.fasta
		# skip sequence since we cannot repolish later
		#continue
		head -n 2 $out2/$cluster_id.fastq | sed "1s/^@/>/" > $ref		
	else
	    grep -E "^$cluster_id\s" $out2/final_clusters.csv |cut -f 2 > $out2/$cluster_id.seq_ids
	    grep -f $out2/$cluster_id.seq_ids -F -A 3 $out2/sorted.fastq | grep -v -- "^--$" > $out2/$cluster_id.seqs.fastq
	    rm -f $out2/$cluster_id.seq_ids
	    ## align
	    if [ ! -e $out2/$cluster_id.sam ]; then
		minimap2 -ax map-ont $out2/$cluster_id.fastq $out2/$cluster_id.seqs.fastq > $out2/$cluster_id.sam.tmp && mv $out2/$cluster_id.sam.tmp  $out2/$cluster_id.sam
	    else
		pinfo "Skipping the generation of $out2/$cluster_id.sam"
	    fi	    
	    # 
	    ## consensus
	    ## pilon:  https://github.com/broadinstitute/pilon/wiki
	    ## racon: https://github.com/isovic/racon (fragment correction with self overlaps)
	    if [  ! -e $out2/$cluster_id.polished.fastq ]; then
		racon $out2/$cluster_id.seqs.fastq $out2/$cluster_id.sam $out2/$cluster_id.fastq -t $THREADS > $out2/$cluster_id.polished.fastq.tmp  && mv $out2/$cluster_id.polished.fastq.tmp $out2/$cluster_id.polished.fasta
	    else
		pinfo "Skipping the generation of $out2/$cluster_id.polished.fasta"
	    fi
	    ref=$out2/$cluster_id.polished.fasta
	fi
	cat $ref >>  $representatives
    done
}

function process_fastq_no_results {
    local CENTROIDS=$1
    ## no results
    touch $CENTROIDS.blast $CENTROIDS.tsv $CENTROIDS-cdhit.clstr.sorted.tree
    pinfo "No data, no results"
}

function remove_split_by_primer {
    local fq_file=$1b
    local fasta_file=$2
    local adapters_file=${fasta_file//.fasta/.adapters}    
    local adapters_infofile=${fasta_file//.fasta/.adapters.info}
    local adapters_nohit_file=${fasta_file//.fasta/.noprimers.fasta}
    local adapters_outfile=${fasta_file//.fasta/.primers.fasta}
    pinfo "Preparing to call cutdaptor to remove primers..."
    ## create the file with the adapters
    # revseq from emboss should be available
    local primer_f_a=(${MD["PRIMER_F"]})
    local primer_r_a=(${MD["PRIMER_R"]})
    local primer_min_len_a=(${MD["MIN_LENGTH"]})
    local primer_max_len_a=(${MD["MAX_LENGTH"]})
    local min_len
    local max_len
    local i
    local R
    local F
    local RCF
    local RCR
    let i=0
    set -e

    rm -f $adapters_file
    touch $adapters_file
    ## should look for
    # F RCR and R RCF
    # 
    for primer in ${MD["PRIMER_SET"]}; do	
	F=${primer_f_a[$i]^^}
	R=${primer_r_a[$i]^^}
	# --minimum/maximum-length
	min_len=${primer_min_len_a[$i]}
	max_len=${primer_max_len_a[$i]}
	# add/remove 10%
	min_len=$(perl -e "print int($min_len * 0.9);")
	max_len=$(perl -e "print int($max_len * 1.1);")
	F=${F//I/N}
	R=${R//I/N}
	# ;minimum-length=$min_len;maximum-length=$max_len
	RCF=$(echo $F|revseq -sequence stdin -outseq stdout|grep -v "^>")
	RCR=$(echo $R|revseq -sequence stdin -outseq stdout|grep -v "^>")
	if [ $R == $F ]; then
	    echo ">$primer:F-RCR" >> $adapters_file
	    echo "$F...$RCR"  >> $adapters_file
	    #echo ">$primer:F-R" >> $adapters_file
	    #echo "$F...$R;max_error_rate=$PRIMER_MAX_ERROR"  >> $adapters_file
	else
	    echo ">$primer:F-RCR" >> $adapters_file
	    echo "$F...$RCR"  >> $adapters_file
	    echo ">$primer:R-RCF"  >> $adapters_file
	    echo "$R...$RCF"  >> $adapters_file
	fi
	#echo ${primer_r_a[$i]}
	let i=$i+1
    done

    ## call
    # --info-file $adapters_infofile - crashes in version 2.3
    # --untrimmed-output $adapters_nohit_file
    cmd="$CUTA_CMD --fasta -g file:$adapters_file    -y :adapter={name}  -o $adapters_outfile  $fasta_file  --cores $THREADS -e $PRIMER_MAX_ERROR"
    $cmd > /dev/stderr
    set +e
    echo $adapters_outfile
}

##
function fasta_stats_file {
    set +e
    local fasta_file=$1
    local fastq_stats_file=$2
    local sample_name=$3
    local note=$4
    if [  -e  $fasta_file ]; then
       local NR=$(grep -c "^>" $fasta_file)

    else
	local NR=0
    fi
    set -e
    echo "id note num_reads" | sed "s/ /\t/g"  >  $fastq_stats_file
    echo "$sample_name $note $NR "| sed "s/ /\t/g" >> $fastq_stats_file
}

function num_reads_in_centroids_stats_file {
    set +e
    local centroids_file=$1
    local stats_file=$2
    local sample_name=$3
    local note=$4
    if [  -e  $centroids_file ]; then
	local NR=$(grep "size=" $centroids_file|sed -E "s/.*size=([0-9]+):.*/\1/"|awk '{s+=$1} END {print s}')
	if [ "$NR-" == "-" ]; then
	    NR=0
	fi
    else
	local NR=0
    fi
    set -e
    echo "id note num_reads" | sed "s/ /\t/g"  >  $stats_file
    echo "$sample_name $note $NR "| sed "s/ /\t/g" >> $stats_file
}

## Creates one folder per sample
function process_fastq {

    fq_file=$1
    md_file=$2 ;# metadata file
    ## not really the sample name....
    sample_name=$(basename -s .fastq.gz $1 )
    dir=$sample_name

    pinfo "Processing sample:$sample_name"

    SAMPLE_OUT_FOLDER=$OUT_FOLDER/$sample_name
    mkdir -p $SAMPLE_OUT_FOLDER

    ## assumes one output folder per sample/fastq
    PROCESSED_FASTQS=$OUT_FOLDER/$sample_name/processed
    CENTROIDS1=$OUT_FOLDER/$sample_name/$sample_name.centroids.withprimers.fasta
    CENTROIDS=$OUT_FOLDER/$sample_name/$sample_name.centroids.fasta
    
    ##################################################
    ## File is ignored if is not in the metadata table
    if [ "$md_file-" != "-" ]; then
	set +e
	file_in_metadata_file $METADATAFILE $(basename $fq_file)
	if [ $? == 1 ]; then
	    pinfo "skipping processing of $fq_file"
	    return 
	fi
	set -e
    fi

    ###################################################
    ## 
    ## validate the fastq file and get some stats
    ##  - number of reads,min_len,max_len,quality encoding, quality encoding range
    INFO_FILE=$SAMPLE_OUT_FOLDER/$sample_name.info
    STATS_FILE1=$(get_stats_filename 1 $SAMPLE_OUT_FOLDER/$sample_name)
    if [ -e $STATS_FILE1 ] && [ $STATS_FILE1 -nt $fq_file ] && [ "$LAZY-" == "y-" ]; then
	pinfo "Keeping cached  $STATS_FILE1"
    else
	set -e
	msi_fastq_stats.sh $fq_file raw $sample_name $INFO_FILE | grep -v "^$" > $STATS_FILE1.tmp && mv $STATS_FILE1.tmp $STATS_FILE1
    fi

    ###################################################
    ##
    ##
    ## qc
    set +e
    QC0=$SAMPLE_OUT_FOLDER/qc/raw
    QC1=$SAMPLE_OUT_FOLDER/qc/f1
    mkdir -p $QC0
    mkdir -p $QC1
    pref=$sample_name
    FQ_FILE_F1=$SAMPLE_OUT_FOLDER/$pref.f1.fastq.gz

    if [ $GEN_FASTQC_REPORT == "Y" ]; then
	FQC_REPORT0=$QC0/$(basename $fq_file .fastq.gz)_fastqc.html
	FQC_REPORT1=$QC1/$(basename $fq_file .fastq.gz).f1_fastqc.html
	if [ -e $FQC_REPORT0 ]  && [ $FQC_REPORT0 -nt $fq_file ] && [ "$LAZY-" == "y-" ]; then
	    pinfo "QC report already generated"
	else
	    $FASTQ_QC_CMD -o $QC0 -f fastq $fq_file
	    touch $QC0/$sample_name.qc_done	
	fi
    fi

    ######################################################
    ## filter by fragment length and quality
    if [ -e $FQ_FILE_F1 ]  && [ $FQ_FILE_F1 -nt $fq_file ] && [ "$LAZY-" == "y-" ]; then
	pinfo "Skipping generation of $FQ_FILE_F1"
    else
	$CUTA_CMD -q $MIN_QUAL,$MIN_QUAL  -m $MIN_LEN -M $MAX_LEN -o $FQ_FILE_F1 $fq_file
    fi

    ######################################################
    ##
    if [ $GEN_FASTQC_REPORT == "Y" ]; then
	if [ -e $FQC_REPORT1 ] && [ $FQC_REPORT1 -nt $FQ_FILE_F1 ] && [ "$LAZY-" == "y-" ]; then
	    pinfo "QC report 2 already generated"
	else
	    $FASTQ_QC_CMD -o $QC1 -f fastq $FQ_FILE_F1
	    touch $QC1/$sample_name.qc_done
	fi
    fi

    ######################################################
    ##
    STATS_FILE2=$(get_stats_filename 2 $SAMPLE_OUT_FOLDER/$sample_name)
    if [  -e $STATS_FILE2 ] && [ $STATS_FILE2 -nt $FQ_FILE_F1 ] &&  [ "$LAZY-" == "y-" ]; then
	pinfo "Keeping cached  $STATS_FILE2"
    else
	msi_fastq_stats.sh $FQ_FILE_F1 "raw_post_filter" $sample_name $INFO_FILE  | grep -v "^$" > $STATS_FILE2.tmp && mv $STATS_FILE2.tmp $STATS_FILE2
    fi

    STATS_FILE3=$(get_stats_filename 3 $SAMPLE_OUT_FOLDER/$sample_name)
    STATS_FILE4=$(get_stats_filename 4 $SAMPLE_OUT_FOLDER/$sample_name)

    set -e
    ######################################################
    ## We may end up with no reads...
    nlines=$(zcat $FQ_FILE_F1|wc -l)
    if [ "$nlines-" == "0-" ]; then
	pinfo "Skipping $sample_name:$fq_file - no reads after QC"
	process_fastq_no_results $CENTROIDS
	fasta_stats_file $CENTROIDS $STATS_FILE3 $sample_name "polished_reads"
	num_reads_in_centroids_stats_file $CENTROIDS $STATS_FILE4 $sample_name "total_num_reads_in_centroids"
	return
    fi

    ######################################################
    ## Clustering
    ##
    ## try to keep it fast
    out2=$SAMPLE_OUT_FOLDER/$pref-isonclust
    representatives=$out2/centroids.fasta
    mkdir -p $out2
    if [  -e  $representatives ] &&  [ "$LAZY-" == "y-" ] && [ $representatives -nt $FQ_FILE_F1 ]; then
	pinfo "Skipping clustering 1"
    else
	let thr=`expr 1 + \( $nlines / 30 \)`
	if [ $thr -le  $THREADS ]; then
	    CTHREADS=1
	else
	    CTHREADS=$THREADS
	fi
	## clean up
	rm -rf $out2/*
	#	    nreads=$(fastq_num_reads $FQ_FILE_F1)
	#	    if [ $nreads -gt 1 ]; then
	isONclust --ont --fastq <(gunzip -c $FQ_FILE_F1)  --outfolder $out2  --t $CTHREADS
	#	    fi
	if [ -e $out2/final_clusters.csv ]; then
	    cut -f 1 $out2/final_clusters.csv | uniq -c | sed -E 's/^\s+//'> $out2/final_clusters_size.csv
	    polish_sequences $representatives $out2
	    #ls -l $representatives
	    #echo $fq_file $representatives >> $PROCESSED_FASTQS
	else
	    echo "isONclust did not generate $out2/final_clusters.csv "
	    exit 3
	fi
    fi
    # deprecated
    #if [ "$(wc -l $PROCESSED_FASTQS|cut -f 1 -d\ )-" == "0-" ]; then
    #process_fastq_no_results $CENTROIDS
    #fasta_stats_file $CENTROIDS $STATS_FILE3 $sample_name "polished_reads"
    #num_reads_in_centroids_stats_file $CENTROIDS $STATS_FILE4 $sample_name "total_num_reads_in_centroids"
    #return
    #fi

    ## final file
    #cat `cut -f 2 -d\  $PROCESSED_FASTQS |tail -n 1` > $CENTROIDS1.tmp
    cat $representatives > $CENTROIDS1.tmp

    if [ -e  $CENTROIDS1 ] && [ $CENTROIDS1 -nt $representatives ] && [ "$LAZY-" == "y-" ]; then
	pinfo "Skipping clustering 2"
    else
	## recluster
	## -M unlimited memory
	cd-hit-est  -i $CENTROIDS1.tmp -o $CENTROIDS1-cdhit  -c $CD_HIT_CLUSTER_THRESHOLD -M 0 -T $THREADS  -g 1 -G 1 -d 0
	NC=`wc -l $CENTROIDS1-cdhit| cut -f 1 -d\ `
	if [ $NC -eq 0 ]; then
	    # no clusters
	    cp $CENTROIDS1.tmp  $CENTROIDS1
	    ## TODO: make the format of centroids to be the same as the one from CLUSTER_ADD_SIZE
	else
	    ##
	    grep "*$" $CENTROIDS1-cdhit.clstr|cut -f 2 -d\>|sed "s/:size.*//" >$CENTROIDS1.tmp2
	    grep -A 1 -F -f $CENTROIDS1.tmp2 $CENTROIDS1.tmp | grep -v --  "--" > $CENTROIDS1.tmp3
	    mv $CENTROIDS1.tmp3  $CENTROIDS1.tmp4
	    ## tree
	    clstr_sort_by.pl < $CENTROIDS1-cdhit.clstr  > $CENTROIDS1-cdhit.clstr.sorted
	    clstr2tree.pl $CENTROIDS1-cdhit.clstr.sorted  >  $CENTROIDS1-cdhit.clstr.sorted.tree

	    ## keep track of the number of representatives "merged" on each cluster
	    ## add the size the reformat the headers
	    $CLUSTER_ADD_SIZE $CENTROIDS1.tmp4 $CENTROIDS1-cdhit.clstr.sorted $CLUSTER_MIN_READS > $CENTROIDS1.tmp5
	    mv $CENTROIDS1.tmp5 $CENTROIDS1
	fi
    fi

    NC=`wc -l $CENTROIDS1| cut -f 1 -d\ `
    if [ $NC -eq 0 ]; then
	## empty fasta file
	process_fastq_no_results $CENTROIDS
	fasta_stats_file $CENTROIDS $STATS_FILE3 $sample_name "polished_reads"
	num_reads_in_centroids_stats_file $CENTROIDS $STATS_FILE4 $sample_name "total_num_reads_in_centroids"
	return
	#touch $CENTROIDS.tsv
	#touch $CENTROIDS.blast
    fi

    ############################################################
    ## Trim adapters and filter by length
    ## keep adapers in FASTA header
    if [ "$md_file-" != "-" ]; then
	if [ -e $CENTROIDS ] && [ $CENTROIDS -nt $CENTROIDS1 ] &&  [ "$LAZY-" == "y-" ]; then
	    pinfo "skipping trimming adapaters and filter by length (already done)"
	else
	    load_metadata $METADATAFILE $(basename $fq_file)
	    if [ "${MD[PRIMER_SET]^^}-" == "NONE-" ]; then
		pinfo "No primers for $fq_file"
		sed  -E "s/size=(.*)$/\1/;s/$/:adapter=none:/" $CENTROIDS1 > $CENTROIDS
	    else
		pinfo "Calling cutadapter"
		# 2.run cut adaptor
		#   2.1 one single primer - we get one single file
		#   2.2 multiple primerrs - we get multiple files	    
		new_file=$(remove_split_by_primer $fq_file $CENTROIDS1)
		# filter by length (min and max defined for all samples)
		$CUTA_CMD -m $MIN_LEN -M $MAX_LEN -o $new_file.tmp $new_file
		# rename files
		mv $new_file.tmp $CENTROIDS
		rm -f $new_file
	    fi
	fi
    fi

    #####################################################
    ## generat the stats file
    if [ -e $STATS_FILE3 ] && [ $STATS_FILE3 -nt $CENTROIDS ] &&  [ "$LAZY-" == "y-" ]; then
	pinfo "Skipping generation of $STATS_FILE3"
    else
	fasta_stats_file $CENTROIDS $STATS_FILE3 $sample_name "polished_reads"
    fi
    if [ -e $STATS_FILE4 ] && [ $STATS_FILE4 -nt $CENTROIDS ] &&  [ "$LAZY-" == "y-" ]; then
	pinfo "Skipping generation of $STATS_FILE4"
    else
	num_reads_in_centroids_stats_file $CENTROIDS $STATS_FILE4 $sample_name "total_num_reads_in_centroids"	
    fi

    #####################################################
    ## blast
    if [ $SKIP_BLAST == "Y" ]; then
	# finish here
	pinfo "Skipping blast as requested"
	exit 0
    fi
    if [ -e $CENTROIDS.blast ] && [ "$LAZY-" == "y-" ] && [ $CENTROIDS.blast -nt $CENTROIDS ]; then
	pinfo "Skipping Blast - file $CENTROIDS.blast already exists"
    else
	run_blast $CENTROIDS  $CENTROIDS.blast
    fi
    ## blat??
    #####################################################
    ## simple tsv file with the stats from blast
    # summary file
    if [ -e $CENTROIDS.tsv ] && [ $CENTROIDS.tsv -nt $CENTROIDS.blast ] && [ "$LAZY-" == "y-" ]; then
	pinfo "$CENTROIDS.tsv already generated...skipping it"
    else
	set -x
	msi_tidyup_results $CENTROIDS $CENTROIDS.blast $CENTROIDS.tsv.tmp $TAXONOMY_DATA_DIR
	mv $CENTROIDS.tsv.tmp $CENTROIDS.tsv
    fi
}

####################################################
## Process each fastq_file
for ddd in $FASTQ_FILES; do
    process_fastq $ddd "$METADATAFILE"
done

set -e 
## Generate a single file with all results
### First add the sample name as a column before merging the files
out_file=$OUT_FOLDER/results.tsv.gz
out_file_fasta=${out_file//.tsv.gz/.fasta.gz}
rstats_file=$OUT_FOLDER/running.stats.tsv

rm -f $out_file $out_file.tmp
touch $out_file.tmp

rm -f $out_file_fasta $out_file_fasta.tmp
touch $out_file_fasta.tmp


###############################
## stats per step - number of reads, etc
rm -f $rstats_file
touch $rstats_file.tmp 
for ddd in $FASTQ_FILES; do
    sample_name=$(basename -s .fastq.gz $ddd )
    prefix_path=$OUT_FOLDER/$sample_name/$sample_name
    if [ ! -s $rstats_file.tmp ]; then
	head -n 1 $prefix_path.stats.1.tsv > $rstats_file.tmp
    fi
    tail -q -n +2 $prefix_path.stats.?.tsv >> $rstats_file.tmp	
done
gzip $rstats_file.tmp
mv $rstats_file.tmp.gz   $rstats_file.gz
pinfo "Generated $rstats_file.gz"
###############################
## 
for ddd in $FASTQ_FILES; do
    sample_name=$(basename -s .fastq.gz $ddd )
    f=$OUT_FOLDER/$sample_name/$sample_name.centroids.fasta.tsv
    fa=$OUT_FOLDER/$sample_name/$sample_name.centroids.fasta
    if [ ! -e $f ]; then
	perror "File $f not found"
	exit 3
    fi
    if [ ! -e $fa ]; then
	perror "File $fa not found"
	exit 3
    fi

    if [ ! -s $f ]; then
	# empty file
	pinfo $f empty
    else
	if [ ! -s $out_file.tmp ]; then
	    head -n 1 $f | sed 's/^/sample\t/' > $out_file.tmp
	fi
	tail -n +2 $f | sed "s/^/$sample_name\t/" >> $out_file.tmp
    fi
    if [ ! -s $fa ]; then
	# empty file
	pinfo $fa empty
    else
	cat $fa | sed -E "s/^>(.*)$/>\1:$sample_name/">> $out_file_fasta.tmp
    fi
    
done
gzip $out_file.tmp
gzip $out_file_fasta.tmp
mv $out_file.tmp.gz $out_file
mv $out_file_fasta.tmp.gz $out_file_fasta
pinfo "Generated $out_file"
pinfo "Generated $out_file_fasta"

pinfo "All done."
exit 0
