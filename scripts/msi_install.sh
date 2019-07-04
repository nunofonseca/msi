#!/usr/bin/env bash


## default installation folder
INSTALL_DIR=$PWD/msi

if [ "$MSI_DIR-" != "-" ]; then
    ## update previous installation
    INSTALL_DIR=$MSI_DIR
fi
MSI_DIR=$INSTALL_DIR

INSTALL_DIR=$(readlink -f $INSTALL_DIR)
## PREFIX=INSTALL_DIR
INSTALL_BIN=$INSTALL_DIR/bin
TEMP_FOLDER=$INSTALL_DIR/tmp
set -eu


#########################################################
## OS tools
SYSTEM_DEPS="gunzip grep git perl /usr/bin/time bash java pip3 python3 Rscript R make cmake"

SYSTEM_PACKS="ncurses-devel libcurl-devel openssl-devel pandoc"

## TOOLS
ALL_TOOLS="fastq_utils taxonkit fastqc cutadapt blast isONclust minimap2 racon cd-hit R_packages"

cutadapt_VERSION=2.3
isONclust_VERSION=0.0.4

blast_VERSION=2.9.0
blast_URL=ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/ncbi-blast-${blast_VERSION}+-x64-linux.tar.gz

fastq_utils_VERSION=0.19.3
fastq_utils_URL=https://github.com/nunofonseca/fastq_utils/archive/$fastq_utils_VERSION.tar.gz

FASTQC_VERSION=0.11.8
FASTQC_URL=http://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v${FASTQC_VERSION}.zip

##
TAXONKIT_VERSION=0.3.0
TAXONKIT_URL=https://github.com/shenwei356/taxonkit/releases/download/v$TAXONKIT_VERSION/taxonkit_linux_amd64.tar.gz


minimap2_VERSION=2.16
minimap2_URL="https://github.com/lh3/minimap2/releases/download/v$minimap2_VERSION/minimap2-${minimap2_VERSION}_x64-linux.tar.bz2"

CD_HIT_VERSION=4.8.1
CD_HIT_DATE=2019-0228
CD_HIT_URL=https://github.com/weizhongli/cdhit/releases/download/V$CD_HIT_VERSION/cd-hit-v${CD_HIT_VERSION}-$CD_HIT_DATE.tar.gz

####################################################################
## 
function install_blast {
	pinfo "Installing blast..."
	pushd $TEMP_FOLDER
	wget -c $blast_URL -O tmp.tar.gz
	tar zxvpf tmp.tar.gz
	cp ncbi-blast-${blast_VERSION}+/bin/* $INSTALL_BIN
	## taxonomy
	wget -c ftp://ftp.ncbi.nlm.nih.gov/blast/db/taxdb.tar.gz
	mkdir -p $INSTALL_DIR/db
	mv taxdb.tar.gz $INSTALL_DIR/db
	pushd $INSTALL_DIR/db
	tar xzvf taxdb.tar.gz
	rm -f taxdb.tar.gz
	popd
	popd
	pinfo "Installing blast...done."
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

function install_taxonkit {
    echo "Installing taxonkit.."
    pushd $TEMP_FOLDER
    rm -f tmp.tar.gz
    wget -c  $TAXONKIT_URL -O tmp.tar.gz
    tar xzvf tmp.tar.gz
    mkdir -p $INSTALL_BIN
    chmod +x taxonkit
    mv taxonkit $INSTALL_BIN
    rm -f tmp.tar.gz
    popd
    echo "Installing taxonkit..done."
}

function install_fastqc { 
    
    ########
    echo "Installing fastqc..."
    rm -f tmp.tar.gz
    wget -c  $FASTQC_URL -O tmp.tar.gz
    unzip tmp.tar.gz
    mkdir -p $INSTALL_DIR
    rm -rf $INSTALL_DIR/FastQC  $INSTALL_DIR/fastqc
    mv FastQC $INSTALL_DIR
    pushd $INSTALL_DIR/FastQC
    chmod 755 fastqc
    sed "s.^#\!/usr/bin/perl.#\!/usr/bin/env perl." -i fastqc
    ln -s `pwd`/fastqc $INSTALL_DIR
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
    pip3 install --upgrade-strategy only-if-needed --prefix $INSTALL_DIR cutadapt==$cutadapt_VERSION
    pinfo "Installing cutadapt...done."
}

function install_isONclust {
    pinfo "Installing isONclust..."
    ## https://github.com/ksahlin/isONclust
## 2019-04-29: does not work as advertised (broken examples) - comment line 157
    pip3 install --prefix $INSTALL_DIR wheel
    pip3 install --prefix $INSTALL_DIR parasail
    pip3 install --prefix $INSTALL_DIR   isOnclust==$isONclust_VERSION
    
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
    cp minimap2-${minimap2_VERSION}_x64-linux/minimap2 $INSTALL_BIN
    rm -rf minimap2-${minimap2_VERSION}_x64-linux  tmp.tar.gz
    popd
    pinfo "Installing minimap2...done."
}

function install_racon {
    pinfo "Installing racon..."
    pushd $TEMP_FOLDER
    rm -f tmp.tar.gz
    git clone --recursive https://github.com/isovic/racon.git racon
    mkdir -p racon/build
    pushd racon/build
    cmake -DCMAKE_BUILD_TYPE=Release ..
    make
    cp bin/racon $INSTALL_BIN
    popd
    rm -rf racon
    popd
    pinfo "Installing racon...done."
}


function install_cd-hit {
    pinfo "Installing cd-hit..."
    pushd $TEMP_FOLDER
    rm -f tmp.tar.gz
    wget -c $CD_HIT_URL -O tmp.tar.gz
    tar -zxvf tmp.tar.gz
    pushd cd-hit-v$CD_HIT_VERSION-$CD_HIT_DATE
    make
    PREFIX=$INSTALL_DIR  make install
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
source("http://bioconductor.org/biocLite.R")
message("_____________________________________________________")

message("Installing packages")
packages2install<-c("Matrix","data.table","devtools","shiny","plotly","DT","r2d3","tidyr","sunburstR","d3heatmap","gplots","rmarkdown","flexdashboard","d3Tree")

for (p in packages2install ) {
  message("PACKAGE:",p,"\n")
  biocLite(p,ask=FALSE)
}

#message("PACKAGE:","d3treeR","\n")
#devtools::install_github("timelyportfolio/d3treeR")


EOF

    
}

###############################################################
##

## local blast db
## depends on blast
## mkdir -p ~/blastdb; pushd ~/blastdb
## update_blastdb.pl  --verbose nt taxdb 
## gem install ncbi-blast-dbs
## email="nf@ebi.ac.uk" ncbi-blast-dbs nt
## rm -f *.gz
## make index
# makembindex -input nt

# database
# http://ccb.jhu.edu/software/centrifuge/manual.shtml#nt-database
#wget ftp://ftp.ncbi.nih.gov/blast/db/FASTA/nt.gz
#gunzip nt.gz && mv -v nt nt.fa

# Get mapping file
#wget ftp://ftp.ncbi.nih.gov/pub/taxonomy/gi_taxid_nucl.dmp.gz
#gunzip -c gi_taxid_nucl.dmp.gz | sed 's/^/gi|/' > gi_taxid_nucl.map

#wget https://github.com/shenwei356/taxonkit/releases/download/v0.3.0/taxonkit_linux_amd64.tar.gz
#tar xzvf taxonkit_linux_amd64.tar.gz
# chmod +x taxonkit
# copy to a subfolderof blast
# wget ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz

######################################################################
function pinfo {
    echo "[INFO] $*"
}

function usage {
    echo "Usage: msi_install.sh  [-x all|tool_name -i toplevel_installation_folder]  ";
    echo " -x software: install/update software.";
    echo " -i dir : install/update all files to directory 'dir' (default: $PWD/MSI)";
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

## by default install all software
MODE=all
DEBUG=0
set +u
while getopts "i:x:hH"  Option
do
    case $Option in
	i) INSTALL_DIR=$OPTARG;;
	x) MODE=$OPTARG;;
	d) DEBUG=1;;
	h ) usage; exit;;
	H ) usage; exit;;
    esac
done

if [ $DEBUG == 1 ]; then
    set -eux
else
    set +eux
    set -eu
fi

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
export PYTHONPATH=$MSI_DIR/lib64/$python_dir/site-packages:\$MSI_DIR/lib/$python_dir/site-packages:\$MSI_DIR/lib64/$python3_dir/site-packages:\$MSI_DIR/lib/$python3_dir/site-packages:$PYTHONPATH
## R packages
export R_LIBS=\$MSI_DIR/Rlibs:\$R_LIBS

# BLAST
if [ "\$BLASTDB-" == "-" ]; then
export BLASTDB=\$MSI_DIR/db
fi
EOF
    pinfo "Generating $1...done"
}

MSI_ENV_FILE=$INSTALL_DIR/msi_env.sh
if [ ! -e $MSI_ENV_FILE ]; then
    gen_env_sh $MSI_ENV_FILE    
fi

source $MSI_ENV_FILE

x="-$(echo $ALL_TOOLS make|sed -E 's/\s+/-|-/g')|-all-"
echo $x
if [[ "-$MODE-" =~ ^($x) ]]; then
    pinfo "Installation mode: $MODE"
else
    pinfo Valid values for -x: $ALL_TOOLS
    echo ERROR: invalid value $MODE for -x parameter
    rm -rf $TEMP_FOLDER
    exit 1
fi

set -u
pinfo "Installation folder: $INSTALL_DIR"
install_$MODE
rm -rf $TEMP_FOLDER
exit 0
