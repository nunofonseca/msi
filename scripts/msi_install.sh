#!/usr/bin/env bash
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

## OS tools
SYSTEM_DEPS="wget gunzip grep git perl /usr/bin/time bash java pip3 python3 Rscript R make cmake"

SYSTEM_PACKS="ncurses-devel libcurl-devel openssl-devel pandoc python3-devel"

## TOOLS
ALL_TOOLS="fastq_utils metabinkit fastqc cutadapt  isONclust minimap2 racon cd-hit R_packages msi"
ALL_SOFT="$ALL_TOOLS  blast_db_slow blast_db"

#ALL_TOOLS="isONclust minimap2 racon cd-hit R_packages msi"

# upgraded 2019-12-04:
cutadapt_VERSION=2.10
# https://pypi.org/project/isONclust/
isONclust_VERSION=0.0.6


metabinkit_VERSION=0.2.1
metabinkit_URL=https://github.com/envmetagen/metabinkit/archive/${metabinkit_VERSION}.tar.gz

fastq_utils_VERSION=0.24.1
fastq_utils_URL=https://github.com/nunofonseca/fastq_utils/archive/$fastq_utils_VERSION.tar.gz

FASTQC_VERSION=0.11.9
FASTQC_URL=http://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v${FASTQC_VERSION}.zip

##

minimap2_VERSION=2.17
minimap2_URL="https://github.com/lh3/minimap2/releases/download/v$minimap2_VERSION/minimap2-${minimap2_VERSION}_x64-linux.tar.bz2"

CD_HIT_VERSION=4.8.1
CD_HIT_DATE=2019-0228
CD_HIT_URL=https://github.com/weizhongli/cdhit/releases/download/V$CD_HIT_VERSION/cd-hit-v${CD_HIT_VERSION}-$CD_HIT_DATE.tar.gz

#
racon_VERSION=1.4.13
racon_URL="https://github.com/lbcb-sci/racon/releases/download/$racon_VERSION/racon-v${racon_VERSION}.tar.gz"

envir_name=test_msi_env
####################################################################
##
function install_blast_db_slow {
    pinfo "Installing blast database to $INSTALL_DIR/db..."
    pushd $INSTALL_DIR/db
    ## depends on blast
    update_blastdb.pl  --verbose nt taxdb  
    popd
    pinfo "Installing blast database...done"
}
function install_blast_db {
    pinfo "Installing blast database to $INSTALL_DIR/db..."
    mkdir -p $INSTALL_DIR/db
    pushd $INSTALL_DIR/db
    gem install --verbose ncbi-blast-dbs
    ncbi-blast-dbs nt taxdb
    for f in $(ls *.tar.gz); do
	tar xzvf $f
	rm -f $f
    done
    ## make index
    ##makembindex -input nt
    popd
    pinfo "Installing blast database...done"
}


function install_fastq_utils {
    pinfo "Installing fastq_utils..."
    rm -f tmp.tar.gz
    wget -c $fastq_utils_URL -O tmp.tar.gz
    tar -zxvf tmp.tar.gz
    pushd fastq_utils-${fastq_utils_VERSION}
    CFLAGS=  ./install_deps.sh
    make install
    cp bin/fast* bin/bam*  $INSTALL_BIN
    popd
    rm -rf fastq_utils-${fastq_utils_VERSION} tmp.tar.gz
    pinfo "Installing fastq_utils...done."
}

function install_metabinkit {
    pinfo "Installing metabinkit..."
    rm -f tmp.tar.gz
    wget -c $metabinkit_URL -O tmp.tar.gz
    tar -zxvf tmp.tar.gz
    pushd metabinkit-${metabinkit_VERSION}
    CFLAGS=  ./install.sh -i $INSTALL_DIR
    popd
    rm -rf metabinkit-${metabinkit_VERSION} tmp.tar.gz
    pinfo "Installing metabinkit...done."
}


function install_fastqc { 
    
    ########
    echo "Installing fastqc..."
    rm -f tmp.tar.gz
    wget -c  $FASTQC_URL -O tmp.tar.gz
    unzip tmp.tar.gz
    mkdir -p $INSTALL_BIN
    rm -rf $INSTALL_BIN/FastQC  $INSTALL_BIN/fastqc
    mv FastQC $INSTALL_BIN
    pushd $INSTALL_BIN/FastQC
    chmod 755 fastqc
    sed "s.^#\!/usr/bin/perl.#\!/usr/bin/env perl." -i fastqc
    ln -s `pwd`/fastqc $INSTALL_BIN
    ## increase default memory
    sed -i "s/Xmx250m/Xmx1250m/" fastqc
    popd
    echo "Installing fastqc...done."
}


function install_cutadapt {
    pinfo "Installing cutadapt..."
    #pip install --prefix $INSTALL_DIR
    #cutadapt.readthedocs.io/en/stable/installation.html
    #dependencies:
    #check that python2.7 or at least 3.6 are installed
    #Possibly a C compiler. For Linux, cutadapt packages are provided as so-called “wheels” (.whl files) which come pre-compiled.
    #Under Ubuntu, you may need to install the packages build-essential and python-dev (or python3-dev) to get a C compiler.
    set +ex
    pip3 uninstall -y cutadapt || pinfo No previous installation of cutadapt found
    set -ex
    export PYTHONUSERBASE=$INSTALL_DIR/python
    pip3 install --upgrade-strategy only-if-needed cutadapt==$cutadapt_VERSION --user
    pinfo "Installing cutadapt...done."
}

function install_isONclust {
    pinfo "Installing isONclust..."
    ## https://github.com/ksahlin/isONclust
    ## 2019-04-29: does not work as advertised (broken examples) - comment line 157
    export PYTHONUSERBASE=$INSTALL_DIR/python
    pip3 install  wheel --user
    pip3 install parasail --user
    pip3 install isOnclust==$isONclust_VERSION --user
    
    #git clone https://github.com/ksahlin/isONclust.git
    #cd isONclust
    pinfo "Installing isONclust...done."
}

function install_minimap2 {
    pinfo "Installing minimap2..."
    pushd $TEMP_FOLDER
    rm -f tmp.tar.gz
    wget -c $minimap2_URL -O tmp.tar.gz
    tar -jxvf tmp.tar.gz
    cp minimap2-${minimap2_VERSION}_x64-linux/{minimap2,k8,paftools.js} $INSTALL_BIN
    rm -rf minimap2-${minimap2_VERSION}_x64-linux  tmp.tar.gz
    popd
    pinfo "Installing minimap2...done."
}

function install_racon {
    pinfo "Installing racon..."
    pushd $TEMP_FOLDER
    rm -f tmp.tar.gz
    wget -c $racon_URL -O tmp.tar.gz
    tar -xzvf tmp.tar.gz
    cd racon-v${racon_VERSION}
    mkdir -p build
    pushd build
    cmake -DCMAKE_BUILD_TYPE=Release ..
    make
    cp bin/racon $INSTALL_BIN
    popd
    rm -rf racon
    popd
    pinfo "Installing racon...done."
}

function install_msi {
    pinfo "Installing msi..."
    pushd $PATH2SCRIPT/..
    cp scripts/* $INSTALL_BIN
    cp -r LICENSE README.md $INSTALL_DIR
    cp -r template $INSTALL_DIR
    popd
    pinfo "Installing msi...done."
}


function install_cd-hit {
    pinfo "Installing cd-hit..."
    pushd $TEMP_FOLDER
    rm -f tmp.tar.gz
    wget -c $CD_HIT_URL -O tmp.tar.gz
    tar -zxvf tmp.tar.gz
    pushd cd-hit-v$CD_HIT_VERSION-$CD_HIT_DATE
    make
    PREFIX=$INSTALL_BIN  make install
    popd
    rm -rf cd-hit-v$CD_HIT_VERSION-$CD_HIT_DATE tmp.tar.gz
    popd
    pinfo "Installing cd-hit...done."
}

function install_R_packages {
    mkdir -p $INSTALL_DIR/Rlibs
    R_LIBS_USER=$INSTALL_DIR/Rlibs R --vanilla <<EOF
repo<-"http://www.stats.bris.ac.uk/R/"

########################
# Check if version is ok
version <- getRversion()
currentVersion <- sprintf("%d.%d", version\$major, version\$minor)
message("R version:",version)
usebiocmanager<-TRUE
if ( version\$major < 3 || (version\$major>=3 && version\$minor<5) ) {
  cat("ERROR: R version should be 3.5 or above\n")
  q(status=1)
}

########################
# Where to install the packages
assign(".lib.loc",.libPaths()[1],envir=environment(.libPaths))

message("Using library: ", .libPaths()[1])
##print(.libPaths())

message("_____________________________________________________")

if (version\$major > 3 || (version\$major == 3 && version\$minor>5)) {
   if (!requireNamespace("BiocManager", quietly = TRUE))
       install.packages("BiocManager",repo=repo)
   BiocManager::install()
} else {
   usebiocmanager<-FALSE
   source("http://bioconductor.org/biocLite.R")
} 

message("_____________________________________________________")

message("Installing packages")
packages2install<-c("Matrix","data.table","devtools","shiny","plotly","DT","r2d3","tidyr","sunburstR","d3heatmap","gplots","rmarkdown","flexdashboard","d3Tree")

for (p in packages2install ) {
  message("PACKAGE:",p,"\n")
  if ( usebiocmanager ) BiocManager::install(p,ask=FALSE)
  else  biocLite(p,ask=FALSE)
}

#message("PACKAGE:","d3treeR","\n")
#devtools::install_github("timelyportfolio/d3treeR")


EOF

    
}



######################################################################
function pinfo {
    echo "[INFO] $*"
}

function usage {
    echo "Usage: msi_install.sh  [-x all|tool_name -i toplevel_installation_folder]  ";
    echo " -x software: install/update software.";
    echo " -i dir : install/update all files to directory 'dir' (default: $PWD/MSI)";
    echo " -C     - Conda installation mode"
    echo " -E     - install msi in a conda environment [$envir_name]"
    echo " -h     - print this help information"
}

function check_system_deps {
    local bin
    pinfo "Checking dependencies..."
    local MISSING=0
    for bin in $SYSTEM_DEPS; do
	local PATH2BIN=`which $bin 2> /dev/null`
	if [ "$PATH2BIN-" == "-" ]; then
	    pinfo " $bin not found!"
	    #
	    MISSING=1
	else
	    pinfo " $bin found: $PATH2BIN"
	fi
    done
    pinfo "Checking dependencies...done."
    if [ $MISSING == 1 ]; then
	pinfo "ERROR: Unable to proceed"
	exit 1
    fi

}

function install_all {
    check_system_deps    
    for tt in $ALL_TOOLS; do
	install_$tt
    done
}

function msi_to_docker {
    MSI_VERSION="0.2.11"
    set -e
    echo "Generating docker image with MSI...this may take a while"
    pushd $PATH2SCRIPT/..
    docker build -f msi.dockerfile -t "msi/$MSI_VERSION" .
    exit 0
}

## default installation folder
INSTALL_DIR=$PWD/msi
set +eu
if [ "$MSI_DIR-" != "-" ]; then
    ## update previous installation
    INSTALL_DIR=$MSI_DIR
fi

## by default install all software
MODE=all
DEBUG=0
CONDA_INSTALL=0
CONDA_ENVIR=0
set -x
set +u
while getopts "i:x:hHDdCE"  Option
do
    case $Option in
	C) CONDA_INSTALL=1;;
	E) CONDA_ENVIR=1;;
	i) INSTALL_DIR=$OPTARG;;
	x) MODE=$OPTARG;;
	d) DEBUG=1;;
	D) msi_to_docker;;
	h ) usage; exit;;
	H ) usage; exit;;
	* ) usage; exit 1;;
    esac
done

if [ $DEBUG == 1 ]; then
    set -eux
else
    set +x
    set -eu
fi


if [ "x`uname`" == "xLinux" ] ; then
    ## readlink does not work in MacOS
    ## 
    INSTALL_DIR=$(readlink -f $INSTALL_DIR)
fi

MSI_DIR=$INSTALL_DIR


## PREFIX=INSTALL_DIR
INSTALL_BIN=$INSTALL_DIR/bin
TEMP_FOLDER=$INSTALL_DIR/tmp
set -eu

mkdir -p $INSTALL_BIN
TEMP_FOLDER=$(mktemp -d)
##-p $PWD)
mkdir -p $TEMP_FOLDER

function gen_env_sh {
    env_file=$1
    pinfo "Generating $1..."
    python_dir=python$(python --version 2> /dev/stdout | sed "s/.* \(.*\)\..*/\1/")
    python3_dir=python$(python3 --version 2> /dev/stdout | sed "s/.* \(.*\)\..*/\1/")
    set +u
    if [ "$PYTHONPATH-" == "-" ]; then
	PYTHONPATH=.
    fi
    set -u
    cat <<EOF > $env_file
# source $env_file
# Created `date`
export PATH=$INSTALL_BIN:\$PATH    
export MSI_DIR=$INSTALL_DIR
set +u
## Python
export PYTHONUSERBASE=\$MSI_DIR/python
export PYTHONPATH=$MSI_DIR/:$PYTHONPATH
## lib64/$python_dir/site-packages:\$MSI_DIR/lib/$python_dir/site-packages:\$MSI_DIR/lib64/$python3_dir/site-packages:\$MSI_DIR/lib/$python3_dir/site-packages:$PYTHONPATH
## R packages
export R_LIBS=\$MSI_DIR/Rlibs:\$R_LIBS
PATH=\$MSI_DIR/python/bin:\$PATH
if [ -e $MSI_DIR/metabinkit_env.sh ]; then
   source $MSI_DIR/metabinkit_env.sh
fi
EOF
    pinfo "Generating $1...done"
}

MSI_ENV_FILE=$INSTALL_DIR/msi_env.sh
if [ ! -e $MSI_ENV_FILE ]; then
    gen_env_sh $MSI_ENV_FILE    
fi

source $MSI_ENV_FILE

## 
## create a bioconda environment with msi
if [ "$CONDA_ENVIR-" == "1-" ]; then
    echo "You should have run `conda init bash` first"
    set +x
    conda create -y --name $envir_name
    #conda install -n $envir_name -c bioconda  -c conda-forge python=3.7 -y
    conda install -n $envir_name -c bioconda  -c conda-forge python=3.8 -y
    conda install -n $envir_name -c bioconda  -c conda-forge metabinkit=$metabinkit_VERSION -y
    conda install -n $envir_name -c bioconda  -c conda-forge cutadapt=$cutadapt_VERSION -y
    conda install -n $envir_name -c bioconda  -c conda-forge isOnclust=$isONclust_VERSION -y
    conda install -n $envir_name -c bioconda  -c conda-forge fastq_utils=$fastq_utils_VERSION -y
    conda install -n $envir_name -c bioconda  -c conda-forge fastqc=$fastqc_VERSION -y
    conda install -n $envir_name -c bioconda  -c conda-forge minimap2=$minimap2_VERSION -y
    conda install -n $envir_name -c bioconda  -c conda-forge cd-hit=$cd_hit_VERSION -y
    conda install -n $envir_name -c bioconda  -c conda-forge racon=$racon_VERSION -y
    #1.4.13-he513fc3_0
    conda install -n $envir_name -c bioconda -c conda-forge pilon=1.23 -y
    echo "type
conda activate $envir_name
to activate the conda environment and then run
msi_install.sh -i \$CONDA_PREFIX -x msi"
    INSTALL_DIR=$CONDA_PREFIX
    exit 0
fi

if [ "$CONDA_INSTALL-" == "1-" ]; then
    install_msi
    #install_R_packages
    exit 0
fi
x="-$(echo $ALL_SOFT make|sed -E 's/\s+/-|-/g')|-all-"
echo $x
if [[ "-$MODE-" =~ ^($x) ]]; then
    pinfo "Installation mode: $MODE"
else
    pinfo Valid values for -x: $ALL_SOFT
    echo ERROR: invalid value $MODE for -x parameter
    rm -rf $TEMP_FOLDER
    exit 1
fi

set -u
pinfo "Installation folder: $INSTALL_DIR"
install_$MODE
rm -rf $TEMP_FOLDER
exit 0
