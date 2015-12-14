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

# Create log dirs
mkdir -p $LOG_DIR;
chown -R hdfs:hadoop $LOG_DIR;
chmod -R 755 $LOG_DIR;

echo "HADOOP_LOG_DIR=${LOG_DIR}" >> /etc/hadoop/conf/hadoop-env.sh

# Create PID dirs
mkdir -p $PID_DIR;
chown -R hdfs:hadoop $PID_DIR;
chmod -R 755 $PID_DIR;

echo "HADOOP_PID_DIR=${PID_DIR}" >> /etc/hadoop/conf/hadoop-env.sh

# Update core-site.xml
: ${CLUSTER_NAME:?"CLUSTER_NAME is required."}
addConfig $CORE_SITE "fs.defaultFS" "hdfs://${CLUSTER_NAME}"
addConfig $CORE_SITE "ipc.client.connect.retry.interval" 4000
addConfig $CORE_SITE "ipc.client.connect.max.retries" 100

# Update hdfs-site.xml
addConfig $HDFS_SITE "dfs.permissions.superusergroup" "hadoop"
addConfig $HDFS_SITE "dfs.journalnode.edits.dir" ${DFS_JOURNALNODE_EDITS_DIR:="/var/lib/hadoop-hdfs/journal"}

# Create directory for journal node files
mkdir -p $DFS_JOURNALNODE_EDITS_DIR
chown -R hdfs:hdfs $DFS_JOURNALNODE_EDITS_DIR

# Start the datanode
sudo -u hdfs -i /usr/hdp/current/hadoop-hdfs-journalnode/../hadoop/sbin/hadoop-daemon.sh --config /etc/hadoop/conf start journalnode

cleanup() {
    sudo -u hdfs -i /usr/hdp/current/hadoop-hdfs-journalnode/../hadoop/sbin/hadoop-daemon.sh --config /etc/hadoop/conf stop journalnode
    exit 0
}

trap cleanup SIGINT SIGTERM

while true; do sleep 1; done