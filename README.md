## Introduction
- 3-July-2015
- Script files needed for kubernete setup
- Latest kubernete version: 0.19.3

## Usage
- Run the install.sh script. The script will help you to:
	- Copy all the files in bin/ folder into /usr/bin/ of your machine
	- Copy all the files in master/init_conf/ into /etc/init/ of your master machine
	- Copy all the files in master/init_scripts/ into /etc/init.d/ of your master machine
	- Copy all the files in minion/init_conf/ into /etc/init/ of your minion machine
	- Copy all the files in minion/init_scripts/ into /etc/init.d/ of your minion machine
	- Config kubernete and etcd settings

```sh
# Run install script, state your kubernete version
export VERSION=0.19.3
./install.sh $VERSION
```

## Contacts
[Frank Tran](https://bitbucket.org/FrankRazer)