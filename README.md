# Openlico container deployment

## Introduction

openlico-docker is used for building openlico(include [openlico backend](https://github.com/lenovo/openlico.git) and [openlico frontend](https://github.com/lenovo/openlico-portal.git)) docker image and deloying openlico container as well.


**note: Openlico docker container should be deployed on management node of hpc cluster.** 
## Prerequisite
1. Openhpc, openldap, icinga have been installed in the hpc cluster.
2. Docker have been installed on management node. Please refer to [Install Docker Engine](https://docs.docker.com/engine/install/) to install Docker.


## Deploy LiCO in container
### 1. Create image build folder and clone openlico source code

```sh
version=<main>
mkdir -p openlico_container/$version
cd openlico_container/$version

git clone https://github.com/lenovo/openlico.git -b $version
git clone https://github.com/lenovo/openlico-portal.git -b $version
git clone https://github.com/lenovo/openlico-docker.git -b $version
cp  openlico-docker/Dockerfile openlico-docker/scripts/build.sh .
chmod +x ./build.sh
cp openlico-docker/scripts/lico-control /usr/bin/
chmod +x /usr/bin/lico-control

```


### 2. Generate Nginx https certification

```sh
./build.sh --genSslCert 
```

### 3. Prepare script
If the host OS is based on Ubuntu,please update the deploy script as below, 
otherwise please skip this step:

```shell
vi /usr/bin/lico-control
```

**Navigate the ENSURE_PATH globle variable， replace the "/opt/ohpc" path with your real hpc module path. For Ubuntu OS the default hpc module path is /opt/hpc, the change is shown as below.**

```bash
ENSURE_PATH=("/root/.ssh" "/etc/libuser.conf" "/etc/lico"  "/opt/hpc" "/etc/localtime")
```
**Modify start script**
```shell
vi openlico-docker/scripts/start
```
 **Add two lines before "lico start --start-only"**

```shell
mkdir -p /usr/lib/x86_64-linux-gnu/
ln -s /usr/lib64/slurm /usr/lib/x86_64-linux-gnu/slurm-wlm
```

### 4. Build docker image

```sh
# Default
./build.sh 
# To accelerate building docker image, you can use npm mirror and pypi mirror, like following command
./build.sh  --npm-registry <https://registry.npm.taobao.org/> --pypi-url <https://pypi.tuna.tsinghua.edu.cn/simple> 

```




### 5. Prepare mount folder and config file

```sh
lico-control prepare
```




**Configure /etc/lico/nodes.csv, adding manage node and compute node,like following example**

```
"# This file is using to define the basic information for datacenter room, logical groups, rows, racks, chassis and nodes."
"# We recommend edit this file using Excel or other table editing software."
"# Notes:"
"# The lines that start with '#' are comment lines. Please delete them, if you don't need them."
"# There is one sample line in every below tables. Please replace them with your real data."
,,,,,,,,,,,,,,
"# Please enter datacenter room information in the below table."
"# LiCO only support one datacenter room currently."
room,name,location_description,,,,,,,,,,,,
,ShangHai Solution Room,Shanghai Zhangjiang,,,,,,,,,,,,
,,,,,,,,,,,,,,
"# Please enter the logic groups information in the below table."
"# The cluster nodes can be divided into groups logically. This is helpful for monitoring, querying, statistics, etc."
"# The logic groups do not impact the use of computing resources or permissions configurations."
group,name,,,,,,,,,,,,,
,login,,,,,,,,,,,,,
,head,,,,,,,,,,,,,
,compute,,,,,,,,,,,,,
,io,,,,,,,,,,,,,
,,,,,,,,,,,,,,
"# Please enter the rows information in the below table."
"# The row refers to the rack order in the datacenter room."
"# Columns:"
"# name - Row name, must be unique in the same room."
"# index - Row order, must be a positive integer and be unique in the same room."
"# belonging_room - Name of the room where the row belongs. The room must be entered into the room table before."
row,name,index,belonging_room,,,,,,,,,,,
,row1,1,ShangHai Solution Room,,,,,,,,,,,
,,,,,,,,,,,,,,
"# Please enter the racks information in the below table."
"# Columns:"
"# name - Rack name, must be unique in the same room."
"# column - Rack location column, must be a positive integer and be unique in the same row."
"# belonging_row - Name of the row where the rack belongs. The row must be entered into the row table before."
rack,name,column,belonging_row,,,,,,,,,,,
,rack1,1,row1,,,,,,,,,,,
,,,,,,,,,,,,,,
"# Please enter the chassis information in the below table, if there are chassis in the cluster."
"# Columns:"
"# name - Chassis name, must be unique in the same room."
"# belonging_rack - Name of the rack where the chassis belongs. The rack must be entered into the rack table before."
"# location_u_in_rack - Location of the chassis base in the rack(Unit is U). In a standard cabinet, the value should be between 1 and 42."
"# machine_type - Chassis type or product code, refere to the "Supported servers and chassis models" part in installation guide."
chassis,name,belonging_rack,location_u_in_rack,machine_type,,,,,,,,,,
,chassis1,rack1,7,7X20,,,,,,,,,,
,,,,,,,,,,,,,,
"# Please enter the information about all nodes in the cluster into the below table."
"# Every node should belong to one rack or one chassis in the rack."
"# Columns:"
"# name - Node hostname, domain name is not needed."
"# nodetype - Node type, support head,login or compute."
"# immip: IP address of the node's BMC system."
"# hostip: IP address of the node on the host network."
"# machine_type: Node type or product code, refere to the "Supported servers and chassis models" part in installation guide."
"# ipmi_user: Account of the node's BMC system."
"# ipmi_pwd: Password of the node's BMC system."
"# belonging_rack: Name of the rack where the node belongs. The rack must be entered into the rack table before."
"# belonging_chassis: Name of the chassis where the node belongs. The chassis must be entered into the rack table before. Make this field empty, if the node does not locate in any chassis)."
"# location_u: Node location. If the node is located in the chassis, enter the slot in the chassis in which the node is located. If the node is located in a rack, enter the location of the node base in the rack (Unit is U)."
"# groups: Name of the node location logic group. One node can belong to multiple logic groups. Group names should be separated by ;. The logic groups must be entered into the logic group table before."
node,name,nodetype,immip,hostip,machine_type,ipmi_user,ipmi_pwd,belonging_rack,belonging_chassis,location_u,groups
,head,head,10.240.212.13,127.0.0.1,7X05,<ipmi_user>,<ipmi_pwd>,rack1,,2,login
```





**Modify /etc/lico/password-tool.ini, configure service account and password**

```ini
[mariadb]
username = "<username>"
password = "<password>"

[influxdb]
username = "<username>"
password = "<password>"

[confluent]
username = "<username>"
password = "<password>"

[icinga]
username = "<username>"
password = "<password>"

[ldap]
password = "<password>"

[datasource]
username = "<username>"
password = "<password>"

```



### 6. Initial data for openlico

**If using mariadb and influxdb inside the container, run this command**
```shell
lico-control init --mode all --inner-db true
````
**If using external mariadb and influxdb, run following command**
```shell
lico-control init --mode all 
```


### 7. Create and run a new LiCO container from an image
**If using mariadb and influxdb inside the container, run this command**
```shell
lico-control run --inner-db true
```
**If using external mariadb and influxdb, run following command**
```shell
lico-control run 
```

### Other Operation:
```shell
lico-control start       #Start stopped LiCO container
lico-control stop        #Stop running LiCO container
lico-control restart     #Restart LiCO container
lico-control remove      #Remove LiCO container
```

