# msi



# Installation

There are two options to install MSI. One options involves downloading the latest version of MSI, compiling and installing MSI and 3rd party software to your operating system (only Linux is supported). An alternative option involves creating/downloading a docker image with MSI (a docker file for MSI is available at https://github.com/nunofonseca/msi/blob/master/msi.dockerfile).

## Download

Using git:

`git clone https://github.com/nunofonseca/msi.git`

or download and unpack the zip file
`wget https://github.com/nunofonseca/msi/archive/master.zip`
`unzip master.zip`

## Compile and install

To install MSI to a specific folder (e.g., ~/msi) run
`./scripts/msi_install.sh -i ~/msi`

The installation script will install third party software used by MSI (e.g., R packages, blast, etc) therefore it will need internet acess and will take several minutes to conclude.

Note: Ensure that you have write permission to the parent folder.


## Configuration

When the installation is complete, a file called `msi_env.sh` will be created in the top level folder (~/msi in the above example).

The following line should be run in a terminal or added to $HOME/.bashrc

`source TOPLEVEL_FOLDER/env.sh`

where TOPLEVEL_FOLDER should be replaced by the toplevel folder (~/msi in the above example).

## Docker

A docker file is provided in the top level of msi: msi.dockerfile

A docker image with MSI can be created by running the following command:

`docker build -f msi.dockerfile -t "msi/latest" .`
 
 
# Installing databases

## Taxonomy

MSI requires the taxonomy database available from NCBI (ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz). By default the msi_install.sh script will download the database to `$MSI_DIR/db`, where `MSI_DIR` is the folder where MSI was installed.

# Running


# Visualising the results
