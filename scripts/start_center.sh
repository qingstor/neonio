#!/usr/bin/env bash

USER=`whoami`
HOST=`hostname -s`
DOMAIN=`hostname -d`
CENTER_CONFIG_EXAMPLE_FILE="/etc/neonsan/center.conf.example"
CENTER_CONFIG_FILE="/etc/neonsan/center.conf"
QBD_CONFIG_EXAMPLE_FILE="/etc/neonsan/qbd.conf.example"
QBD_CONFIG_FILE="/etc/neonsan/qbd.conf"

cp -rp  $CENTER_CONFIG_EXAMPLE_FILE $CENTER_CONFIG_FILE
cp -rp  $QBD_CONFIG_EXAMPLE_FILE $QBD_CONFIG_FILE

ZK_IPS="neonio-zk-hs.$POD_NAMESPACE.svc.cluster.local:2181"

sed -i "s/^ip=\"192.168.101.25:2181,192.168.101.26:2181,192.168.101.27:2181\"/ip=\"$ZK_IPS\"/g" $CENTER_CONFIG_FILE
sed -i "s/^ip=\"192.168.101.25:2181,192.168.101.26:2181,192.168.101.27:2181\"/ip=\"$ZK_IPS\"/g" $QBD_CONFIG_FILE

if [ -z "$CENTER_SVC" ]
then
    CENTER_IPS="neonio-center-hs.$POD_NAMESPACE.svc.cluster.local"
else
    CENTER_IPS=$(echo $CENTER_SVC | tr '-' ',')
fi

sed -i "s/^ip=\"192.168.101.25,192.168.101.26,192.168.101.27\"/ip=\"$CENTER_IPS\"/g" $QBD_CONFIG_FILE

MYSQL_IP="demo-radondb-mysql-leader"
sed -i "s/^ip=\"192.168.101.12\"/ip=\"$MYSQL_IP\"/g" $CENTER_CONFIG_FILE
if [ "$HOSTNETWORK" == "false" ]
then
    sed -i "s/^mngt_ip=.*/mngt_ip=\"$HOST\.$DOMAIN\"/g" $CENTER_CONFIG_FILE
else
    sed -i "s/^mngt_ip=.*/mngt_ip=\"$NODE_IP\"/g" $CENTER_CONFIG_FILE
fi

sed -i "s/^pass=.*/pass=\"zhu88jie\"/g" $CENTER_CONFIG_FILE

while true
do
    nc -zv "neonio-zk-hs.$POD_NAMESPACE.svc.cluster.local" "2181"
    if [ $? -ne 0 ]
    then
        sleep 5
        continue
    fi
    
    nc -zv "$MYSQL_IP" "3306"
    if [ $? -ne 0 ]
    then
        sleep 5
        continue
    fi
    
    break
    
done

/usr/bin/supervisord -c /etc/supervisor/supervisord.conf


# start脚本不能推出
while true
do
    sleep 2
done


