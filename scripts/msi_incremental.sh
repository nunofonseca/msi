#!/bin/env bash
## 2019-06-03
set -ex
#set -e
set -o pipefail
# perform some checks on the fastq files and performs incremental analysis

################
# Default values
MIN_LEN=400
MAX_LEN=4000
MIN_QUAL=10
OUT_FOLDER=test_incr1
CD_HIT_CLUSTER_THRESHOLD=0.95

## workind directory
TL_DIR=$PWD
# if no db is provided then a remote blast is performed
LOCAL_BLAST_DB=~/blastdb/nt
TAXONOMY_DATA_DIR=$MSI_DIR/db

THREADS=2
MAX_NUM_ITERATIONS=1000000

LAZY=y
#################################################
## commands
FASTQ_INFO_CMD=fastq_info
FASTQ_QC_CMD=fastqc
CUTA_CMD=cutadapt
FASTQ_QUAL_TRIMMER=fastq_quality_trimmer
BLAST_CMD=blastn
CLUSTER_ADD_SIZE=msi_clustr_add_size.pl
TIME=/usr/bin/time

## TODO
## check for commands



#taxdb.tar.gz ftp://ftp.ncbi.nlm.nih.gov/blast/db/taxdb.tar.gz
##   ftp://ftp.ncbi.nlm.nih.gov/blast/db/FASTA/nt.gz  (50GB)
## ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz
#######################################################################################
#
function pinfo {
    echo "==INFO: $*" 1>&2
}

function perror {
    echo "==ERROR: $*"  1>&2
}

function usage {
    echo "xxx [ -s  -t root_dir  -p prot -d data_dir -c -h] -i raw_data_toplevel_folder"
    cat <<EOF
 -i tl_dir - toplevel directory with the nanopore data. fastq files will be searched in \$tl_dir/*/fastq_pass. It is expected that the tree directory is organized as \$tl_dir/sample_name/fastq_pass.
 -m min_len    - minimum length of the reads
 -M max_len    - maximum length of the reads
 -q min_qual   - minimum quality
 -o out_folder -  output folder
 -b blast_database - path to the blast database
 -t threads        - maximum number of threads
 -h  - provides usage information
EOF
}

function run_blast {

    query=$1
    out=$2
    # -use_index true
    params="-task megablast -max_target_seqs 1 -evalue 0.1 -perc_identity 80"
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

function tidy_results {
    fasta_file=$1
    blast_tsv=$2
    out_file=$3
    #pident means Percentage of identical matches
    #nident means Number of identical matches
    #mismatch means Number of mismatches
    echo read nreads nbatches qseqid sseqid evalue bitscore pident nident mismatch qlen length sgi pid staxids ssciname scomnames stitle  | tr " " "\t" > $out_file.tmp
    grep "^>" $fasta_file | sed "s/^>//" | cut -f 1 -d\  > $out_file.tmp2
    sed -E "s/^.*:(size=.*:size=.*)$/\1/;s/:/\t/g;s/size=//g;s/members=//"  $out_file.tmp2  > $out_file.tmp3    
    paste -d "\t" $out_file.tmp2 $out_file.tmp3 | sed -E "s/:size=[^\t]+//"| sort -u -k 1b,1 > $out_file.tmp1
    sort -k 1b,1 $blast_tsv | sed -E "s/:size=[^\t]+//" > $out_file.tmp2
    join -t $'\t' -a 1 -e X $out_file.tmp1 $out_file.tmp2  >> $out_file.tmp
    #join -t\t $out_file.tmp2 $out_file.tmp1  >> $out_file.tmp
    ## add lineage information when possible
    echo taxid lineage kingdom phylum class order family genus species subspecies | tr " " "\t" > $out_file.tmp3 
    cut -f 15 $out_file.tmp | tail -n +2 | sed "s/^$/unclassified/" | taxonkit lineage --data-dir $TAXONOMY_DATA_DIR |  taxonkit reformat  --data-dir $TAXONOMY_DATA_DIR  --lineage-field 2  --format   "{k}\t{p}\t{c}\t{o}\t{f}\t{g}\t{s}\t{S}" >> $out_file.tmp3
    paste -d "\t" $out_file.tmp $out_file.tmp3 > $out_file.tmp2
    
    mv $out_file.tmp2 $out_file
    rm -f $out_file.tmp*
}

#tidy_results blast_example.fasta blast_example.tsv lixo.tsv
#tidy_results test_incr1/test1_c/test1_c.centroids.fasta test_incr1/test1_c/test1_c.centroids.fasta.blast  lixo.tsv

function run_and_time_it {
    logfile=$1
    label=$2
    datetime=`date "+%F %R"`
    shift 2
    if [ ! -e $logfile ] || [ ! -s $logfile ] ; then
	## initialize log file
	echo 'label |Time elapsed |Time elapsed(Seconds)| maximum resident memory |date|command | exit status | System inputs| system outputs| Times Swapped' | tr "|" "\t" > $logfile
    fi
    set +e
    /usr/bin/time -q -o $logfile -a --format "$label\t%E\t%e\t%M\t$datetime\t$*\t%x\t%I\t%O\t%W" bash -c "$*"
    EXIT_STATUS=$?
    set -e
    if [ $EXIT_STATUS -ne 0 ]; then	
	exit $EXIT_STATUS
    fi
}


## arg for all iteration functions: sample_name
function set_cur_iteration {
    echo $2 > $OUT_FOLDER/$1/cur_iteration.txt
}

function get_cur_iteration {
    if [ -e $OUT_FOLDER/$1/cur_iteration.txt ]; then
	cat $OUT_FOLDER/$1/cur_iteration.txt
    fi
    echo
}

function new_iteration {

    CUR_ITERATION=`get_cur_iteration $1`
    if [ "$CUR_ITERATION-" == "-" ]; then
	##
	CUR_ITERATION=1
    else
	CUR_ITERATION=`expr $CUR_ITERATION + 1`
    fi
    mkdir -p $OUT_FOLDER/$1/iterations/${CUR_ITERATION}
    echo $CUR_ITERATION
}

function freeze_iteration_files {
    sample_name=$1
    shift 1
    files=$*
    cp -ar $files $OUT_FOLDER/$sample_name/iterations/${CUR_ITERATION}
}

#######################################################################################
# 
while getopts "n:i:m:M:q:o:b:t:hd"  Option; do
    case $Option in
	i ) TL_DIR=$OPTARG;;
	d ) set -x;;
	m ) MIN_LEN=$OPTARG;;
	M ) MAX_LEN=$OPTARG;;
	q ) MIN_QUAL=$OPTARG;;
	o ) OUT_FOLDER=$OPTARG;;
	b ) LOCAL_BLAST_DB=$OPTARG;;
	t ) THREADS=$OPTARG;;
	n ) MAX_NUM_ITERATIONS=$OPTARG;;
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


################################################################################3
## start working....
pinfo "Looking for fastq_pass folder in $TL_DIR/*/*/"
##set +e
## fix paths
##  $TL_DIR/*/*/fastq_pass|sort)
FASTQ_DIRS=$(ls -q -d $TL_DIR/*/|sort)
#FASTQ_DIRS=$(ls -q -d $TL_DIR/uncl*/)
pinfo "Found: $FASTQ_DIRS"

## create top level folder to hold the results
pinfo "Ouput folder: $OUT_FOLDER"
mkdir -p $OUT_FOLDER

LOGFILE=$OUT_FOLDER/time_mem_log.tsv


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
	
function process_sample {

    dir=$1
    sample_name=$(basename $dir )
    pinfo "Processing sample:$sample_name"

    SAMPLE_OUT_FOLDER=$OUT_FOLDER/$sample_name
    mkdir -p $SAMPLE_OUT_FOLDER


    PROCESSED_FASTQS=$OUT_FOLDER/$sample_name/processed
    CENTROIDS=$OUT_FOLDER/$sample_name/$sample_name.centroids.fasta

    if [ -e $CENTROIDS.tsv ] && [ "$LAZY-" == "y-" ]; then
	echo "skipping processing of $sample_name ($CENTROIDS.tsv already created)"
	return
    fi
    CUR_ITERATION=`new_iteration $sample_name`
    pinfo "Iteration: $CUR_ITERATION"

    touch $PROCESSED_FASTQS

    ## compress fastq files if they are uncompressed
    # UNCOMPRESSED=$(find  $ddd -name "*.fastq")
    # pinfo ">$UNCOMPRESSED<"
    # if [ "$UNCOMPRESSED-" != "-" ]; then
    # 	pinfo "Compressing $UNCOMPRESSED..."
    # 	gzip -f  $UNCOMPRESSED
    # 	pinfo "Compressing $UNCOMPRESSED...done"
    # fi
    ##
    ##
    num_fastq_files=0
    ## Process each fastq file if not processed already
    find  $ddd -name "*.fastq.gz" | sort -n | while read n; do
	num_fastq_files=`expr $num_fastq_files + 1`
	if [ $num_fastq_files -gt $MAX_NUM_ITERATIONS ]; then
	    ## CUR_ITERATION
	    continue
	fi
	
	fq_file=$(basename $n)
	set +e
	ll=$(grep -s -c $fq_file $n$PROCESSED_FASTQS)
	set -e
	if [ "$ll-" != "-" ] && [ "$LAZY-" == "y-" ]; then
	    pinfo "Skipping $sample_name:$fq_file"
	    continue
	fi
	##
	## validate the fastq file
	INFO_FILE=$SAMPLE_OUT_FOLDER/$fq_file.info
	if [  -e $INFO_FILE ] && [ "$LAZY-" == "y-" ]; then
	    $FASTQ_INFO_CMD $n 2> $INFO_FILE
	else
	    pinfo "Skipping FASTQ validation for $n"
	fi
	## qc
	QC0=$SAMPLE_OUT_FOLDER/qc/raw
	QC1=$SAMPLE_OUT_FOLDER/qc/f1
	mkdir -p $QC0
	mkdir -p $QC1
	pref=$(echo $fq_file|sed "s/.fastq.gz//")
	FQ_FILE_F1=$SAMPLE_OUT_FOLDER/$pref.f1.fastq.gz

	if [  -e $QC0/$fq_file.qc_done ] && [ "$LAZY-" == "y-" ]; then
	    pinfo "QC report already generated"
	else
	    $FASTQ_QC_CMD -o $QC0 -f fastq $n
	    touch $QC0/$fq_file.qc_done

	fi
	## filter by fragment length and quality
	if [  -e $FQ_FILE_F1 ]  && [ "$LAZY-" == "y-" ]; then
	    pinfo "Skipping generation of $FQ_FILE_F1"
	else
	    $CUTA_CMD -q $MIN_QUAL,$MIN_QUAL  -m $MIN_LEN -M $MAX_LEN -o $FQ_FILE_F1 $n
	fi
	if [ -e $QC1/$fq_file.qc_done ] &&  [ "$LAZY-" == "y-" ]; then
	    pinfo "QC report already generated"
	else
	    $FASTQ_QC_CMD -o $QC1 -f fastq $FQ_FILE_F1
	    touch $QC1/$fq_file.qc_done

	fi	
	##
	## keep it fast
	out2=$SAMPLE_OUT_FOLDER/$pref-isonclust
	representatives=$out2/centroids.fasta
	mkdir -p $out2
	if [  -e $out2/final_clusters.csv ] &&  [ "$LAZY-" == "y-" ]; then
	    pinfo "Skipping clustering"
	else
	    isONclust --ont --fastq <(gunzip -c $FQ_FILE_F1)  --outfolder $out2  --t $THREADS 
	fi
	cut -f 1 $out2/final_clusters.csv | uniq -c | sed -E 's/^\s+//'> $out2/final_clusters_size.csv
	polish_sequences $representatives $out2
	ls -l $representatives
	echo $fq_file $representatives >> $PROCESSED_FASTQS
    done

    ## final file
    cat `cut -f 2 -d\  $PROCESSED_FASTQS |sort -u` > $CENTROIDS.tmp

    if [ ! -e  $CENTROIDS ] || [ $PROCESSED_FASTQS -nt $CENTROIDS ]; then
	## recluster
	## -M unlimited memory
	cd-hit-est  -i $CENTROIDS.tmp -o $CENTROIDS-cdhit  -c $CD_HIT_CLUSTER_THRESHOLD -M 0 -T $THREADS  -g 1 -G 1 -d 0
	NC=`wc -l $CENTROIDS-cdhit| cut -f 1 -d\ `
	if [ $NC -eq 0 ]; then
	    # no clusters
	    cp $CENTROIDS.tmp  $CENTROIDS
	    ## TODO: make the format of centroids to be the same as the one from CLUSTER_ADD_SIZE
	else
	    ##
	    grep "*$" $CENTROIDS-cdhit.clstr|cut -f 2 -d\>|sed "s/:size.*//" >$CENTROIDS.tmp2
	    grep -A 1 -F -f $CENTROIDS.tmp2 $CENTROIDS.tmp | grep -v --  "--" > $CENTROIDS.tmp3
	    mv $CENTROIDS.tmp3  $CENTROIDS.tmp4
	    ## tree
	    clstr_sort_by.pl < $CENTROIDS-cdhit.clstr  > $CENTROIDS-cdhit.clstr.sorted
	    clstr2tree.pl $CENTROIDS-cdhit.clstr.sorted  >  $CENTROIDS-cdhit.clstr.sorted.tree
	    
	    ## keep track of the number of representatives "merged" on each cluster
	    cat $CENTROIDS-cdhit.clstr | $CLUSTER_ADD_SIZE $CENTROIDS.tmp4
	    mv $CENTROIDS.tmp4 $CENTROIDS
	fi
    fi

    ## blast 
    if [ -e $CENTROIDS.blast ] && [ "$LAZY-" == "y-" ] && [ ! $CENTROIDS.blast -nt $CENTROIDS ]; then
	pinfo "Skipping Blast - file $CENTROIDS.blast already exists"
    else
	run_blast $CENTROIDS  $CENTROIDS.blast
    fi
    ## blat??
    
    ## simple tsv file with the stats from blast
    # summary file
    tidy_results $CENTROIDS $CENTROIDS.blast $CENTROIDS.tsv
    ## cp the results to the iteration folder
    freeze_iteration_files $sample_name $CENTROIDS.blast $CENTROIDS.tsv $CENTROIDS $CENTROIDS-cdhit.clstr.sorted.tree
    set_cur_iteration $sample_name $CUR_ITERATION    
}
## each top level directory corresponds to a sample
for ddd in $FASTQ_DIRS; do
    process_sample $ddd
done

## Generate a single file with all results
### First add the sample name as a column before merging the files
out_file=$OUT_FOLDER/results.tsv.gz
rm -f $out_file $out_file.tmp
for ddd in $FASTQ_DIRS; do
    sample_name=$(basename $ddd)
    f=$OUT_FOLDER/$sample_name/$sample_name.centroids.fasta.tsv
    if [ ! -e $f ]; then
	perror "File $f not found"
	exit 3
    fi
    if [ ! -e $out_file.tmp ]; then
	head -n 1 $f | sed 's/^/sample\t/' > $out_file.tmp
    fi
    tail -n +2 $f | sed "s/^/$sample_name\t/" >> $out_file.tmp
done
gzip $out_file.tmp
mv $out_file.tmp.gz $out_file



exit 0

# #reads/#batches/%id/species

grep -v "^>" xxx |while read n; do
    if [ $prev -ne 0 ]; then
done
