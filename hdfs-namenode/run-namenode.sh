#!/usr/bin/env bash

CORE_SITE="/etc/hadoop/conf/core-site.xml"
HDFS_SITE="/etc/hadoop/conf/hdfs-site.xml"
NAMENODE_FORMATTED_FLAG="/namenode-is-formatted"
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
: ${CLUSTER_NAME:?"CLUSTER_NAME is required."}
addConfig $CORE_SITE "fs.defaultFS" "hdfs://${CLUSTER_NAME}"
addConfig $CORE_SITE "fs.trash.interval" ${FS_TRASH_INTERVAL:=1440}
addConfig $CORE_SITE "fs.trash.checkpoint.interval" ${FS_TRASH_CHECKPOINT_INTERVAL:=0}
addConfig $CORE_SITE "ipc.client.connect.retry.interval" 6000
addConfig $CORE_SITE "ipc.client.connect.max.retries" 400

: ${HA_ZOOKEEPER_QUORUM:?"HA_ZOOKEEPER_QUORUM is required."}
addConfig $CORE_SITE "ha.zookeeper.quorum" $HA_ZOOKEEPER_QUORUM

# Update hdfs-site.xml
addConfig $HDFS_SITE "dfs.permissions.superusergroup" "hadoop"
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
addConfig $HDFS_SITE "dfs.namenode.name.dir" ${DFS_NAMENODE_NAME_DIR:="file:///var/lib/hadoop-hdfs/cache/hdfs/dfs/name"}

: ${DFS_NAMENODE_SHARED_EDITS_DIR:?"DFS_NAMENODE_SHARED_EDITS_DIR is required."}
DFS_NAMENODE_SHARED_EDITS_DIR=${DFS_NAMENODE_SHARED_EDITS_DIR//","/";"}
addConfig $HDFS_SITE "dfs.namenode.shared.edits.dir" "qjournal://${DFS_NAMENODE_SHARED_EDITS_DIR}/${CLUSTER_NAME}"

addConfig $HDFS_SITE "dfs.ha.fencing.methods" "shell(/bin/true)"

addConfig $HDFS_SITE "dfs.ha.automatic-failover.enabled" "true"

# Create and set the data directories correctly
IFS=',' read -ra DFS_NAMENODE_NAME_DIRS <<< "$DFS_NAMENODE_NAME_DIR"
for i in "${DFS_NAMENODE_NAME_DIRS[@]}"; do

    if [[ $i == "file:///"* ]]; then
        path=${i/"file://"/""}
        mkdir -p $path
        chown -R hdfs:hdfs $path
        chmod 700 $path
    fi
done

cleanup() {
    sudo -u hdfs -i /usr/hdp/current/hadoop-hdfs-namenode/../hadoop/sbin/hadoop-daemon.sh --config /etc/hadoop/conf stop namenode
    sudo -u hdfs -i /usr/hdp/current/hadoop-hdfs-namenode/../hadoop/sbin/hadoop-daemon.sh --config /etc/hadoop/conf stop zkfc
    exit 0
}

trap cleanup SIGINT SIGTERM

IFS=',' read -ra HA_ZOOKEEPER_QUORUMS <<< "$HA_ZOOKEEPER_QUORUM"
num_zk=${#HA_ZOOKEEPER_QUORUMS[*]}

IFS=":" read -ra REMOTE_ADDR <<< "${HA_ZOOKEEPER_QUORUMS[$((RANDOM%num_zk))]}"

until $(nc -z -v -w5 ${REMOTE_ADDR[0]} ${REMOTE_ADDR[1]}); do
    echo "Waiting for zookeeper to be available..."
    sleep 2
done

# Format namenode
if [[ (! -f $NAMENODE_FORMATTED_FLAG) && -z "$STANDBY" ]]; then

    echo "Formatting zookeeper"
    gosu hdfs hdfs zkfc -formatZK

    echo "Formatting namenode..."
    gosu hdfs hdfs namenode -format
    touch $NAMENODE_FORMATTED_FLAG
fi

# Set this namenode as standby if required
if [ -n "$STANDBY" ]; then
    echo "Starting namenode in standby mode..."
    gosu hdfs hdfs namenode -bootstrapStandby
else
    echo "Starting namenode..."
fi

trap 'kill %1; kill %2' SIGINT SIGTERM

gosu hdfs hdfs --config /etc/hadoop/conf namenode &

# Start the zkfc
gosu hdfs hdfs --config /etc/hadoop/conf zkfc &

# Wait for cluster to be ready
gosu hdfs hdfs dfsadmin -safemode wait

# Create the /tmp directory if it doesn't exist
gosu hdfs hadoop fs -test -d /tmp

if [ $? != 0 ]; then
    gosu hdfs hadoop fs -mkdir /tmp
    gosu hdfs hadoop fs -chmod -R 1777 /tmp
fi

while true; do sleep 1; done