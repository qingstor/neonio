[English](README.md) | 中文 

# NeonIO简介
NeonIO是一款支持容器化部署的企业级分布式块存储系统，能够给Kubernetes平台上提供动态创建（dynamic provisioning)持久存储卷（persistent volume)的能力,支持clone、snapshot、resstore、resize等功能。

## 架构图
 
![NeonIO架构图](docs/images/neonio_Architecture.png)

zk/etcd: 提供集群发现、分布式协调、选master等服务

mysql：提供元数据存储服务，如PV存储卷的元数据

center：提供逻辑管理服务，如创建PV卷，快照

monitor: 提供监控服务，能够把采集监控指标暴露给Promethus

store：存储服务，处理应用IO的功能

portal：提供UI界面服务

CSI：提供csi的标准IO接入服务




# 安装
## 前置条件 
1. Kubernetes已经成功部署，可按照Kubernetes的官网部署

2. 集群的每个节点都已安装qbd，如未安装，用如下命令安装，[下载qbd](https://github.com/qingstor/neonio.git)

    centos OS系列：`rpm -ivh pitrix-dep-qbd-2.1.2-1dkms.noarch.rpm pitrix-dep-qbd-util-2.1.2-1.el8.x86_64.rpm`

    ubuntu OS系列：`dpkg -i pitrix-dep-qbd-dkms_2.1.2_all.deb pitrix-dep-qbd-util-2.1.2.amd64.deb`

3. Kubernetes集群的每个节点都加载了qbd和qbd_tcp模块

    `lsmod | egrep -i qbd`

    ![lsmod | egrep -i qbd回显](docs/images/lsmod_qbd.png)

    如未加载，可在节点上运行如下命令加载

    `modprobe qbd && modprobe qbd_tcp`

    **提示：可在每个节点上编辑以下文件，开机自动加载qbd所需模块,编辑/etc/rc.local写入:**


    ```
    modprobe qbd
    modprobe qbd_tcp 
    ```

4. Kubernetes集群的master节点已经安装了Helm

    `helm version`

    ![helm version回显](docs/images/helm_version.png)



## 检查是否已经安装

登陆Kubernetes集群的master节点，运行如下命令，如果输出为空，表示NeonIO未安装，如果输出结果类似下方，则表示NeonIO已经安装。

`kubectl get pod -A -owide | grep neon`


![kubectl get pod -A -owide | grep neon回显](docs/images/kubectl_get_pod_neon.png)


## 安装
1. 运行如下命令下载Helm安装包:

    ```
    git clone  https://github.com/qingstor/neonio.git
    cd neonio/charts/
    ```
2. 部署节点的规划

    2.1 登录集群的master节点，执行命令如下查询k8s集群的节点

    `kubectl get node -o wide`

    ![kubectl get node -o wide回显](docs/images/kubectl_get_node.png)

    2.2 例如把host03、host05、host06部署neonio-store，则把三节点标记为store
    ```
    kubectl label nodes host03 neonio/store=store
    kubectl label nodes host05 neonio/store=store
    kubectl label nodes host06 neonio/store=store
    ```  
    **部署neonio-store服务的节点至少有一个原始设备（无分区或格式化文件系统）给neonio单独使用，如下命令回显，sdb是一个原始设备，可以给neonio使用**
    
    ```
    root@host03:~# lsblk -f
    NAME                  FSTYPE      LABEL                           UUID                                   MOUNTPOINT
    sda                                                                                                      
    ├─sda1                ext2                                        38869881-aa97-4bf5-8b39-668f739b2ede   /boot
    ├─sda2                                                                                                   
    └─sda5                LVM2_member                                 dsDtd3-9Aeg-4r1t-EiL6-xUgb-zhpC-MHeTWP 
      ├─host01--vg-root   ext4                                        0e031537-f01b-49b0-a282-3722cfa25056   /
      └─host01--vg-swap_1 swap                                        80b1f62c-1c2b-44b1-a0b7-83d58ea8652b   
        └─cryptswap1      swap                                        ad07281a-51c7-4919-aee8-3bc60194fdec   
    sdb                                                                                                      
    sr0                   iso9660     Ubuntu-Server 16.04.5 LTS amd64 2018-07-31-00-39-29-00                 

    ```

    2.3 例如部署zookeeper的节点为host03、host05、host06，部署mysql的节点为host03、host05、host06，则把三节点分别打label
    ```
    # 执行如下命令host03、host05、host06标记为zk
    kubectl label nodes host03 neonio/zk=zk
    kubectl label nodes host05 neonio/zk=zk
    kubectl label nodes host06 neonio/zk=zk
    ```
    ```
    # 执行如下命令host03、host05、host06标记为mysql
    kubectl label nodes host03 neonio/mysql=mysql
    kubectl label nodes host05 neonio/mysql=mysql
    kubectl label nodes host06 neonio/mysql=mysql
    ```

3. 安装NeonIO

    3.1 安装NeonIO，默认是需要3节点，如果不满足参考《修改安装参数》章节
    
    `helm install neonio ./neonio --namespace kube-system`

    ![helm install neonio ./neonio --namespace kube-system回显](docs/images/helm_install_neonio.png)


    3.2 用如下命令查看，等到都read都OK了为止

    `kubectl get pod -A -owide | grep neon`

    ![kubectl get pod -A -owide | grep neon回显](docs/images/kubectl_get_pod_neon.png)

    3.3 检查集群状态 
    
    `kubectl -n kube-system exec neonio-center-0 -- neonsan list_center`

    ![list_center回显](docs/images/neonsan_list_center.png)

    `kubectl -n kube-system exec neonio-center-0 -- neonsan list_store`

    ![list_store回显](docs/images/neonsan_list_store.png)

    `kubectl -n kube-system exec neonio-center-0 -- neonsan list_ssd`

    ![list_ssd回显](docs/images/neonsan_list_ssd.png)

    3.4 创建pool
    
    `kubectl -n kube-system  exec neonio-center-0 -- neonsan create_pool --pool kube`

    ![list_ssd回显](docs/images/neonsan_create_pool.png)


    3.5 创建rg
    
    `kubectl -n kube-system  exec neonio-center-0 -- neonsan create_rg --rg rg_name`

    ![list_ssd回显](docs/images/neonsan_create_rg.png)

    3.6 把节点store节点加入到到rg，**store_id需要根据实际情况修改**
    
    `kubectl -n kube-system  exec neonio-center-0 -- neonsan add_rg_node --rg rg_name --store_id 192168101245,192168101251,192168101252`

    ![list_ssd回显](docs/images/neonsan_add_rg_node.png)
    


# 测试NeonIO

如下示例，创建一个yaml文件
```
cat busybox-test.yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: neonsan-test-pvc
spec:
  storageClassName: csi-neonsan
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: busybox-test
spec:
  containers:
    - name: busybox
      imagePullPolicy: IfNotPresent
      image: busybox:latest
      command: [ "/bin/sh", "-c", "tail -f /dev/null" ]
      volumeMounts:
      - name: volume1
        mountPath: "/mnt/volume1"
  volumes:
  - name: volume1
    persistentVolumeClaim:
      claimName: neonsan-test-pvc
  restartPolicy: Never


# 应用yaml，创建pvc和busybox应用
$ kubectl apply -f busybox-test.yaml
persistentvolumeclaim/neonsan-test-pvc created
pod/busybox-test created

# 查看pvc，状态应为Bound
$ kubectl get pvc
NAME                                   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS           AGE
neonsan-test-pvc                       Bound    pvc-5ef6436c-95f6-470f-9e4e-ad705457fb0f   10Gi       RWO            csi-neonsan            4s

# 查看busybox pod，状态应为Running
$ kubectl get pod
NAME                                READY   STATUS      RESTARTS   AGE
busybox-test                        1/1     Running     0          11s

# 进入busybox pod，向存储卷里写入数据
$ kubectl exec busybox-test -t -- sh -c 'echo hello > /mnt/volume1/test.log'
# 进入busybox pod，读取存储卷里的数据
$ kubectl exec busybox-test -t -- sh -c 'cat /mnt/volume1/test.log'
hello

# 删除pvc和busybox pod
$ kubectl delete -f busybox-test.yaml
persistentvolumeclaim "neonsan-test-pvc" deleted
pod "busybox-test" deleted
```


# 登录portal
1. 查看portal映射出来的端口

    `kubectl get svc  -A |grep neonio-web`

    ![kubectl get svc  -A |grep neonio-web 回显](docs/images/kubectl_get_svc_web.png)

2. 通过浏览器登录portal：http://k8s_master_ip:32276，用户名/密码：admin@qingstore.com/zhu88jie

    ![UI界面](docs/images/neonio_portal.png)

# 更改安装参数

使用helm install安装NeonIO时，可按需更改某些默认参数，查看所有参数和默认值: `helm show values ./neonio`


- 例如更改storageclass的存储池名称为"neonsan", 卷副本数为3，center的个数为2

    `helm install neonio ./neonio  --namespace kube-system --set sc.pool_name=neonsan --set sc.rep_count=3 --set center.servers=2`

- 例如已经部署了promethus、altermanager，需要对接,并且需要更改prometheus、alertmanager的服务地址

    `helm install neonio ./neonio  --namespace kube-system --set web.prometheus=true  --set web.alertmanager=true  --set web.prometheus_svc=prometheus-operated.monitoring.svc.cluster.local  --set web.alertmanager_svc=alertmanager-operated.monitoring.svc.cluster.local`

- 例如已经部署了promethus、altermanager，需要对接,并且需要更改prometheus、alertmanager的服务地址，并且是部署单机版本的neonio

    `helm install neonio ./neonio  --namespace kube-system --set sc.rep_count=1 --set center.servers=1 --set zookeeper.servers=1 --set galera.servers=1 --set store.servers=1 --set web.servers=1 --set redis.servers=1 --set web.prometheus=true  --set web.alertmanager=true`


# 监控数据
1. 已经部署了promethus、altermanager，并且已经对接，把monitor服务暴露给promethus 

    `kubectl apply -f neonio_monitor_serviceMonitor.yaml`

2. 配置NeonIO的告警规则: 

    `kubectl apply -f neonio-rules.yaml`

3. 通过portal可查看到NeonIO的iops等监控数据

    ![protal 监控数据](docs/images/protal_monitor.png)


# 卸载
1. 查看已经安装的neonio：
    
    `helm list -A`

    ![helm list -A 回显](docs/images/helm_list.png) 

2. 卸载neonio：
    
    `helm uninstall neonio --namespace kube-system`

3. 确认相关neonio pod和storageclass均已被删除,以下命令输出为空

    ```
    kubectl get pod -A | grep neon
    kubectl get storageclass | grep csi-neonsan
    ```

4. 登录到部署zookeeper、mysql的节点清除持久化的元数据

    `rm -rf /opt/neonsan/*`

5. 登录到部署store的节点清除store的配置

    `rm -rf /etc/neonsan/*`



# 故障排查

```
kubectl describe pod <application pod name>
kubectl describe pvc <pvc name>
kubectl get storageclass <storageclass name> -o yaml
kubect logs <neonsan csi pod name> -c <container name>
```

# 应用场景

- k8s集群1部署neonio，k8s集群2通过CSI使用k8s集群1的neonio存储
```
# k8s集群1
root@testr01n01:~# kubectl get node -owide
NAME         STATUS   ROLES           AGE   VERSION   INTERNAL-IP       EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
testr01n01   Ready    master,worker   54d   v1.17.9   192.168.101.174   <none>        Ubuntu 16.04.5 LTS   4.15.0-58-generic   docker://19.3.8
testr01n02   Ready    master,worker   54d   v1.17.9   192.168.101.175   <none>        Ubuntu 16.04.5 LTS   4.15.0-58-generic   docker://19.3.8
testr01n03   Ready    master,worker   54d   v1.17.9   192.168.101.176   <none>        Ubuntu 16.04.5 LTS   4.15.0-58-generic   docker://19.3.8

# k8s集群2
root@host04:~# kubectl get node -owide
NAME     STATUS   ROLES                  AGE    VERSION   INTERNAL-IP       EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
host03   Ready    <none>                 147d   v1.20.1   192.168.101.245   <none>        Ubuntu 16.04.5 LTS   4.4.0-131-generic   docker://19.3.11
host04   Ready    control-plane,master   147d   v1.20.1   192.168.101.250   <none>        Ubuntu 16.04.5 LTS   4.4.0-131-generic   docker://19.3.11
host05   Ready    <none>                 147d   v1.20.1   192.168.101.251   <none>        Ubuntu 16.04.5 LTS   4.4.0-131-generic   docker://19.3.11
host06   Ready    <none>                 147d   v1.20.1   192.168.101.252   <none>        Ubuntu 16.04.5 LTS   4.4.0-131-generic   docker://19.3.11

# k8s集群1参考《安装》章节的3.1-3.6完成neonio的部署，3.1章节部署neonio的命令换成如下：
root@testr01n01:~/neonio/charts# helm install neonio ./neonio --namespace kube-system --set center.hostnetwork=true
NAME: neonio
LAST DEPLOYED: Tue Jun  8 16:35:51 2021
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
TEST SUITE: None

#k8s集群2部署csi-neonio,同样k8s集群2需要满足《前置条件》，提示：需要通过driver.qbd.zk_svc，driver.qbd.center_svc指定zk、center服务组件的node节点IP，比如这里部署这两个服务组件的node节点为192.168.101.174-192.168.101.175-192.168.101.176
root@host04:~/neonio/charts# helm install csi-neonio ./csi-neonio --namespace kube-system --set driver.qbd.zk_svc="192.168.101.174-192.168.101.175-192.168.101.176" --set driver.qbd.center_svc="192.168.101.174-192.168.101.175-192.168.101.176"
NAME: csi-neonio
LAST DEPLOYED: Tue Jun  8 16:44:08 2021
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
TEST SUITE: None

# 查看部署成功
root@host04:~/neonio/charts# kubectl get pod -A |grep neon
kube-system   csi-neonsan-controller-5c848f788c-8d8w8   5/5     Running   0          7m40s
kube-system   csi-neonsan-node-2j5dq                    2/2     Running   0          7m40s
kube-system   csi-neonsan-node-2m52j                    2/2     Running   0          7m40s
kube-system   csi-neonsan-node-6dq68                    2/2     Running   0          7m40s
kube-system   csi-neonsan-node-qdpmq                    2/2     Running   0          7m40s

# k8s集群2通过CSI使用k8s集群1的neonio存储

root@host04:~# cat busybox-test.yaml 
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: neonsan-test-pvc
spec:
  storageClassName: csi-neonsan
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: busybox-test
spec:
  containers:
    - name: busybox
      imagePullPolicy: IfNotPresent
      image: busybox:latest
      command: [ "/bin/sh", "-c", "sleep 1000000000" ]
      volumeMounts:
      - name: volume1
        mountPath: "/mnt/volume1"
  volumes:
  - name: volume1
    persistentVolumeClaim:
      claimName: neonsan-test-pvc
  restartPolicy: Never


root@host04:~# kubectl apply -f busybox-test.yaml 
persistentvolumeclaim/neonsan-test-pvc created
pod/busybox-test created

root@host04:~# kubectl get pod 
NAME           READY   STATUS    RESTARTS   AGE
busybox-test   1/1     Running   0          30s

root@host04:~# kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                      STORAGECLASS   REASON   AGE
pvc-ccc2e1b6-1643-45cf-b875-9411e2f13ed9   10Gi       RWO            Delete           Bound    default/neonsan-test-pvc   csi-neonsan             45s

root@host04:~# kubectl get pvc
NAME               STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
neonsan-test-pvc   Bound    pvc-ccc2e1b6-1643-45cf-b875-9411e2f13ed9   10Gi       RWO            csi-neonsan    49s

```


# 联系方式

我们可以使用 Matrix/slack。 那些想在网上找到我们的人可以通过以下方式加入我们：
- Matrix: <https://matrix.to/#/#neonio:matrix.org>
- Slack: <https://join.slack.com/t/qingstor/shared_invite/zt-quh57ig2-4Oegt91U4KaNz_ouxAI3yQ> (expire on 2021/26/06)   