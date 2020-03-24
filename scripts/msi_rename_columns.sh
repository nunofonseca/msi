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

## 
set -eu
set -o pipefail

# change msi code to load the metadata file and change/share code
# swap column 1 corresponding to column X to column Y
## tsv_file metadata_file outfile -metadata_column_old -metadata_column_new -experimen_id 

################
# Default values
METADATA_COLUMN_OLD=barcode_name
METADATA_COLUMN_NEW=ss_sample_id
METADATAFILE=
TSV_FILE=

##################################################################
## 
function usage {
    echo "msi_rename_columns.sh [-e experiment_id -O old_metadata_column -N new_metadata_column -h] -i tsv_folder -I metadata_file "
    cat <<EOF
 -i tsv_file  
 -I metadata   - metadata file*
 -e EXPERIMENT_ID
 -O old_metadata_column - should exist in the metadata_file [default: barcode_id]
 -N new_metadata_column - should exist in the metadata_file [default: sample_id]
 -o out_folder -  output file
 -h  - provides usage information

*metadata file: tsv file were the file name should be found in one column and the column names (first line of the file) X, Y, Z should exist.
EOF
}
#######################################################################################
# 
while getopts "O:N:I:e:i:dh"  Option; do
    case $Option in
	i ) TSV_FILE=$OPTARG;;
	d ) set -x;;
	e ) EXPERIMENT_ID=$OPTARG;;
	O ) METADATA_COLUMN_OLD=$OPTARG;;
	N ) METADATA_COLUMN_NEW=$OPTARG;;
	I ) METADATAFILE=$OPTARG;;
	h) usage; exit;;
    esac
done

## Check and validate arguments
if [ "$TSV_FILE-" == "-" ]; then
    perror "no value given to parameter -i"
    usage
    exit 1
fi
if [ ! -e $TSV_FILE ]; then
    perror "invalid value given to -i: $TSV_FILE should be a readable file"
    usage
    exit 1
fi

MD_EXPECTED_COLS="$METADATA_COLUMN_OLD $METADATA_COLUMN_NEW sample_id"

## Validate and load the metadata file
validate_metadata_file $METADATAFILE
load_metadata $METADATAFILE $EXPERIMENT_ID

OLD_COLUMN_NUM=$(get_metadata_col_pos $METADATA_COLUMN_OLD)
NEW_COLUMN_NUM=$(get_metadata_col_pos $METADATA_COLUMN_NEW)

tmp=$(mktemp -p . .msi_rename_XXX)
tmp=a
zcat $TSV_FILE|  tail -n +2 | sort -k1,1 > $tmp.1

## header
set +e
zcat $TSV_FILE |head -n 1
set -e
awk -v  c1="${OLD_COLUMN_NUM}" -v c2="${NEW_COLUMN_NUM}" 'BEGIN {FS="\t"; OFS="\t"} {print $c1,$c2 }' $METADATAFILE | tail -n +2 | sort -k1,1 > $tmp.2
join -t$'\t' $tmp.2 $tmp.1  | cut -f 2-

rm -f $tmp.2 $tmp.1 

exit 0


