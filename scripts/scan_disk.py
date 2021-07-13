#!/usr/bin/env python
# -*- coding:utf-8 -*-
# Author:yangxingxiang
import sys
import os
import re
import json
  

DISKIDPATH = "/dev/disk/by-id/"

def execCmd(cmd):  
    r = os.popen(cmd)  
    text = r.read()  
    r.close()  
    return text  

def GetDiskIdDic():
    diskIdDic = {}
    cmd = "ls -l"  + " " + DISKIDPATH + " " + "|awk '{ print $9 $11}'|xargs"
    result = execCmd(cmd)
    diskInfoList = result.split(" ")
    for diskInfo in diskInfoList:
        diskInfoTmp = diskInfo.split("../../")
        if len(diskInfoTmp) == 2:
           diskIdDic[diskInfoTmp[1]] = diskInfoTmp[0]
    
    return diskIdDic
    
def GetDiskNameOrDiskIdList(deviceFilter):
    diskIdDic = GetDiskIdDic()
    diskIdOrNameList = []
    cmd = "lsblk -f -J"  
    result = execCmd(cmd)
    diskDic = json.loads(result)
    diskList = diskDic.get("blockdevices", [])
    for _, disk in enumerate(diskList):
        # 磁盘没有分区且没有文件系统,则可以作为neonio使用的磁盘
        if disk.get("children") is None and disk.get("fstype") is None:
            diskName = disk.get("name")
            if diskName is None:
                continue
            # 如果磁盘名包含需要过滤的磁盘，则过滤掉
            if deviceFilter != "":
                if re.search(deviceFilter, diskName) is not None:
                    continue
            # 如果查询不到磁盘设备，过滤掉，vmware虚拟机会多出一个sr0的设备，过滤掉
            if os.system("fdisk -l|grep -w" + " " + "/dev/" + diskName + " > /dev/null"):
                continue
                
            diskId = diskIdDic.get(diskName)
            # 目前容器化不支持用by-Id，因为容器化中不能调用ssh远程调用脚本，因此，只能配置设备名
            # 如果有by-id，则用by-id，否则用磁盘名
            # if diskId is not None:
            #    diskIdOrNameList.append(DISKIDPATH + diskId)
            # else:
            diskIdOrNameList.append("/dev/" + diskName)
                
    return diskIdOrNameList

 
 
if __name__ == '__main__': 
    if len(sys.argv) != 2:
        exit(1)
    
    deviceFilter = sys.argv[1]
    diskIdOrNameList = GetDiskNameOrDiskIdList(deviceFilter)
    print " ".join(diskIdOrNameList)
    