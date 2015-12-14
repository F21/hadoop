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
addConfig $CORE_SITE "fs.trash.interval" ${FS_TRASH_INTERVAL:=1440}
addConfig $CORE_SITE "fs.trash.checkpoint.interval" ${FS_TRASH_CHECKPOINT_INTERVAL:=0}
addConfig $CORE_SITE "ipc.client.connect.retry.interval" 4000
addConfig $CORE_SITE "ipc.client.connect.max.retries" 100

# Update hdfs-site.xml
addConfig $HDFS_SITE "dfs.permissions.superusergroup" "hadoop"
addConfig $HDFS_SITE "dfs.datanode.max.transfer.threads" 4096
addConfig $HDFS_SITE "dfs.nameservices" $CLUSTER_NAME
addConfig $HDFS_SITE "dfs.ha.namenodes.${CLUSTER_NAME}" "nn1,nn2"

: ${DFS_NAMENODE_RPC_ADDRESS_NN1:?"DFS_NAMENODE_RPC_ADDRESS_NN1 is required."}
addConfig $HDFS_SITE "dfs.namenode.rpc-address.${CLUSTER_NAME}.nn1" $DFS_NAMENODE_RPC_ADDRESS_NN1

: ${DFS_NAMENODE_RPC_ADDRESS_NN2:?"DFS_NAMENODE_RPC_ADDRESS_NN2 is required."}
addConfig $HDFS_SITE "dfs.namenode.rpc-address.${CLUSTER_NAME}.nn2" $DFS_NAMENODE_RPC_ADDRESS_NN2

: ${DFS_NAMENODE_HTTP_ADDRESS_NN1:?"DFS_NAMENODE_HTTP_ADDRESS_NN1 is required."}
addConfig $HDFS_SITE "dfs.namenode.http-address.${CLUSTER_NAME}.nn1" $DFS_NAMENODE_HTTP_ADDRESS_NN1

: ${DFS_NAMENODE_HTTP_ADDRESS_NN2:?"DFS_NAMENODE_HTTP_ADDRESS_NN2 is required."}
addConfig $HDFS_SITE "dfs.namenode.http-address.${CLUSTER_NAME}.nn2" $DFS_NAMENODE_HTTP_ADDRESS_NN2

addConfig $HDFS_SITE "dfs.client.failover.proxy.provider.${CLUSTER_NAME}" "org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider"

addConfig $HDFS_SITE "dfs.datanode.name.dir" ${DFS_DATANODE_NAME_DIR:="file:///var/lib/hadoop-hdfs/data"}
[ ! -z "$DFS_DATANODE_FSDATASET_VOLUME_CHOOSING_POLICY" ] && addConfig $HDFS_SITE "dfs.datanode.fsdataset.volume.choosing.policy" "org.apache.hadoop.hdfs.server.datanode.fsdataset.AvailableSpaceVolumeChoosingPolicy"
[ ! -z "$DFS_DATANODE_AVAILABLE_SPACE_VOLUME_CHOOSING_POLICY_BALANCED_SPACE_THRESHOLD" ] && addConfig $HDFS_SITE "dfs.datanode.available-space-volume-choosing-policy.balanced-space-threshold" $DFS_DATANODE_AVAILABLE_SPACE_VOLUME_CHOOSING_POLICY_BALANCED_SPACE_THRESHOLD
[ ! -z "$DFS_DATANODE_AVAILABLE_SPACE_VOLUME_CHOOSING_POLICY_BALANCED_SPACE_PREFRENCE_FRACTION" ] && addConfig $HDFS_SITE "dfs.datanode.available-space-volume-choosing-policy.balanced-space-preference-fraction" $DFS_DATANODE_AVAILABLE_SPACE_VOLUME_CHOOSING_POLICY_BALANCED_SPACE_PREFRENCE_FRACTION

# Create and set the data directories correctly
IFS=',' read -ra DFS_DATANODE_NAME_DIRS <<< "$DFS_DATANODE_NAME_DIR"
for i in "${DFS_DATANODE_NAME_DIRS[@]}"; do

    if [[ $i == "file:///"* ]]; then
        path=${i/"file://"/""}
        mkdir -p $path
        chown -R hdfs:hdfs $path
        chmod 700 $path
    fi
done

# Start the datanode
sudo -u hdfs -i /usr/hdp/current/hadoop-hdfs-datanode/../hadoop/sbin/hadoop-daemon.sh --config /etc/hadoop/conf start datanode

cleanup() {
    sudo -u hdfs -i /usr/hdp/current/hadoop-hdfs-datanode/../hadoop/sbin/hadoop-daemon.sh --config /etc/hadoop/conf stop datanode
    exit 0
}

trap cleanup SIGINT SIGTERM

while true; do sleep 1; done