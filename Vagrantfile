Vagrant.configure("2") do |config|
    # Detect host architecture
    host_architecture = `uname -m`.strip

    # Set box based on architecture
    config.vm.box = "rockylinux/9"
    
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

        # Set Ethernet PCI slot number
        vmware.vmx["ethernet0.pcislotnumber"] = "160"

        vmware.vmx["svga.present"] = "FALSE"
        vmware.vmx["svga.autodetect"] = "FALSE"
        vmware.vmx["svga.vramSize"] = "0"

        # Enable GUI
        vmware.gui = "true"
    end

    # Master VM
    config.vm.define "master" do |master|
      master.vm.hostname = "master"
  
      master.vm.provision "shell", inline: <<-SHELL
        /vagrant/bin/convolv master init
      SHELL

    end
  
    # Worker VM
    config.vm.define "worker" do |worker|
      worker.vm.hostname = "worker"
  
      worker.vm.provision "shell", inline: <<-SHELL
        /vagrant/bin/convolv worker init
      SHELL

    end
  
  end
  