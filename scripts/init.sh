#!/usr/bin/env bash
QBD_CONFIG_FILE="/etc/neonsan/qbd.conf"
cp -rp ./qbd.conf $QBD_CONFIG_FILE

if [ -z "$ZK_SVC" ]
then
    ZK_IPS="neonio-zk-hs.$POD_NAMESPACE.svc.cluster.local:2181"
else
    ZK_IPS=$(echo $ZK_SVC |xargs |sed "s/-/:32181,/g")
    ZK_IPS="$ZK_IPS:32181"
fi

sed -i "s/^ip=\"zk_ips\"/ip=\"$ZK_IPS\"/g" $QBD_CONFIG_FILE

if [ -z "$CENTER_SVC" ]
then
    CENTER_IPS="neonio-center-hs.$POD_NAMESPACE.svc.cluster.local"
else
    CENTER_IPS=$(echo $CENTER_SVC | tr '-' ',')
fi

sed -i "s/^ip=\"center_ips\"/ip=\"$CENTER_IPS\"/g" $QBD_CONFIG_FILE


