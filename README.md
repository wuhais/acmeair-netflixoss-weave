Acmeair-netflix-docker
======================
These instructions are based on Docker 1.0.0 run on Ubuntu trusty boot2docker. [(Japanese)](README_ja.md) [(Chinese)](README_zh.md)
## The source code

The original project is forked from [here](https://github.com/aspyker/acmeair-netflixoss-dockerlocal). Base on the original version, we setup weave as the docker network overlay. 

## The topology

![topology](images/topology.png)

## Configurations
### Enable remote API access of Docker daemon via TCP socket
Change Docker daemon startup configuration (`/etc/default/docker`) like as bellow. On boot2docker, it is enabled by default.

```bash
# Use DOCKER_OPTS to modify the daemon startup options.
#DOCKER_OPTS="-dns 8.8.8.8 -dns 8.8.4.4"
DOCKER_OPTS="-H tcp://0.0.0.0:2375 -H unix://var/run/docker.sock"
```

### Docker client command
If you need `sudo` with `docker` command, change `docker_cmd` in `bin/env.sh`.

```bash
docker_cmd="sudo docker"
```

### The bridge name which is used by Docker daemon
If your Docker daemon uses a bridge different from `docker0`, change `bridge_name` in `bin/env.sh`.

```bash
bridge_name=docker0
```

## Build images
You have to go through the following steps to build the images

### Agree the licenses before building the images and use them.

```bash
cd bin
./acceptlicenses.sh
```

### Build the source code
Before doing this, make sure you have [gradle](https://gradle.org/) already being installed.

Install jdk by 
```bash
apt-get install openjdk-7-jdk
```
Update ```workspace/gradle.properties``` and point the ```org.gradle.java.home``` to your local JAVA_HOME

```bash
cd workspace
./gradlew
./gradlew distZip
```
To list other gradle tasks, try the following:
```bash
cd workspace
./gradlew tasks
```
To work with eclipse:
```bash
cd workspace
./gradlew eclipse
```

### Build the docker images
```bash
cd bin
./buildimages.sh
```

An SSH key pair is created in this process. That is `bin/id_rsa` and `bin/id_rsa.pub`. The private key is used for login to the instances via SSH. If you want to use another key pair, place it in `bin` directory as `id_rsa` and `id_rsa.pub`.

Or you can get all the images from our docker repository by running 

```bash
cd bin
./pullimages.sh
```

## Run acmeair on one docker host (without weave) 
### Start the minimum set of containers (with Microscaler)
`startminimum.sh` starts the minimum set of containers. The script starts SkyDNS, SkyDock, one Cassandra (cassandra1), the data loader, Eureka server (service registry), Zuul (load balancer), Microscaler and Microscaler Agent. Two auto scaling groups (ASGs) are created. One is for the authentication service, another is for the web application. Each ASG has one instance as the desired capacity. The one auth-service and one webapp are started by Microscaler. Please wait few minutes after the command finishes.

```bash
cd bin
./startminimum.sh
```
### Populate the cassandra database
Populate the database with the following command

```bash
cd bin
./runloader.sh
```
By default, the loader will populate ```30000``` customers. If you want to change this number, you can change the code from [here](https://github.com/wuhais/acmeair-netflixoss-weave/blob/weave/workspace/acmeair-loader/src/main/resources/loader.properties) and recompile the whole loader project.
Sometimes, we may end up with having trouble in accessing the cassandra database due to dns error. The solution will be to restart both the ```skydns``` container and ```skydock``` container. Then try the same ```runloader.sh``` command again. 

### Start the minimum set of containers (without Microscaler)
`startallexceptscaler.sh` starts one container per each service. The script starts one SkyDNS, one SkyDock, one Cassandra (cassandra1), one data loader, one Eureka server, one Zuul, one web application instance, one authentication service instance.

```bash
cd bin
./startallexceptscaler.sh
```

### Stop all the running containers
```bash
cd bin
./stopall.sh
```

## Run acmeair on multiple docker hosts (with weave version 1.0.0 +)
We can also leverage [weave](https://github.com/weaveworks/weave) to setup the network overlay for docker containers. Before doing this, you need to install weave on every docker hosts by 
```bach
sudo curl -L git.io/weave -o /usr/local/bin/weave
sudo chmod a+x /usr/local/bin/weave
weave
weave setup
```
Check the setup of weave by
```bash
root@acmeair-services3:~/acmeair-netflix# weave version
weave script 1.0.1
weave router 1.0.1
weave DNS 1.0.1
weave exec 1.0.1
```

### Start the minimum set of containers (without Microscaler)
Update the ```env.sh``` on every docker host
```bash
cd weave-bin
vi env.sh
```
Revise the following config
```base
iprange=11.128.0.1/24  #Your prefer iprange
dnsrange=11.128.254.1/24 #Update the dns according to your iprange. Each docker host needs its own range, such as 11.128.254.3/2, 11.128.254.5/24 etc.
iplist="acmeair-services acmeair-services2 acmeair-services3" #Your docker hostname. Remember NOT to include the docker host's own name
```
Enable weave on each docker host by
```bash
cd weave-bin
./startweave.sh
```
Run each service on the docker hosts seperately, for example
On ```acmeair-services``` 
```bash
cd weave-bin
./startzuul.sh
./starteureka.sh
```
On ```acmeair-services2```
```bash
cd weave-bin
./addwebapp.sh
```
On ```acmeair-services3```
```bash
cd weave-bin
./addauthsvc.sh
```
On ```acmeair-services4```
```bash
cd weave-bin
./addcassandra.sh
./runloader.sh
```
### Stop all the running containers
```bash
cd weave-bin
./stopall.sh
```

## Switch the application servers
The default application server for auth-service and webbapp is IBM WebSphere Application Server Liberty profile (WLP). You can use Tomcat instead of WLP. Change `appserver` value in `bin/env.sh`.

```bash
# "wlp" for WAS Liberty profile or "tc" for Tomcat
appserver=tc
```

Delete and create the ASGs (and the loader configurations) to run auth-service and webapp on Tomcat.

```bash
cd bin
./deleteasg.sh
./configureasg.sh
./startasg.sh
```

## Add additional containers
Auth-service and webapp are managed by Microscaler. If you want more those instances, change ASG configuration.

### Cassandra

```bash
./addcassandra.sh
```

## Stop all containers and clean the environment

```bash
./stopall.sh
```

## Show IP Addresses of the containers

```bash
./showipaddrs.sh
```

## Login to the container
Use SSH. SSH servers run on all containers except SkyDNS and SkyDock.

```bash
ssh -i bin/id_rsa root@172.17.0.5
```

## Quick test
### Zuul and webapp

```bash
./testwebapp.sh
```

or

```bash
./testwebapp.sh 172.17.0.6
```

### auth-service

```bash
./testauth.sh
```

or

```bash
./testauth.sh 172.17.0.9
```

### Cassandra

```bash
./showcassandrastatus.sh

./showcustomertable.sh
```

## Check name resolution

```bash
root@acmeair-services:~/acmeair-netflix/bin# ./testdns.sh
172.17.0.124
172.17.0.123
172.17.0.119

```
if there are less than 3 returning IPs, it means the skydns is not properly working. Try to retart the docker containers for both skydns and skydock. After finished, rerun the same test. 

```bash
dig @172.17.42.1 +short zuul.*.local.flyacmeair.net
dig @172.17.42.1 +short eureka.*.local.flyacmeair.net
dig @172.17.42.1 +short cassandra1.*.local.flyacmeair.net
dig @172.17.42.1 +short webapp1.*.local.flyacmeair.net
dig @172.17.42.1 +short auth1.*.local.flyacmeair.net
```

## Jmeter
Follow the instructions [here](https://github.com/wuhais/acmeair-netflixoss-weave/tree/weave/workspace/acmeair-driver) to setup your workload generator.

## Problem?
Make sure your docker version. The version might be different from the assumption of these instructions.

```bash
$ docker version
Client version: 1.0.0
Client API version: 1.12
Go version (client): go1.2.1
Git commit (client): 63fe64c
Server version: 1.0.0
Server API version: 1.12
Go version (server): go1.2.1
Git commit (server): 63fe64c
```

TCP socket might not be enabled. Check options of Docker daemon.

```bash
$ ps -ef | grep docker
root     22320     1  0 14:06 ?        00:01:00 /usr/bin/docker -d -H tcp://0.0.0.0:2735 -H unix://var/run/docker.sock
```

Your firewall might block the communications between the containers and the Docker daemon. Please check your firewall rules.

SkyDock might not work properly. Please try restart `skydock`. SkyDock registers all running containers at its start time. You don't have to restart other containers.

```bash
docker restart skydock
```

The Docker images might different as you assume. Try following commands to clear images. NOTICE: the following commands stop all containers and remove all containers and images.

```bash
docker rm -f `docker ps -qa`
docker rmi `docker images -q`
```

## Software versions
|Image|Name|Version|Format|Source|
|-----|----|------|------|-------|
|asgard|Asgard|latest (dockerlocal branch)|binary|https://acmeair.ci.cloudbees.com/job/asgard-etiport/|
|asgard|MongoDB|2.4.9|binary|Ubuntu repository|
|auth-service|NetflixOSS Acme Air|latest (astyanax branch)|binary|https://acmeair.ci.cloudbees.com/job/acmeair-netflix-astyanax/|
|base|Oracle Java|7|binary|https://launchpad.net/~webupd8team/+archive/java/|
|base|ruby|1.9.3|binary|Ubuntu repository|
|base|sshd|6.6|binary|Ubuntu repository|
|base|supervisor|3.0|binary|Ubuntu repository|
|base|Ubuntu Linux|14.04|binary|[Docker Index](https://index.docker.io/)|
|cassandra|Cassandra|2.0.7|binary|http://cassandra.apache.org/|
|eureka|Eureka server|1.1.132|binary|Maven Central Repository|
|ibmjava|IBM Java|7.0 SR5|binary|https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/wasdev/downloads/jre/index.yml|
|liberty|IBM WebSphere Application Server Liberty profile|8.5.5.2|binary|https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/wasdev/downloads/wlp/index.yml|
|loader|Acme Air loader|latest (astyanax branch)|binary|https://acmeair.ci.cloudbees.com/job/acmeair-netflix-astyanax/|
|microscaler|Microscaler CLI|latest|source|https://github.com/EmergingTechnologyInstitute/microscaler/|
|microscaler|Microscaler|latest|source|https://github.com/EmergingTechnologyInstitute/microscaler/|
|microscaler|gnatsd|latest|source|https://github.com/apcera/gnatsd/|
|microscaler|Go|1.2.1|binary|Ubuntu repository|
|microscaler|MongoDB|2.4.9|binary|Ubuntu repository|
|microscaler|Redis|2.8.4|binary|Ubuntu repository|
|microscaler-agent|Microscaler Agent|latest|source|https://github.com/EmergingTechnologyInstitute/microscaler/|
|skydns|SkyDNS|latest|binary|[Docker Index](https://index.docker.io/)|
|skydock|SkyDock|latest|binary|[Docker Index](https://index.docker.io/)|
|tomcat|Tomcat|7.0.54|binary|http://tomcat.apache.org/|
|webapp|Acme Air|latest (astyanax branch)|binary|https://acmeair.ci.cloudbees.com/job/acmeair-netflix-astyanax/|
|zuul|Zuul|1.0.21|binary|Maven Central Repository|
