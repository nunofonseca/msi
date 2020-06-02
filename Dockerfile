FROM fedora:31
LABEL maintainer="nuno.fonseca at gmail.com"

RUN dnf update -y && dnf install -y git bzip2-devel bzip2 zlib-devel git gcc wget make xz-devel tar make wget grep  perl  bash java python3 R  cmake ncurses-devel libcurl-devel openssl-devel pandoc python3-devel python3-pip python2 python time EMBOSS



ADD scripts ./scripts/
ADD tests ./tests/
COPY scripts/msi_install.sh .
RUN chmod a+x msi_install.sh

RUN ./scripts/msi_install.sh -i /opt/msi_install

WORKDIR /opt/msi
## wrapper to msi
RUN echo '#!/usr/bin/env bash' > /usr/bin/msi
RUN echo 'source /opt/msi_install/msi_env.sh' >> /usr/bin/msi
RUN echo '/opt/msi_install/bin/msi "$@"' >> /usr/bin/msi
RUN chmod u+x /usr/bin/msi

