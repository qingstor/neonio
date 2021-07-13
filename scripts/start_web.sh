#!/usr/bin/env bash

USER=`whoami`
HOST=`hostname -s`
DOMAIN=`hostname -d`
WEB_CONFIG_FILE="/qingstor/etc/qingstor-zero-web.yaml"



MYSQL_IPS="demo-radondb-mysql-leader"
sed -i "s/neonio-mysql-hs.kube-system.svc.cluster.local/$MYSQL_IPS/g" $WEB_CONFIG_FILE

REDIS_IPS="neonio-redis-hs.$POD_NAMESPACE.svc.cluster.local"
sed -i "s/neonio-redis-hs.kube-system.svc.cluster.local/$REDIS_IPS/g" $WEB_CONFIG_FILE

ZK_IPS="neonio-zk-hs.$POD_NAMESPACE.svc.cluster.local"
sed -i "s/neonio-zk-hs.kube-system.svc.cluster.local/$ZK_IPS/g" $WEB_CONFIG_FILE

PROMETHEUS_IPS="$PROMETHEUS_SVC"
sed -i "s/prometheus-operated.monitoring.svc.cluster.local/$PROMETHEUS_IPS/g" $WEB_CONFIG_FILE
sed -i "s/prometheus_enabled/$PROMETHEUS_ENABLED/g" $WEB_CONFIG_FILE

ALTERMANAGER_IPS="$ALTERMANAGER_SVC"
sed -i "s/alertmanager-operated.monitoring.svc.cluster.local/$ALTERMANAGER_IPS/g" $WEB_CONFIG_FILE
sed -i "s/alertmanager_enabled/$ALTERMANAGER_ENABLED/g" $WEB_CONFIG_FILE

while true
do
    nc -vz $ZK_IPS 2181
    if [ $? -eq 0 ]
    then
        break
    fi
    
    sleep 2
done

while true
do
    nc -vz $MYSQL_IPS 3306
    if [ $? -eq 0 ]
    then
        break
    fi
    
    sleep 2
done

while true
do
    nc -vz $REDIS_IPS 6379
    if [ $? -eq 0 ]
    then
        break
    fi
    
    sleep 2
done

if [ "$PROMETHEUS_ENABLED" == "true" ]
then
    while true
    do
        nc -vz $PROMETHEUS_IPS 9090
        if [ $? -eq 0 ]
        then
            break
        fi
        
        sleep 2
    done
fi

if [ "$ALTERMANAGER_ENABLED" == "true" ]
then
    while true
    do
        nc -vz $ALTERMANAGER_IPS 9093
        if [ $? -eq 0 ]
        then
            break
        fi
        
        sleep 2
    done
fi

export CONFIG_FILE_PATH=$WEB_CONFIG_FILE && /qingstor/bin/qingstor-zero-web


# start脚本不能推出
while true
do
    sleep 2
done


