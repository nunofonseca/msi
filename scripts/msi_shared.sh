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

## shared code
set -eu
set -o pipefail

# used to filter the entries in metadata file
EXPERIMENT_ID=.

#######################################################################################
#
function pinfo {
    echo "==INFO: $*" 1>&2
}

function pwarn {
    echo "==WARNING: $*" 1>&2
}

function perror {
    echo "==ERROR: $*"  1>&2
}


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


#######################################################################################
MD_MIN_LENGTH=
MD_MAX_LENGTH=
MD_PRIMER_F=
MD_PRIMER_R=
MD_PRIMER_SET=
MD_BARCODE_NAME=
MD_TARGET_GENE=
MD_FILE=
MD_EXPECTED_COLS="barcode_name sample_id ss_sample_id primer_set primer_f primer_r min_length max_length target_gene"
declare -A MD


## return 0 if found/1 if not
function file_in_metadata_file {

    if [ "$1-" == "-" ]; then
	# nothing to do
	return
    fi
    if [ ! -e "$1" ]; then
	perror "file $1 not found or not readable"
	exit 1
    fi
    MD_FILE=$1
    set +u
    CFILE=$2
    set -u
    if [ $CFILE == "unclassified.fastq.gz" ] ; then
    return $IGNORE_UNCLASSIFIED
fi
    set +e
    # if CFILE/$2 is provided then look for the file in $MD_FILE
    if [ "$CFILE-" != "-" ]; then
	N=$( grep -E "$EXPERIMENT_ID" $MD_FILE | grep -i -c -E "(^|\s)$CFILE($|\s)")
	if [ $N == "0" ] && [ $CFILE != "unclassified.fastq.gz" ] ; then
	    local CFILE2=$(basename -s .fastq.gz $CFILE)
	    N=$( grep -E "$EXPERIMENT_ID" $MD_FILE | grep -i -c -E "(^|\s)$CFILE2($|\s)")
	    if [ $N == "0" ] && [ $CFILE != "unclassified.fastq.gz" ] ; then
		pwarn "File $CFILE not found in $MD_FILE"
		return 1
	    fi
	fi
	pinfo "Found info about $N primers associated to $CFILE"
    fi
    set -e
    return 0
}
function validate_metadata_file {

    if [ "$1-" == "-" ]; then
	# nothing to do
	return
    fi
    if [ ! -e "$1" ]; then
	perror "file $1 not found or not readable"
	exit 1
    fi
    MD_FILE=$1
    set +u
    CFILE=$2
    set -u
    ## check if the expected columns are present    
    set +e
    for EC in $MD_EXPECTED_COLS; do
	N=$(head -n 1 $MD_FILE| grep -i -c -E "(^|\s)$EC($|\s)")
	if [ $N == "0" ]; then
	    perror "Column $EC not found in $MD_FILE"
	    exit 1
	fi
    done
    set -e
}

function load_metadata {

    if [ "$1-" == "-" ]; then
	# nothing to do
	return
    fi
    if [ ! -e "$1" ]; then
	perror "file $1 not found or not readable"
	exit 1
    fi
    MD_FILE=$1
    # experiment_id
    local FILE=$2
     # # load
    local H=$(head -n 1 $MD_FILE|sed "s/ /_/g")
    let i=1
    for C in $H; do
	set +e
    	N=$(echo $MD_EXPECTED_COLS | grep -i -c -E "(^|\s)$C(\s|$)")
	set -e
    	if [ $N == 1 ]; then
    	    ## keep col number
    	    ## get all values of that column
	    local C_UP=${C^^}
	    set +e
	    x=$(grep -i -E "$EXPERIMENT_ID" $MD_FILE| grep -i -E "(^|\s)$FILE(\s|$)" |cut -f $i)
	    set -e
	    if [ "$x-" == "-" ]; then
		FILE=$(basename -s .fastq.gz $FILE )
		x=$(grep -i -E "$EXPERIMENT_ID" $MD_FILE| grep -i -E "(^|\s)$FILE(\s|$)" |cut -f $i)
	    fi
	    MD[$C_UP]="$x"
	    export MDP_$C_UP=$i
    	fi
	let i=$i+1
    done
    for EC in $MD_EXPECTED_COLS; do
	local v=${EC^^}
    done
}

## given a columan name returns the respective column numberin the header
function get_metadata_col_pos {

    local colname=$1
    local colname_up=${colname^^}
    set +u
    local var=MDP_$colname_up
    local pos=${!var}
    set -u
    echo $pos    
}
