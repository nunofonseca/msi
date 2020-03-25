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
#source $PATH2SCRIPT/msi_shared.sh

## 
set -e
set -o pipefail

FASTQ_INFO_CMD=fastq_info
COMMANDS_NEEDED="$FASTQ_INFO_CMD"
# 
# 
for cmd in $COMMANDS_NEEDED; do
    command -v $cmd  >/dev/null 2>&1 || { echo "ERROR: $cmd  does not seem to be installed.  Aborting." >&2; exit 1; }
done

fastq_file=$1
note=$2
fastq_name=$3
fastq_info_file=$4

if [ "$note-" == "-" ]; then
    note="NA"
fi

if [ "$fastq_name-" == "-" ]; then
    sample_name=$(basename $1 .fastq.gz)
else
    sample_name=$fastq_name
fi
set -u 
if [ "$fastq_info_file-" == "-" ]; then
    fastq_info_file=$fastq_file.info
fi

if [ -e $fastq_info_file ] &&  [  $fastq_info_file -nt $fastq_file ]; then
    echo "skipping running fastq_info" >&2
else
    $FASTQ_INFO_CMD $fastq_file 2> $fastq_info_file
fi

nreads=$(grep "Number of reads:" $fastq_info_file | cut -f 2 -d:|tr -d " ")
qual_enc=$(grep "Quality encoding: " $fastq_info_file | cut -f 2 -d:|sed "s/^\s//")
qual_enc_range=$(grep "Quality encoding range: " $fastq_info_file | cut -f 2 -d:|sed "s/^\s//")
read_len=$(grep "Read length: " $fastq_info_file | cut -f 2 -d:|sed "s/^\s//")

echo "id note nreads quality_encoding quality_enc_min quality_enc_max read_len_min read_len_max read_len_avg" | sed "s/ /\t/g" 
echo "$sample_name $note $nreads $qual_enc $qual_enc_range $read_len"  | sed "s/ /\t/g" 

exit 0
