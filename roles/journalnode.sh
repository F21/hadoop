#!/usr/bin/env bash

# Update core-site.xml
addConfig $CORE_SITE "ipc.client.connect.retry.interval" 4000
addConfig $CORE_SITE "ipc.client.connect.max.retries" 100

# Update hdfs-site.xml
addConfig $HDFS_SITE "dfs.permissions.superusergroup" "hadoop"
addConfig $HDFS_SITE "dfs.journalnode.edits.dir" ${DFS_JOURNALNODE_EDITS_DIR:="/var/lib/hadoop/journal"}

# Create directory for journal node files
mkdir -p $DFS_JOURNALNODE_EDITS_DIR
chown -R hadoop:hadoop $DFS_JOURNALNODE_EDITS_DIR

# Start the journalnode
exec su-exec hadoop $HADOOP_PREFIX/bin/hdfs --config $HADOOP_CONF_DIR journalnode