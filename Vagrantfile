# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.define "kube-master" do |master|
    master.vm.box = "ubuntu/trusty64"
    master.vm.network "forwarded_port", guest: 8080, host: 8080
    master.vm.network "private_network", ip: "192.168.33.50"
    master.vm.hostname = "kube-master"
    master.vm.provision "shell", inline: <<-SHELL
		sudo -s
		add-apt-repository ppa:saltstack/salt
		apt-get update
		apt-get install -y salt-master
		killall salt-master
		echo "file_roots:" $'\n' "base: " $'\n' "- /srv/salt/ " >> /etc/salt/master 
		salt-master -d
		# This part could be improved using salt in the future
		# Install docker
		wget -qO- https://get.docker.com/ | sh
		# Download kubernete shell script and install
		git clone https://github.com/anhcuong/kubernetes-ubuntu-cluster.git
		cd kubernete-ubuntu-cluster/
		chmod o+x install.sh
		export MASTER_IP=192.168.33.50
		export KUBERNETE_VERSION=v0.19.3
		export ETCD_VERSION=v2.0.5
		./install.sh master
	SHELL
  end

  (1..2).each do |i|
	  config.vm.define "kube-slave-#{i}" do |slave|
	    slave.vm.box = "ubuntu/trusty64"
	    slave.vm.network "private_network", ip: "192.168.33.#{i}"
	    slave.vm.hostname = "kube-slave-#{i}"
	    slave.vm.provider "virtualbox" do |vb|
			# vb.gui = true
			vb.memory = 2048
		end
		slave.vm.provision "shell", inline: <<-SHELL
			sudo -s
			add-apt-repository ppa:saltstack/salt
			apt-get update
			apt-get install -y salt-minion
			echo "master: 192.168.33.50" >> /etc/salt/minion
			salt-minion -d
			# This part could be improved using salt in the future
			# Install docker
			wget -qO- https://get.docker.com/ | sh
			# Download kubernete shell script and install
			git clone https://github.com/anhcuong/kubernetes-ubuntu-cluster.git
			cd kubernete-ubuntu-cluster/
			chmod o+x install.sh
			export MASTER_IP=192.168.33.50
			export KUBERNETE_VERSION=v0.19.3
			export ETCD_VERSION=v2.0.5
			./install.sh slave
		SHELL
	  end
  end
end