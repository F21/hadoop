# Cloudera Distribution including Apache Hadoop 5.5.0

FROM f21global/java:8
MAINTAINER Francis Chuang <francis.chuang@boostport.com>

ENV CDH_VER 2.6.0+cdh5.5.0+921-1.cdh5.5.0.p0.15~trusty-cdh5.5.0

ADD cloudera.pref /etc/apt/preferences.d/cloudera.pref

RUN apt-get update \
    && apt-get install -y ca-certificates wget \
    && wget 'https://archive.cloudera.com/cdh5/ubuntu/trusty/amd64/cdh/cloudera.list' -O /etc/apt/sources.list.d/cloudera.list \
    && wget 'https://archive.cloudera.com/cdh5/ubuntu/trusty/amd64/cdh/archive.key' -O - | apt-key add - \
    && apt-get update