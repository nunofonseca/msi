#!/usr/bin/env bash

PATH2SCRIPT=$(dirname "${BASH_SOURCE[0]}" )

PATH2MSI=$(which msi)
if [ "$MSI_DIR-" == "-" ]; then
    if [ "$PATH2MSI-" == "-" ]; then
	# use current folder (last resort)
	MSI_DIR=$(readlink -f $PATH2SCRIPT/..)
    else
	MSI_DIR=$(readlink -f $(dirname $PATH2MSI)/..)
    fi
fi

export MSI_DIR=$MSI_DIR

set -u
source $PATH2SCRIPT/tests_aux.sh

## use the most recent version of the scripts
PATH=$PATH2SCRIPT/../scripts:$PATH

PATH2TESTS=$PATH2SCRIPT
TMPDIR=$PWD/msi_tests_res
NULL_REDIR=/dev/null
NULL_REDIR=/dev/stdout

######################################################


## test params file


echo "*** msi tests - db generation"
## use metabinkit wrapper
must_succeed "metabinkit_blastgendb -f $PATH2TESTS/fasta/test_refdb.fasta -o $TMPDIR/refdb/db1 -t 2"
must_succeed "metabinkit_blastgendb -f $PATH2TESTS/fasta/test_refdb.fasta -o $TMPDIR/refdb/db2 -t 2"
#must_succeed "metabinkit_blastgendb -f $PATH2TESTS/fasta/test_refdb.fasta -o $TMPDIR/refdb/db2 -c -t 2"

echo "*** msi tests"

set +xe
must_fail "msi &> $NULL_REDIR"
must_fail "msi -i __folder_not_found &> $NULL_REDIR"
# no file
must_fail "msi -i tests/samples/s1/ -I tests/metadata/metadataee1.tsv -S &> $NULL_REDIR"
# missing column
must_fail "msi -i tests/samples/s1/ -I tests/metadata/metadatae1.tsv -S &> $NULL_REDIR"
# fastq file not in metadata
must_fail "msi -I tests/metadata/metadata1.tsv  -i tests/samples/s1/ -o $TMPDIR/tt0 &> $NULL_REDIR"

## skip blast
must_succeed "msi  -I tests/metadata/metadata1.tsv -S -i tests/samples/s1/ -o $TMPDIR/t1"
must_succeed "zdiff -q ./tests/out/t1.running.stats.tsv.gz $TMPDIR/t1/running.stats.tsv.gz"

must_succeed "msi -I tests/metadata/metadata1.tsv -r  -S -i tests/samples/s1/ -o $TMPDIR/t2"
must_succeed "zdiff -q $TMPDIR/t2/running.stats.tsv.gz $TMPDIR/t2/running.stats.tsv.gz"


# no results for binning 
must_succeed "msi  -I tests/metadata/metadata1.tsv  -i tests/samples/s1/ -o $TMPDIR/t1 -b $TMPDIR/refdb/db1"

# try again with a new database
must_succeed "msi  -I tests/metadata/metadata1.tsv  -i tests/samples/s1/ -o $TMPDIR/t1 -b $TMPDIR/refdb/db2"

## works
must_succeed "msi  -I tests/metadata/metadata2.tsv  -i tests/samples/s4/ -o $TMPDIR/t4 -b $TMPDIR/refdb/db1"

## samples
must_succeed "msi  -I tests/metadata/metadata2.tsv  -i tests/samples/s5/ -o $TMPDIR/t5 -b $TMPDIR/refdb/db1"

must_succeed " [ $(zcat  $TMPDIR/t5/binres.tsv.gz|cut -f 1|tail -n +2|sort -u|wc -l) == 2 ]"
must_succeed " [ $(zcat  $TMPDIR/t5/results.tsv.gz|cut -f 1|tail -n +2|sort -u|wc -l) == 2 ]"

cat <<EOF > $TMPDIR/msi.params
METADATAFILE=tests/metadata/metadata2.tsv
blast_refdb=$TMPDIR/refdb/db1
CLUSTER_MIN_READS=1
CD_HIT_CLUSTER_THRESHOLD=0.99
EXPERIMENT_ID=
PRIMER_MAX_ERROR=0.2
TAXONOMY_DATA_DIR=$MSI_DIR/db
TL_DIR=tests/samples/s5
IGNORE_UNCLASSIFIED=1
OUT_FOLDER=$TMPDIR/t5a
CLUST_MAPPED_THRESHOLD=0.825
CLUST_ALIGNED_THRESHOLD=0.55
blast_evalue=0.001
blast_max_target_seqs=20
blast_perc_identity=70

mbk_Species=96
mbk_Genus=92
mbk_Family=92
mbk_AboveF=92
mbk_TopSpecies=100
mbk_TopGenus=1
mbk_TopFamily=1
mbk_TopAF=1
mbk_rm_predicted=ssciname
mbk_sp_discard_sp=
mbk_mt2w=
mbk_sp_discard_num=
EOF

cat <<EOF > $TMPDIR/msi2.params
METADATAFILE=tests/metadata/metadata2.tsv
blast_refdb=$TMPDIR/refdb/db1
CLUSTER_MIN_READS=1
CD_HIT_CLUSTER_THRESHOLD=0.99
EXPERIMENT_ID=
PRIMER_MAX_ERROR=0.2
TAXONOMY_DATA_DIR=$MSI_DIR/db
TL_DIR=tests/samples/
IGNORE_UNCLASSIFIED=0
OUT_FOLDER=$TMPDIR/t5a
CLUST_MAPPED_THRESHOLD=0.825
CLUST_ALIGNED_THRESHOLD=0.55
blast_evalue=0.001
blast_max_target_seqs=20
blast_perc_identity=70

mbk_Species=96
mbk_Genus=92
mbk_Family=92
mbk_AboveF=92
mbk_TopSpecies=100
mbk_TopGenus=1
mbk_TopFamily=1
mbk_TopAF=1
mbk_rm_predicted=ssciname
mbk_sp_discard_sp=
mbk_mt2w=
mbk_sp_discard_num=
EOF


must_succeed "msi  -c $TMPDIR/msi.params"

must_succeed " [ $(zcat  $TMPDIR/t5a/binres.tsv.gz|cut -f 1|tail -n +2|sort -u|wc -l) == 2 ]"
must_succeed " [ $(zcat  $TMPDIR/t5a/results.tsv.gz|cut -f 1|tail -n +2|sort -u|wc -l) == 2 ]"

must_succeed "msi  -c $TMPDIR/msi2.params -S"


must_succeed "msi  -I tests/metadata/metadata2.tsv  -i tests/samples/s4/ -o $TMPDIR/t4 -b $TMPDIR/refdb/db1"

must_succeed " [ $(zcat  $TMPDIR/t4/binres.tsv.gz|wc -l) == $(zcat  $TMPDIR/t4/results.tsv.gz|wc -l) ] "

#1 samples
must_succeed " [ $(zcat  $TMPDIR/t4/binres.tsv.gz|cut -f 1|tail -n +2|sort -u|wc -l) == 1 ]"



#params

##############################


echo Failed tests: $num_failed
echo Number of tests: $num_tests

exit

if [ $num_failed == 0 ]; then
    rm -rf $TMPDIR
fi
exit $num_failed


