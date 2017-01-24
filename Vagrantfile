# -*- mode: ruby -*-
# vi: set ft=ruby :

# Populate stuff
VAGRANTFILE_API_VERSION = "2"
# Disk Value
d = 1
# Ceph specific stuff
ceph_src_dir = ENV['CEPH_SRC_DIR'] || "#{File.dirname(__dir__)}/ceph"
ENV['CEPH_MON'] ? ceph_mon = "MON=#{ENV['CEPH_MON']}" : ceph_mon = ""
ENV['CEPH_MDS'] ? ceph_mds = "MDS=#{ENV['CEPH_MDS']}" : ceph_mds = ""
ENV['CEPH_OSD'] ? ceph_osd = "OSD=#{ENV['CEPH_OSD']}" : ceph_osd = ""

# Needed maybe?
# required_plugins = %w( vagrant-proxyconf )

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntu/trusty64"
#  config.vm.box = "fedora/24-cloud-base"

  # Install plugins that you might need.
  if ENV['http_proxy'] || ENV['HTTP_PROXY']
	  system "vagrant plugin install vagrant-proxyconf" unless Vagrant.has_plugin?("vagrant-proxyconf")
  end

  config.vm.define :cephaio do |cephaio|
    cephaio.vm.provider :virtualbox do |vb|
		vb.customize [ "createhd", "--filename", "disk-#{d}", "--size", "1000" ]
# 		vb.customize ["storagectl", :id,
# 				      "--name", "SATA Controller",
# 					  "--add", "sata" ]
		vb.customize [ "storageattach", :id,
				       "--storagectl", "SATAController",
					   "--port", 3 + d,
					   "--device", 0,
					   "--type", "hdd",
					   "--medium", "disk-#{d}.vdi" ]
		vb.customize [ "modifyvm", :id, "--memory", "2048", "--cpus", "2" ]
	end

	# Network & Misc Configurations
    cephaio.vm.network :private_network, ip: "172.16.10.10"
    cephaio.vm.hostname = "cephaio"

	# Set proxy
	if Vagrant.has_plugin?("vagrant-proxyconf")
		config.proxy.http = (ENV['http_proxy']||ENV['HTTP_PROXY'])
		config.proxy.https = (ENV['https_proxy']||ENV['HTTPS_PROXY'])
		config.proxy.no_proxy =  (ENV['no_proxy']+",172.16.10.10" || ENV['NO_PROXY']+",172.16.10.10" || 'localhost,127.0.0.1,172.16.10.10')
	end

	# Sync ceph source dir
    cephaio.vm.synced_folder "#{ceph_src_dir}", "#{ceph_src_dir}", type: 'nfs'

#############################################################
# PROVISIONING OF THE VM
#############################################################

	# Install packages
	config.vm.provision "shell", inline: <<-SHELL
	  # sudo add-apt-repository -y ppa:lttng/ppa
	  sudo apt-get update
	  # sudo dnf update
	  cd #{ceph_src_dir}
	  ./install-deps.sh
	  sudo apt-get install -y lttng-tools libbabeltrace-ctf-dev libbabeltrace-dev libbabeltrace-ctf1 liblttng-ust-dev
	SHELL

	# Prepare disk for use with ceph
	config.vm.provision "shell", inline: <<-SHELL
	  sudo parted /dev/sdb mktable gpt
	  sudo parted /dev/sdb mkpart xfs '0%' '100%'
	  sudo /sbin/mkfs.xfs /dev/sdb1
	  sudo mkdir -p /data/ceph-disk
	  sudo mount -t xfs /dev/sdb1 /data/ceph-disk
	  sudo chown -R vagrant.vagrant /data/ceph-disk/
	SHELL

	# Run ceph
	if File.directory?(File.expand_path("#{ceph_src_dir}/build"))
	    config.vm.provision "shell", privileged: false, inline: <<-SHELL
	      cd #{ceph_src_dir}/build
	      #{ceph_mon} #{ceph_mds} #{ceph_osd} CEPH_DEV_DIR=/data/ceph-disk #{ceph_src_dir}/src/vstart.sh -d -n -x
	    SHELL
	else
	    config.vm.provision "shell", privileged: false, inline: <<-SHELL
	      cd #{ceph_src_dir}/src
	      #{ceph_mon} #{ceph_mds} #{ceph_osd} CEPH_DEV_DIR=/data/ceph-disk #{ceph_src_dir}/src/vstart.sh -d -n -x
	    SHELL
	end
  end
end
