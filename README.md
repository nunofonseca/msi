## msi ![Docker](https://github.com/nunofonseca/msi/workflows/Docker/badge.svg?branch=master) [![License](http://img.shields.io/badge/license-GPL%203-brightgreen.svg?style=flat)](http://www.gnu.org/licenses/gpl-3.0.html) 


1. [Overview](#Overview)
2. [Docker](#Docker)
3. [Manual installation](#Installation)
4. [Databases](#Databases)
5. [Running MSI](#Running-MSI)


### Overview

### Docker

A docker file is provided in the top level of MSI (Dockerfile) that will wrap everything required to run a MSI analysis. This facilitates the setup and installation of MSI, and track all software versions used in the analyses. See the [Docker userguide](https://docs.docker.com/) for more details.

Alternatively you may install the software from source following the instructions provided next. A 64 bit computer with an up to date Linux OS installed will be required.

#### Pre-built docker image with MSI

A pre-built image with the latest version of MSI can be dowloaded with the following command:
 
`docker pull docker.pkg.github.com/nunofonseca/msi/image:latest`


##### Creating a docker image with MSI

A docker image containing MSI can be created, after downloading MSI, by running the following command:

`docker build -f Dockerfile -t msi/latest .`

See the [Docker userguide](https://docs.docker.com/) for more details.

##### How to run MSI in a docker container

Next we provide two ways of running a MSI container in non-interactive mode.

TODO TODO

See the [Docker userguide](https://docs.docker.com/) for more details on how to run containers in interactive and non-interactive mode.

### Installation

There are two main options to install MSI:
1) installating to a folder in your file system (only Linux OS is supported). This involves downloading MSI from GitHub, unpacking, compiling and running the install script to install MSI and 3rd party software
2) docker: An alternative option involves creating/downloading a docker image with MSI (a docker file for MSI is available at https://github.com/nunofonseca/msi/blob/master/msi.dockerfile).


#### Download

Using git:

`git clone https://github.com/nunofonseca/msi.git`

or download and unpack the zip file
`wget https://github.com/nunofonseca/msi/archive/master.zip`
`unzip master.zip`

#### Compile and install

To install MSI to a specific folder (e.g., ~/msi) run
`./scripts/msi_install.sh -i ~/msi`

The installation script will install third party software used by MSI (e.g., R packages, blast, etc) therefore it will need internet acess and will take several minutes to conclude.

Note: Ensure that you have write permission to the parent folder.


#### Configuration

When the installation is complete, a file called `msi_env.sh` will be created in the top level folder (~/msi in the above example).

The following line should be run in a terminal or added to $HOME/.bashrc

`source TOPLEVEL_FOLDER/env.sh`

where TOPLEVEL_FOLDER should be replaced by the toplevel folder (~/msi in the above example).

### Databases


#### Taxonomy

MSI requires the NCBI taxonomy database available from ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz. By default the msi_install.sh script will download the database to `$MSI_DIR/db`, where `MSI_DIR` is the folder where MSI was installed.

#### BLAST

A BLAST database may be optionally downloaded from NCBI (nt database) to $MSI_DIR/db by running the following command after having MSI installed and configured. 

`./scripts/install.sh -i $MSI_DIR -x blast_db`

### Running MSI

`msi.sh [options] -i raw_data_toplevel_folder -o output_folder`

where `raw_data_toplevel_folder` should correspond to the path to the folder where the fastq files (compressed with gzip) may be found. MSI will look to the top level folder and subfolders for all files with the filename extension .fastq.gz.

To get a full list of options run
`msi.sh -h`

If running MSI in a docker then the command `msi_docker` may be used instead.
For instance,

`msi_docker -h`

### Parameters file

Parameters may be passed to `msi.sh` in the command line or provided in a text file.

An example of the contents of a file with the parameters for MSI is shown next.
```
THREADS=5                          # maximum number of threads
METADATAFILE=samplesheet.tsv       # metadata about each fastq file
LOCAL_BLAST_DB=local_db            # path to blast database
CLUSTER_MIN_READS=1                # minimum number of reads per cluster
CD_HIT_CLUSTER_THRESHOLD=0.99      # cluster/group reads with a similitiry greater than the given threshould (range from 0 to 1)
PRIMER_MAX_ERROR=0.2               # maximum error accepted when matching a primer sequence to the reads
TAXONOMY_DATA_DIR=$MSI_DIR/db      # path to the taxonomy database 
TL_DIR=path/to/fastq/files         # path to the toplevel folder containing the fastq files to be processed
OUT_FOLDER=results                 # path to the folder where the files produced by MSI will be stored
```
Assuming that the file myexp.conf contains the above lines, MSI could be started by running

`msi.sh -c myexp.conf`


### Metadata file

The metadata file (TSV format) provides information for each file to be processed. The file shouls contain the at least the columns barcode_name, sample_id, ss_sample_id, primer_set, primer_f, primer_r, min_length, max_length, target_gene where:

- primer_set:
- primer_f:
- primer_r:
- min_length:
- max_length:
- target_gene:


## Output files

# Visualising the results
