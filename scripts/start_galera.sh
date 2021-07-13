#!/usr/bin/env bash

USER=`whoami`
HOST=`hostname -s`
DOMAIN=`hostname -d`
GALERA_CONFIG_EXAMPLE_FILE="/opt/galera/conf/neonsan_galera.conf.example"
GALERA_CONFIG_FILE="/opt/galera/conf/neonsan_galera.conf"
MGMT_CONFIG_EXAMPLE_FILE="/opt/galera/conf/mgmt.conf.example"
MGMT_CONFIG_FILE="/opt/galera/conf/mgmt.conf"
WSREP_CLUSTER_ADDRESS="gcomm\:\/\/"

cp -rp $GALERA_CONFIG_EXAMPLE_FILE $GALERA_CONFIG_FILE
cp -rp $MGMT_CONFIG_EXAMPLE_FILE $MGMT_CONFIG_FILE

mv /etc/supervisor/conf.d/supervisor_galera_cluster.conf.example /etc/supervisor/conf.d/supervisor_galera_cluster.conf

if [[ $HOST =~ (.*)-([0-9]+)$ ]]; then
    NAME=${BASH_REMATCH[1]}
    ORD=${BASH_REMATCH[2]}
else
    echo "Fialed to parse name and ordinal of Pod"
    exit 1
fi

ZK_IPS="neonio-zk-hs.$POD_NAMESPACE.svc.cluster.local:2181"
sed -i "s/^ip=.*/ip=\"$ZK_IPS\"/g" $MGMT_CONFIG_FILE

if [ $SERVERS -gt 1 ]; then
    for (( i=1; i<=$SERVERS; i++ ))
    do
        WSREP_CLUSTER_ADDRESS="$WSREP_CLUSTER_ADDRESS$NAME-$((i-1)).$DOMAIN,"
    done
fi

MY_ID=$((ORD+1))
sed -i "s/^server-id=.*/server-id=$MY_ID/g" $GALERA_CONFIG_FILE

# remove the last characterexit
WSREP_CLUSTER_ADDRESS=${WSREP_CLUSTER_ADDRESS%?}
sed -i "s/^wsrep_cluster_address=.*/wsrep_cluster_address=$WSREP_CLUSTER_ADDRESS/g" $GALERA_CONFIG_FILE
sed -i "s/^wsrep_node_address=.*/wsrep_node_address=$HOST\.$DOMAIN/g" $GALERA_CONFIG_FILE
sed -i "s/^wsrep_cluster_name=.*/wsrep_cluster_name=pxc-neonsan-cluster/g" $GALERA_CONFIG_FILE
echo "skip-grant-tables" >> $GALERA_CONFIG_FILE

while true
do
    IP=$(ping neonio-zk-hs.$POD_NAMESPACE.svc.cluster.local -c 1 -w 1 | sed '1{s/[^(]*(//;s/).*//;q}')
    if [ -z "$IP" ]
    then
        echo "wait zk service ok"
        sleep 2
        continue
    fi
    
    OK=$(echo ruok|nc $IP 2181)
    if [ "X$OK" == "Ximok" ]
    then
        echo "zk service ok"
        break
    fi
    
    echo "wait zk service ok"
    sleep 2
done


if [ ! -d /data/galera/mysql/ -a $HOST == "neonio-mysql-0" ]
then
    while true
    do
        /opt/galera/bin/galera_cluster initdb
        if [ $? -eq 0 ]
        then 
            echo "/opt/galera/bin/galera_cluster initdb sucess"
            break
        fi
        echo "/opt/galera/bin/galera_cluster initdb failed"
        sleep 5
    done
    
    while true
    do
        /opt/galera/bin/galera_cluster start --bootstrap --user=neonsan --passwd=zhu88jie --onetime
        if [ $? -eq 0 ]
        then
            echo "/opt/galera/bin/galera_cluster start --bootstrap --user=neonsan --passwd=zhu88jie --onetime sucess"
            break
        fi
        
        echo "/opt/galera/bin/galera_cluster start --bootstrap --user=neonsan --passwd=zhu88jie --onetime failed"
        sleep 5
    done
    
    sleep 5
    
    while true
    do
        mysql -uneonsan -pzhu88jie -h "$HOST.$DOMAIN" -e "show databases;"
        ret1=$?
        mysql -uneonsan -pzhu88jie -h "$HOST.$DOMAIN" -e "show databases;" |grep -w "neonsan"
        ret2=$?
        if [ $ret1 -eq 0 -a $ret2 -ne 0 ]
        then
            mysql -uneonsan -pzhu88jie -h "$HOST.$DOMAIN" -e "source /etc/neonsan/initdb.sql;"
            if [ $? -ne 0 ]
            then
                echo 'mysql -uneonsan -pzhu88jie -h "$HOST.$DOMAIN" -e "source /etc/neonsan/initdb.sql;" failed'
                continue
            fi
            
            mysql -uneonsan -pzhu88jie -h "$HOST.$DOMAIN" neonsan -e "alter table port drop index ip;"
            if [ $? -ne 0 ]
            then
                echo 'mysql -uneonsan -pzhu88jie -h "$HOST.$DOMAIN" neonsan -e "alter table port drop index ip;" failed'
                continue
            fi
        fi 
        
        mysql -uneonsan -pzhu88jie -h "$HOST.$DOMAIN" -e "show databases;"
        ret1=$?
        mysql -uneonsan -pzhu88jie -h "$HOST.$DOMAIN" -e "show databases;" |grep -w "qingstor-zero-web"
        ret2=$?
        if [ $ret1 -eq 0 -a $ret2 -ne 0 ]
        then
            mysql -uneonsan -pzhu88jie -h "$HOST.$DOMAIN" -e "source /etc/neonsan/qingstor-zero-web_schema.sql;"
            if [ $? -ne 0 ]
            then
                echo 'mysql -uneonsan -pzhu88jie -h "$HOST.$DOMAIN" -e "source /etc/neonsan/qingstor-zero-web_schema.sql;" failed'
                continue
            fi
            
            mysql -uneonsan -pzhu88jie -h "$HOST.$DOMAIN" -e "source /etc/neonsan/qingstor-zero-web_seed.sql;"
            if [ $? -ne 0 ]
            then
                echo 'mysql -uneonsan -pzhu88jie -h "$HOST.$DOMAIN" -e "source /etc/neonsan/qingstor-zero-web_seed.sql;" failed'
                continue
            fi
        fi 
        
        mysql -uneonsan -pzhu88jie -h "$HOST.$DOMAIN" -e "show databases;"
        ret1=$?
        mysql -uneonsan -pzhu88jie -h "$HOST.$DOMAIN" -e "show databases;" |grep -w "neonsan"
        ret2=$?
        mysql -uneonsan -pzhu88jie -h "$HOST.$DOMAIN" -e "show databases;" |grep -w "qingstor-zero-web"
        ret3=$?
        if [ $ret1 -eq 0 -a $ret2 -eq 0 -a $ret3 -eq 0 ]
        then           
            break
        fi 
        
        sleep 5
    done
    
    sleep 5
    
    /opt/galera/bin/galera_cluster stop
     if [ $? -ne 0 ]
    then 
        echo "/opt/galera/bin/galera_cluster stop failed"
        exit 1
    fi
    
fi

if [ ! -d /data/galera/mysql/ ] 
then 
    /opt/galera/bin/galera_cluster initdb
    if [ $? -ne 0 ]
    then 
         echo "/opt/galera/bin/galera_cluster initdb failed"
         exit 1
    fi
    
    while true
    do
        /opt/galera/bin/galera_cluster status |grep -w "neonio-mysql-0.$DOMAIN" |grep -w "on" |grep -w "primary"
        if [ $? -eq 0 ]
        then           
            break
        fi 
        
        echo "wait first neonio-mysql-0 start"
        sleep 5
    done
fi 

echo "mysql service start"
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf

# start脚本不能推出
while true
do
    sleep 2
done


