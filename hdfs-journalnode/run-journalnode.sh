#!/usr/bin/env bash

CORE_SITE="/etc/hadoop/conf/core-site.xml"
HDFS_SITE="/etc/hadoop/conf/hdfs-site.xml"
LOG_DIR="/var/log/hadoop/hdfs"
PID_DIR="/var/run/hadoop/hdfs"

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

# Update core-site.xml
addConfig $CORE_SITE "ipc.client.connect.retry.interval" 4000
addConfig $CORE_SITE "ipc.client.connect.max.retries" 100

# Update hdfs-site.xml
addConfig $HDFS_SITE "dfs.permissions.superusergroup" "hadoop"
addConfig $HDFS_SITE "dfs.journalnode.edits.dir" ${DFS_JOURNALNODE_EDITS_DIR:="/var/lib/hadoop-hdfs/journal"}

# Create directory for journal node files
mkdir -p $DFS_JOURNALNODE_EDITS_DIR
chown -R hdfs:hdfs $DFS_JOURNALNODE_EDITS_DIR

# Start the journalnode
exec gosu hdfs hdfs --config /etc/hadoop/conf journalnode