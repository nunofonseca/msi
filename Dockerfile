FROM fedora:36
LABEL maintainer="nuno.fonseca at gmail.com"

## wrapper to msi
RUN echo '#!/usr/bin/env bash' > /usr/bin/msi && echo 'source /opt/msi_install/msi_env.sh' >> /usr/bin/msi && echo '/opt/msi_install/bin/msi "$@"' >> /usr/bin/msi && chmod u+x /usr/bin/msi

ADD scripts ./scripts/
#ADD tests ./tests/
ADD template ./template/
COPY LICENSE .
COPY README.md .
COPY scripts/msi_install.sh .
RUN chmod a+x msi_install.sh

RUN dnf update -y && dnf install -y git bzip2-devel bzip2 zlib-devel git gcc wget make xz-devel tar make wget grep  perl  bash java python3 R  cmake ncurses-devel libcurl-devel openssl-devel pandoc python3-devel python3-pip python2 python time EMBOSS
RUN ./scripts/msi_install.sh -i /opt/msi_install
WORKDIR /opt/msi

