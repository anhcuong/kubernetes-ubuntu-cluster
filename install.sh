#!/bin/bash -e
#
# Customize the config from 
# https://gist.github.com/ric03uec/81f6dc1208c87e4f4b86#file-vagrant-cmd
# 	

export DEFAULT_CONFIG_PATH=/etc/default/
export DEFAULT_INIT_PATH=/etc/init/
export DEFAULT_INITD_PATH=/etc/init.d/
export EXECUTABLE_LOCATION=/usr/bin/
export ETCD_PORT=4001
export is_success=false

if [[ $# > 0 ]]; then
	if [[ "$1" == "slave" ]]; then
			export INSTALLER_TYPE=slave
	else
			export INSTALLER_TYPE=master
	fi
else
  		export INSTALLER_TYPE=master
fi

config_etcd(){
	chmod o+x etcd_$ETCD_VER/*
	cp -v etcd_$ETCD_VER/* $EXECUTABLE_LOCATION;
	etcd_path=$(which etcd);
    if [[ -z "$etcd_path" ]]; then
      echo 'etcd not installed ...'
      return 1
    else
      echo 'etcd successfully installed ...'
      echo $etcd_path;
      etcd --version;
    fi
}

update_hosts(){

	export NODE_IP="$(ifconfig eth1 | perl -nle'/dr:(\S+)/ && print $1')"
	## Replace the environment app
	sed -i 's/127.0.1.1/'$NODE_IP'/g' /etc/hosts
}

update_kubernetes_master(){
	echo '######### Updating configurations for kubernetes master ############'
	chmod o+x kube_$KUBERNETE_VER/bin/*
	chmod o+x kube_$KUBERNETE_VER/master/init_scripts/*
	chmod o+x kube_$KUBERNETE_VER/master/init_conf/*
	cp -vr supervisord/master_supervisord.conf $DEFAULT_CONFIG_PATH/supervisord.conf
	cp -vr kube_$KUBERNETE_VER/bin/* $EXECUTABLE_LOCATION/
}


update_kubernetes_slave(){
	echo '######### Updating configurations for kubernetes slave ############'
	chmod o+x kube_$KUBERNETE_VER/bin/*
	cp -vr supervisord/slave_supervisord.conf $DEFAULT_CONFIG_PATH/supervisord.conf
	cp -vr kube_$KUBERNETE_VER/bin/* $EXECUTABLE_LOCATION/
}

run_supervisord_slave(){
	echo '######### Run supervisord on slave ############'
	sed -i 's/$MASTER_IP/'$MASTER_IP'/g' $DEFAULT_CONFIG_PATH/supervisord.conf
	supervisord -c $DEFAULT_CONFIG_PATH/supervisord.conf
}

run_supervisord_master(){
	echo '######### Run supervisord on master ############'
	sed -i 's/$MASTER_IP/'$MASTER_IP'/g' $DEFAULT_CONFIG_PATH/supervisord.conf
	supervisord -c $DEFAULT_CONFIG_PATH/supervisord.conf
	sleep 5
	etcdctl mk /coreos.com/network/config '{"Network":"172.17.0.0/16"}'
	is_success=true
}

run_docker_with_flannel_network(){
	service docker stop
	apt-get install -y bridge-utils
	ip link set docker0 down && brctl delbr docker0
	source /run/flannel/subnet.env && sleep 2
	echo "DOCKER_OPTS=\"--bip=$FLANNEL_SUBNET --mtu=$FLANNEL_MTU\" --insecure-registry=11.1.1.94:5000" >> /etc/default/docker
	service docker start
	is_success=true
}

stop_services() {
	# stop any existing services
	if [[ $INSTALLER_TYPE == 'master' ]]; then
		echo 'Stopping master services...'
		killall supervisord || true
		sudo service etcd stop || true
		sudo service kube-apiserver stop || true
		sudo service kube-controller-manager stop || true
		sudo service kube-scheduler stop || true
		sudo rm -rf $EXECUTABLE_LOCATION/kube*
		sudo rm -rf $DEFAULT_CONFIG_PATH/kube*
		sudo rm -rf $EXECUTABLE_LOCATION/etcd*
		sudo rm -rf $DEFAULT_CONFIG_PATH/etcd*
		sudo rm -rf $EXECUTABLE_LOCATION/flannel*
		sudo rm -rf $DEFAULT_CONFIG_PATH/flannel*
		sudo rm -rf $DEFAULT_CONFIG_PATH/docker*
	else
		echo 'Stopping slave services...'
		killall supervisord || true
		sudo service kubelet stop || true
		sudo service kube-proxy stop || true
		sudo rm -rf $EXECUTABLE_LOCATION/kube*
		sudo rm -rf $DEFAULT_CONFIG_PATH/kube*
		sudo rm -rf $EXECUTABLE_LOCATION/flannel*
		sudo rm -rf $DEFAULT_CONFIG_PATH/flannel*
		sudo rm -rf $DEFAULT_CONFIG_PATH/docker*
	fi
}

before_exit() {
  if [ "$is_success" == true ]; then
    echo "Script Completed Successfully";
  else
    echo "Script executing failed";
  fi
}

trap before_exit EXIT
stop_services

trap before_exit EXIT
update_hosts
 
if [[ $INSTALLER_TYPE == 'master' ]]; then
  trap before_exit EXIT
  config_etcd
  
  trap before_exit EXIT
  update_kubernetes_master

  trap before_exit EXIT
  run_supervisord_master
else
  trap before_exit EXIT
  update_kubernetes_slave

  trap before_exit EXIT
  run_supervisord_slave

  trap before_exit EXIT
  run_docker_with_flannel_network

fi
 
echo "Kubernetes $INSTALLER_TYPE install completed"

