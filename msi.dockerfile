FROM fedora:31
LABEL maintainer="nuno.fonseca at gmail.com"

RUN dnf update -y && dnf install -y git bzip2-devel bzip2 zlib-devel git gcc wget make xz-devel tar make wget grep  perl  bash java python3 R  cmake ncurses-devel libcurl-devel openssl-devel pandoc python3-devel python3-pip python2 python time

########################################
## needed for accessing the private repo
# # Warning! Anyone with access to this image will be able
# to access the the repo
RUN mkdir -p /root/.ssh/
COPY ./keys/msi_github /root/.ssh/id_rsa
RUN chmod 600 /root/.ssh/id_rsa
# Skip Host verification for git
RUN echo "StrictHostKeyChecking no" > /root/.ssh/config


WORKDIR /opt

RUN git clone git@github.com:nunofonseca/msi.git
WORKDIR /opt/msi
RUN ./scripts/msi_install.sh -i /opt/msi_install
