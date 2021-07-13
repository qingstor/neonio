#!/usr/bin/env bash

USER=`whoami`
HOST=`hostname -s`
DOMAIN=`hostname -d`
STORE_CONFIG_EXAMPLE_FILE="/etc/neonio/store.conf.example"
STORE_CONFIG_FILE="/etc/neonsan/store.conf"
QBD_CONFIG_EXAMPLE_FILE="/etc/neonio/qbd.conf.example"
QBD_CONFIG_FILE="/etc/neonsan/qbd.conf"

if [ ! -f $STORE_CONFIG_FILE ]
then
    cp -rp /etc/neonio/* /etc/neonsan/
    cp -rp $STORE_CONFIG_EXAMPLE_FILE $STORE_CONFIG_FILE
    cp -rp $QBD_CONFIG_EXAMPLE_FILE $QBD_CONFIG_FILE

    sed -i "s/^\[ssd.0\]/###\[ssd.0\]/g" $STORE_CONFIG_FILE
    sed -i "s/^dev=\"\/dev\/nvme0n1\"/###dev=\"\/dev\/nvme0n1\"/g" $STORE_CONFIG_FILE
    sed -i "s/^type=\"SSD\"/###type=\"SSD\"/g" $STORE_CONFIG_FILE

    sed -i "s/^\[ssd.1\]/###\[ssd.1\]/g" $STORE_CONFIG_FILE
    sed -i "s/^trim_on_reclaim=0/###trim_on_reclaim=0/g" $STORE_CONFIG_FILE
    sed -i "s/^zero_on_reclaim=0/###zero_on_reclaim=0/g" $STORE_CONFIG_FILE
    sed -i "s/^dev=\"\/dev\/intelcas1-1\"/###dev=\"\/dev\/intelcas1-1\"/g" $STORE_CONFIG_FILE
    sed -i "s/^type=\"CachedHDD\"/###type=\"CachedHDD\"/g" $STORE_CONFIG_FILE

    sed -i "s/^\[port.1\]/###\[port.1]\]/g" $STORE_CONFIG_FILE
    sed -i "s/^\[rep_port.1\]/###\[rep_port.1]\]/g" $STORE_CONFIG_FILE
    sed -i "s/^ip=\"192.168.103.25\"/###ip=\"192.168.103.25\"/g" $STORE_CONFIG_FILE
    sed -i "s/^ip=\"192.168.104.25\"/###ip=\"192.168.104.25\"/g" $STORE_CONFIG_FILE


    ORD=$(echo $NODE_IP| sed 's/\.//g')

    ZK_IPS="neonio-zk-hs.$POD_NAMESPACE.svc.cluster.local:2181"
    sed -i "s/^ip=\"192.168.101.25:2181,192.168.101.26:2181,192.168.101.27:2181\"/ip=\"$ZK_IPS\"/g" $STORE_CONFIG_FILE
    sed -i "s/^ip=\"192.168.101.25:2181,192.168.101.26:2181,192.168.101.27:2181\"/ip=\"$ZK_IPS\"/g" $QBD_CONFIG_FILE
    
    if [ -z "$CENTER_SVC" ]
    then
        CENTER_IPS="neonio-center-hs.$POD_NAMESPACE.svc.cluster.local"
    else
        CENTER_IPS=$(echo $CENTER_SVC | tr '-' ',')
    fi
    
    sed -i "s/^ip=\"192.168.101.25,192.168.101.26,192.168.101.27\"/ip=\"$CENTER_IPS\"/g" $QBD_CONFIG_FILE

    sed -i "s/^ip=\"192.168.101.25\"/ip=\"$NODE_IP\"/g" $STORE_CONFIG_FILE
    sed -i "s/^ip=\"192.168.102.25\"/ip=\"$NODE_IP\"/g" $STORE_CONFIG_FILE
    sed -i "s/^mngt_ip=.*/mngt_ip=\"$NODE_IP\"/g" $STORE_CONFIG_FILE
    sed -i "s/^id=.*/id=$ORD/g" $STORE_CONFIG_FILE
    sed -i "s/^type=\"RDMA\"/type=\"$CONNECT_TYPE\"/g" $STORE_CONFIG_FILE
    sed -i "s/^iotaskpoolsize=8192/iotaskpoolsize=$DISPATCHER_IOTASKPOOLSIZE/g" $STORE_CONFIG_FILE
    sed -i "s/^iotaskpoolsize=16384/iotaskpoolsize=$REPLICATOR_IOTASKPOOLSIZE/g" $STORE_CONFIG_FILE
    if [ -z "$DISKS" ]
    then
        disk_list=$(python /opt/neonsan/bin/scan_disk.py "$DEVFILTER")
    else
        disk_list=(`echo $DISKS | tr ':' ' '` )
    fi 
    index=0
    for disk in ${disk_list[@]}
    do
        echo "[ssd.$index]" >> $STORE_CONFIG_FILE
        echo "trim_on_reclaim=$TRIM_ON_RECLAIM" >> $STORE_CONFIG_FILE
        echo "zero_on_reclaim=$ZERO_ON_RECLAIM" >> $STORE_CONFIG_FILE
        echo "dev=\"$disk\"" >> $STORE_CONFIG_FILE
        echo "type=\"$DISK_TYPE\""  >> $STORE_CONFIG_FILE
        index=$(($index+1))
    done
else 
    echo "the store has been configured, no need to reconfigure"
fi

while true
do
    qfcip
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


