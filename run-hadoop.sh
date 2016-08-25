#!/usr/bin/env bash

: ${HADOOP_ROLE:?"HADOOP_ROLE is required and should be namenode, datanode or journal."}

addConfig () {

    if [ $# -ne 3 ]; then
        echo "There should be 3 arguments to addConfig: <file-to-modify.xml>, <property>, <value>"
        echo "Given: $@"
        exit 1
    fi

    xmlstarlet ed -L -s "/configuration" -t elem -n propertyTMP -v "" \
     -s "/configuration/propertyTMP" -t elem -n name -v $2 \
     -s "/configuration/propertyTMP" -t elem -n value -v $3 \
     -r "/configuration/propertyTMP" -v "property" \
     $1
}

CORE_SITE="$HADOOP_PREFIX/etc/hadoop/core-site.xml"
HDFS_SITE="$HADOOP_PREFIX/etc/hadoop/hdfs-site.xml"
LOG_DIR="/var/log/hadoop/hdfs"
PID_DIR="/var/run/hadoop/hdfs"
HADOOP_CONF_DIR="/opt/hadoop/etc/hadoop"

if [[ ${HADOOP_ROLE,,} = namenode ]]; then
    source roles/namenode.sh
elif [[ ${HADOOP_ROLE,,} = datanode ]]; then
    source roles/datanode.sh
elif [[ ${HADOOP_ROLE,,} = journalnode ]]; then
    source roles/journalnode.sh
else
    echo "HADOOP_ROLE's value must be one of: namenode, datanode or journalnode"
    exit 1
fi