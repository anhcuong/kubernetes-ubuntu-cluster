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
	chmod o+x etcd_$ETCD_VERSION/*
	cp -v etcd_$ETCD_VERSION/* $EXECUTABLE_LOCATION;
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

update_etcd(){
	echo '######### Updating configurations for etcd master ############'
	echo "ETCD=$EXECUTABLE_LOCATION/etcd" | sudo tee -a  $DEFAULT_CONFIG_PATH/etcd
    echo "ETCD_OPTS=--listen-client-urls=http://0.0.0.0:$ETCD_PORT" | sudo tee -a $DEFAULT_CONFIG_PATH/etcd
    echo "etcd config updated successfully"
}

update_kubernetes_master(){
	echo '######### Updating configurations for kubernetes master ############'
	chmod o+x kube_$KUBERNETE_VERSION/bin/*
	chmod o+x kube_$KUBERNETE_VERSION/master/init_scripts/*
	chmod o+x kube_$KUBERNETE_VERSION/master/init_conf/*
	cp -vr kube_$KUBERNETE_VERSION/bin/* $EXECUTABLE_LOCATION/
	cp -vr kube_$KUBERNETE_VERSION/master/init_conf/* $DEFAULT_INIT_PATH/
	cp -vr kube_$KUBERNETE_VERSION/master/init_scripts/* $DEFAULT_INITD_PATH/
	# update kube-apiserver config
    echo "KUBE_APISERVER=$EXECUTABLE_LOCATION/kube-apiserver" | sudo tee -a  $DEFAULT_CONFIG_PATH/kube-apiserver
    echo -e "KUBE_APISERVER_OPTS=\"--address=0.0.0.0 --port=8080 --etcd_servers=http://localhost:4001 --portal_net=11.1.1.0/24 --allow_privileged=true --kubelet_port=10250 --v=0 \"" | sudo tee -a $DEFAULT_CONFIG_PATH/kube-apiserver
    echo 'kube-apiserver config updated successfully'
 
    # update kube-controller manager config
    echo "KUBE_CONTROLLER_MANAGER=$EXECUTABLE_LOCATION/kube-controller-manager" | sudo tee -a  $DEFAULT_CONFIG_PATH/kube-controller-manager
    echo -e "KUBE_CONTROLLER_MANAGER_OPTS=\"--address=0.0.0.0 --master=127.0.0.1:8080 --v=0 \"" | sudo tee -a $DEFAULT_CONFIG_PATH/kube-controller-manager
    echo "kube-controller-manager config updated successfully"
 
 
    # update kube-scheduler config
    echo "KUBE_SCHEDULER=$EXECUTABLE_LOCATION/kube-scheduler" | sudo tee -a  $DEFAULT_CONFIG_PATH/kube-scheduler
    echo -e "KUBE_SCHEDULER_OPTS=\"--address=0.0.0.0 --master=127.0.0.1:8080 --v=0 \"" | sudo tee -a $DEFAULT_CONFIG_PATH/kube-scheduler
    echo "kube-scheduler config updated successfully"
}

update_hosts(){

	export NODE_IP="$(ifconfig eth1 | perl -nle'/dr:(\S+)/ && print $1')"
	## Replace the environment app
	sed -i 's/127.0.1.1/'$NODE_IP'/g' /etc/hosts
}

update_kubernetes_slave(){
	echo '######### Updating configurations for kubernetes slave ############'
	chmod o+x kube_$KUBERNETE_VERSION/bin/*
	chmod o+x kube_$KUBERNETE_VERSION/minion/init_scripts/*
	chmod o+x kube_$KUBERNETE_VERSION/minion/init_conf/*
	cp -vr kube_$KUBERNETE_VERSION/bin/* $EXECUTABLE_LOCATION/
	cp -vr kube_$KUBERNETE_VERSION/minion/init_conf/* $DEFAULT_INIT_PATH/
	cp -vr kube_$KUBERNETE_VERSION/minion/init_scripts/* $DEFAULT_INITD_PATH/
	# update kubelet config
    echo "KUBELET=$EXECUTABLE_LOCATION/kubelet" | sudo tee -a /etc/default/kubelet
    echo "KUBELET_OPTS=\"--address=0.0.0.0 --port=10250 --api_servers=http://$MASTER_IP:8080 --enable_server=true --logtostderr=true --v=0\"" | sudo tee -a /etc/default/kubelet
    echo "kubelet config updated successfully"
 
    # update kube-proxy config
    echo "KUBE_PROXY=$EXECUTABLE_LOCATION/kube-proxy" | sudo tee -a  /etc/default/kube-proxy
    echo -e "KUBE_PROXY_OPTS=\" --master=$MASTER_IP:8080 --logtostderr=true \"" | sudo tee -a /etc/default/kube-proxy
    echo "kube-proxy config updated successfully"	
}

run_flannel(){
	echo '######### Updating configurations for flannel slave ############'
	service docker stop
	apt-get install -y bridge-utils
	ip link set docker0 down && brctl delbr docker0
	export FLANNEL_OPTS="--etcd-endpoints=http://$MASTER_IP:4001 --iface=eth1"	
	start-stop-daemon --start --background --quiet --exec /usr/bin/flanneld -- $FLANNEL_OPTS
	sleep 2
	source /run/flannel/subnet.env && sleep 2
	echo "DOCKER_OPTS=\"--bip=$FLANNEL_SUBNET --mtu=$FLANNEL_MTU\"" >> /etc/default/docker
	service docker start
	echo '######### Finish configurations for flannel slave ############'
}

stop_services() {
	# stop any existing services
	if [[ $INSTALLER_TYPE == 'master' ]]; then
		echo 'Stopping master services...'
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
	else
		echo 'Stopping slave services...'
		sudo service kubelet stop || true
		sudo service kube-proxy stop || true
		sudo rm -rf $EXECUTABLE_LOCATION/kube*
		sudo rm -rf $DEFAULT_CONFIG_PATH/kube*
	fi
}

start_services() {
	if [[ $INSTALLER_TYPE == 'master' ]]; then
		echo 'Starting master services...'
		sudo service etcd start && sleep 5
		etcdctl mk /coreos.com/network/config '{"Network":"172.17.0.0/16"}'
		## No need to start kube-apiserver, kube-controller-manager and kube-scheduler
		## because the upstart scripts boot them up when etcd starts
	else
		echo 'Starting slave services...'
		sudo service kubelet start
		sudo service kube-proxy start
	fi
}

check_service_status() {
	if [[ $INSTALLER_TYPE == 'master' ]]; then
		sudo service etcd status
		sudo service kube-apiserver status
		sudo service kube-controller-manager status
		sudo service kube-scheduler status
		echo 'install of kube-master successful'
		is_success=true
	else
		echo 'Checking slave services status...'
		sudo service kubelet status
		sudo service kube-proxy status

		echo 'install of kube-slave successful'
		is_success=true
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
  update_etcd
  
  trap before_exit EXIT
  update_kubernetes_master
  
  trap before_exit EXIT
  start_services
else
  trap before_exit EXIT
  update_kubernetes_slave
  
  trap before_exit EXIT
  start_services

  trap before_exit EXIT
  run_flannel

fi
 
trap before_exit EXIT
check_service_status
 
echo "Kubernetes $INSTALLER_TYPE install completed"

