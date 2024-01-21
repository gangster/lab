packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"                    // Specifies the minimum version requirement for the Amazon Packer plugin.
      source  = "github.com/hashicorp/amazon" // The source repository for the Amazon plugin.
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "k8s-node"  // The desired name for the generated AMI.
  instance_type = "t2.micro"  // The type of EC2 instance to be used during the AMI creation process.
  region        = "us-west-2" // Specifies the AWS region where the AMI will be built.

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*" // Selects the base Ubuntu 22.04 AMI using a naming filter.
      root-device-type    = "ebs"                                            // Indicates the root device will use Elastic Block Storage (EBS).
      virtualization-type = "hvm"                                            // Specifies Hardware Virtual Machine (HVM) virtualization type.
    }
    most_recent = true             // Chooses the latest available AMI based on the filters.
    owners      = ["099720109477"] // Filters AMIs to those owned by Canonical (official Ubuntu provider).
  }
  ssh_username   = "ubuntu" // The default username for SSH connections to the instance.
  imds_support   = "v2.0"   // Sets the Instance Metadata Service to version 2 for enhanced security.
}

build {
  name = "k8s-node" // Defines the name of this build configuration.
  sources = [
    "source.amazon-ebs.ubuntu" // Links to the source configuration defined above.
  ]

  // First shell provisioner block for initial setup.
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done", // Loop to wait for cloud-init process completion.
      "sudo rm /etc/ssh/ssh_host_*",                                                                              // Deletes SSH host keys.
      "sudo truncate -s 0 /etc/machine-id",                                                                       // Empties the machine-id file for regeneration on next boot.
      "sudo apt -y autoremove --purge",                                                                           // Removes unneeded packages and their configurations.
      "sudo apt -y clean",                                                                                        // Cleans the APT package cache.
      "sudo apt -y autoclean",                                                                                    // Removes old versions of installed packages.
      "sudo cloud-init clean",                                                                                    // Prepares cloud-init for re-run on next instance start.
      "sudo sync",                                                                                                // Flushes file system buffers to disk.
    ]
  }

  // Second shell provisioner block for executing custom scripts.
  provisioner "shell" {
    scripts = [
      "scripts/kernel-modules.sh", // Executes a script to configure kernel modules.
      "scripts/kernel-params.sh",  // Executes a script to set kernel parameters.
      "scripts/containerd.sh",     // Executes a script for installing and configuring containerd.
    ]
  }

  // File provisioner for copying hostname configuration script to the instance.
  provisioner "file" {
    source      = "scripts/hostname.sh"
    destination = "/tmp/hostname.sh"
  }

  // Shell provisioner to execute a script disabling swap.
  provisioner "shell" {
    scripts = [
      "scripts/swapoff.sh", // Runs a script to turn off swap memory.
    ]
  }

  // File provisioners for copying Kubernetes setup scripts.
  provisioner "file" {
    source      = "scripts/install-kubeadm.sh"
    destination = "/tmp/install-kubeadm.sh"
  }

  provisioner "file" {
    source      = "scripts/init-kubeadm.sh"
    destination = "/tmp/init-kubeadm.sh"
  }

  // Shell provisioner for moving scripts to a different directory.
  provisioner "shell" {
    inline = ["sudo cp /tmp/*.sh /root"] // Copies scripts from /tmp to /root directory.
  }

  // Shell provisioner block for AWS CLI v2 installation and verification.
  provisioner "shell" {
    inline = [
      "sudo apt-get install unzip -y",                                                         // Installs unzip, needed for extracting the AWS CLI package.
      "curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\"", // Downloads AWS CLI v2 package.
      "unzip awscliv2.zip",                                                                    // Extracts the AWS CLI package.
      "sudo ./aws/install",                                                                    // Installs the AWS CLI.
      "aws --version",                                                                         // Verifies the AWS CLI installation.
      "curl \"https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb\" -o \"session-manager-plugin.deb\"",
      "sudo dpkg -i session-manager-plugin.deb"                                                // Installs the AWS Session Manager Plugin.
    ]
  }
}
