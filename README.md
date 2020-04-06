# msi



# Installation

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

When the installation is complete, a file called `msi_env.sh` will be created in the top level folder (/opt/msi in the above example).

The following line should be run in a terminal or added to $HOME/.bashrc

`source TOPLEVEL_FOLDER/env.sh`

where TOPLEVEL_FOLDER should be replaced by the toplevel folder (~/msi in the above example).

## Installing databases


# Running


# Visualising the results
