## Introduction
- 3-July-2015
- Script files needed for kubernete setup
- Latest kubernete version: 0.19.3
- Latest etcd version: 2.0.5

## Usage
- Run the install.sh script. The script will help you to:
	- Copy all the files in bin/ folder into /usr/bin/ of your machines
	- Copy all the files in etcd/ folder into /usr/bin/ of your master machine
	- Copy all the files in master/init_conf/ into /etc/init/ of your master machine
	- Copy all the files in master/init_scripts/ into /etc/init.d/ of your master machine
	- Copy all the files in minion/init_conf/ into /etc/init/ of your minion machines
	- Copy all the files in minion/init_scripts/ into /etc/init.d/ of your minion machines
	- Config kubernete and etcd settings

```sh
# Run install script, state your master IP, kubernete, etcd version and type of machine (master/slave)
chmod o+x install.sh
export MASTER_IP=192.168.33.50
export KUBERNETE_VERSION=v0.19.3
export ETCD_VERSION=v2.0.5
./install.sh master/slave
```

## Contacts
[Frank Tran](https://bitbucket.org/FrankRazer)