Vagrant.configure("2") do |config|
  # Detect host architecture
  host_architecture = `uname -m`.strip

  # Set box based on architecture
  config.vm.box = "bento/rockylinux-9.3"
  config.vm.box_version = "202404.23.0"

  # VMware Fusion provider configuration
  config.vm.provider "vmware_desktop" do |vmware|
      if host_architecture == "arm64"
          # Use arm64
          vmware.vmx["guestOS"] = "arm-rhel9-64"
      else
          # Use x86_64 
          vmware.vmx["guestOS"] = "linux"
      end

      # Set the hardware limits
      vmware.memory = 24576 # 24GB
      vmware.cpus = 10 # 10 cores

      # Set the SCSI controller type
      vmware.vmx["scsi0.virtualDev"] = "pvscsi"

      # Enable GUI
      vmware.gui = "true"
  end

  # Master VM
  config.vm.define "master" do |master|
    master.vm.hostname = "master"
    master.vm.network "private_network", type: "dhcp"

    # Forward port 80 on the guest to port 80 on the host
    master.vm.network "forwarded_port", guest: 80, host: 80

    # Forward port 6443 on the guest to port 6443 on the host
    master.vm.network "forwarded_port", guest: 6443, host: 6443, auto_correct: true

    # Sync kubeconfig from the VM to the host project directory
    master.vm.synced_folder ".", "/vagrant"

    master.vm.provision "shell", run: "always", inline: <<-SHELL
      # Initialize the master
      /vagrant/bin/super master init --ip-pool 192.168.1.240/25 --ip-address dhcp --ip-v6-pool 2001:678:7ec:70::1/64 --ip-v6-address dhcp

      # Copy the kubeconfig to the host project directory
      cp /etc/rancher/k3s/k3s.yaml /vagrant/k3s.yaml

      # Replace localhost with 127.0.0.1 in the kubeconfig
      sed -i 's/127.0.0.1/localhost/g' /vagrant/k3s.yaml
    SHELL
  end

  # Worker VM
  #config.vm.define "worker" do |worker|
  #  worker.vm.hostname = "worker"
  #  worker.vm.network "private_network", type: "dhcp"
  #
  #  worker.vm.provision "shell", run: "always", inline: <<-SHELL
  #    /vagrant/bin/super worker init
  #  SHELL
  #end

end