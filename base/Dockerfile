# Hortonworks HDP 2.3.2

FROM f21global/java:8
MAINTAINER Francis Chuang <francis.chuang@boostport.com>

ENV HDP_VER 2.3.2.0

RUN apt-get update \
    && apt-get install -y ca-certificates xmlstarlet wget \
    && wget http://public-repo-1.hortonworks.com/HDP/ubuntu14/2.x/updates/$HDP_VER/hdp.list -O /etc/apt/sources.list.d/hdp.list \
    && gpg --keyserver pgp.mit.edu --recv-keys B9733A7A07513CAD \
    && gpg -a --export 07513CAD | apt-key add - \
    && apt-get update