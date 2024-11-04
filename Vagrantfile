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
      vmware.memory = 2048
      vmware.cpus = 2

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

    master.vm.provision "shell", run: "always", inline: <<-SHELL
      /vagrant/bin/super master init
    SHELL
  end

  # Worker VM
  config.vm.define "worker" do |worker|
    worker.vm.hostname = "worker"
    worker.vm.network "private_network", type: "dhcp"

    worker.vm.provision "shell", run: "always", inline: <<-SHELL
      /vagrant/bin/super worker init
    SHELL
  end

end