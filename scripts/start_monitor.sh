#!/usr/bin/env bash

USER=`whoami`
HOST=`hostname -s`
DOMAIN=`hostname -d`
MONITOR_CONFIG_EXAMPLE_FILE="/etc/neonio/monitor.conf.example"
MONITOR_CONFIG_FILE="/etc/neonsan/monitor.conf"

cp -rp $MONITOR_CONFIG_EXAMPLE_FILE $MONITOR_CONFIG_FILE
ZK_IPS=""
for (( i=1; i<=$ZK_SERVERS; i++ ))
do
     ZK_IPS=$ZK_IPS"neonio-zk-$((i-1)).neonio-zk-hs.$POD_NAMESPACE.svc.cluster.local:2181,"
done

ZK_IPS=${ZK_IPS%?}
sed -i "s/^ip=\"127.0.0.1:2181\"/ip=\"$ZK_IPS\"/g" $MONITOR_CONFIG_FILE

MYSQL_IPS="demo-radondb-mysql-leader"
# for (( i=1; i<=$MYSQL_SERVERS; i++ ))
# do
#     MYSQL_IPS=$MYSQL_IPS"neonio-mysql-$((i-1)).neonio-mysql-hs.$POD_NAMESPACE.svc.cluster.local,"
#done

#MYSQL_IPS=${MYSQL_IPS%?}
sed -i "s/^ip=\"192.168.101.xx,192.168.101.xx,192.168.101.xx\"/ip=\"$MYSQL_IPS\"/g" $MONITOR_CONFIG_FILE
sed -i "s/^ip=\"127.0.0.1\"/ip=\"neonio-mysql-hs.$POD_NAMESPACE.svc.cluster.local\"/g" $MONITOR_CONFIG_FILE

sed -i "s/^local_storeip=.*/local_storeip=\"$NODE_IP\"/g" $MONITOR_CONFIG_FILE
sed -i "s/^type=\"TCP\"/type=\"$CONNECT_TYPE\"/g" $MONITOR_CONFIG_FILE

sed -i "s/^user=.*/user=\"neonsan\"/g" $MONITOR_CONFIG_FILE

if [ $POD_NAME != "neonio-monitor-0" ]
then
    sed -i "s/^monitor_status=.*/monitor_status=false/g" $MONITOR_CONFIG_FILE
    sed -i "s/^monitor_alert=.*/monitor_alert=false/g" $MONITOR_CONFIG_FILE
fi

/usr/bin/neonmonitor


# start脚本不能推出
while true
do
    sleep 2
done


