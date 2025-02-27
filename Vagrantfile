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

  # Manager VM
  config.vm.define "manager" do |manager|
    manager.vm.hostname = "manager"
    manager.vm.network "private_network", type: "dhcp"

    # Forward port 80 on the guest to port 80 on the host
    manager.vm.network "forwarded_port", guest: 80, host: 80

    # Forward port 9443 on the guest to port 9443 on the host
    manager.vm.network "forwarded_port", guest: 9443, host: 9443, auto_correct: true

    # Sync kubeconfig from the VM to the host project directory
    manager.vm.synced_folder ".", "/vagrant"

    manager.vm.provision "shell", run: "always", inline: <<-SHELL
      # Initialize
      /vagrant/bin/super init

      # Copy Token
      docker swarm join-token worker | grep -oE 'SWMTKN-[A-Za-z0-9-]+' > /vagrant/token.txt

      # Copy IP Address
      docker swarm join-token worker | grep -oE '([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+)' > /vagrant/ip.txt
    SHELL
  end

  # Worker VM
  config.vm.define "worker" do |worker|
    worker.vm.hostname = "worker"
    worker.vm.network "private_network", type: "dhcp"
  
    worker.vm.provision "shell", run: "always", inline: <<-SHELL
      # Join
      /vagrant/bin/super join --token $(cat /vagrant/token.txt) $(cat /vagrant/ip.txt):2377
    SHELL
  end

end