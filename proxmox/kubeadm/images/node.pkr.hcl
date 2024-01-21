# Ubuntu Server jammy
# ---
# This Packer template is used to create an Ubuntu Server (Jammy version) virtual machine on Proxmox VE.

# Declaration of variables for Proxmox API access and VM configuration
variable "proxmox_api_url" { 
    type = string  # URL for the Proxmox API
}

variable "proxmox_api_token_id" { 
    type = string  # Token ID for Proxmox API authentication
}

variable "proxmox_api_token_secret" { 
    type = string
    sensitive = true  # Secret for Proxmox API token (marked as sensitive)
}

variable "vm_name" {  
    type = string
    validation {
        condition     = length(var.vm_name) > 0  # Ensures a non-empty vm name
        error_message = "The vm_name length must be > 0."
    }  
}

# Network configuration variables for the VM
variable "vm_ip" {  
    type = string
    validation {
        condition     = length(var.vm_ip) > 0 && length(var.vm_ip) < 16  # Ensures a valid IPv4 address format
        error_message = "The vm_ip value must be a valid IPv4 address."
    }  
}

# Additional network settings with validation for proper IPv4 formatting
variable "vm_netmask" { 
    type = string
    validation {
        condition     = length(var.vm_netmask) > 0 && length(var.vm_netmask) < 16
        error_message = "The vm_netmask value must be a valid IPv4 address."
    }
}

variable "vm_gateway" { 
    type = string
    validation {
        condition     = length(var.vm_gateway) > 0 && length(var.vm_gateway) < 16
        error_message = "The vm_gateway value must be a valid IPv4 address."
    }
}

variable "vm_dns" { 
    type = string
    validation {
        condition     = length(var.vm_dns) > 0 && length(var.vm_dns) < 16
        error_message = "The vm_dns value must be a valid IPv4 address."
    }
}

# Proxmox VM resource definition
source "proxmox" "node" {
    # Connection settings for Proxmox VE
    proxmox_url = "${var.proxmox_api_url}"
    username = "${var.proxmox_api_token_id}"
    token = "${var.proxmox_api_token_secret}"
    insecure_skip_tls_verify = true  # Skips TLS verification, use with caution
    
    # Basic VM settings (node, ID, name, description)
    node = "pve"
    vm_id = "9000"
    vm_name = "${var.vm_name}"
    template_description = "Ubuntu Server jammy Image"

    # VM OS configuration using a local ISO file
    iso_file = "local:iso/ubuntu-22.04.3-live-server-amd64.iso"
    iso_storage_pool = "local"
    unmount_iso = true  # Specifies to unmount the ISO after installation

    # System, hardware, and performance settings for the VM
    qemu_agent = true
    scsi_controller = "virtio-scsi-pci"
    disks {  # Hard disk configuration
        disk_size = "64G"
        format = "raw"
        storage_pool = "local-lvm"
        storage_pool_type = "lvm"
        type = "virtio"
    }
    cores = "4"  # CPU core allocation
    memory = "4096"  # RAM allocation in MB

    # Network adapter configuration
    network_adapters {
        model = "virtio"
        bridge = "vmbr0"
        firewall = "true"
    }

    # Cloud-Init settings for VM initialization
    cloud_init = true
    cloud_init_storage_pool = "local-lvm"

    # Boot and installation automation commands
    boot_command = [
        # Automated keystrokes to configure network settings and start the installer
        "<e><bs><down><down><down>",
        "<right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right>",
        "<spacebar>",
        // "ip=${ var.vm_ip }::${ var.vm_gateway }:${ var.vm_netmask }::::${ var.vm_dns } ",
        "autoinstall 'ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/' ",
        "<F10>"
    ]    
    boot = "c"
    boot_wait = "5s"

    # Additional settings for automated installation via HTTP server
    http_directory = "http" 

    # SSH settings for accessing the VM after installation
    ssh_username = "lab"
    ssh_private_key_file = "~/.ssh/cluster_key"
    ssh_timeout = "20m"
}

# Definition of the build process
build {
    name = "node"
    sources = ["proxmox-iso.proxmox.node"]

    # Shell provisioners for preparing the VM for Cloud-Init and general cleanup
    # These scripts ensure the VM is clean and ready for deployment as a template
    provisioner "shell" {
        inline = [
            "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
            "sudo apt-get update && sudo apt-get upgrade -y"
            "sudo rm /etc/ssh/ssh_host_*",
            "sudo truncate -s 0 /etc/machine-id",
            "sudo apt -y autoremove --purge",
            "sudo apt -y clean",
            "sudo apt -y autoclean",
            "sudo cloud-init clean",
            "sudo sync"
        ]
    }

    provisioner "file" {
        source = "files/99-pve.cfg"
        destination = "/tmp/99-pve.cfg"
    }  

    provisioner "shell" {
        inline = [ "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg" ]
    }

    provisioner "shell" {
        environment_vars = [
            "HOSTNAME=${var.vm_name}"
        ]
        scripts = [
            "files/kernel-modules.sh",
            "files/kernel-params.sh",
            "files/containerd.sh",
        ]
    }

    provisioner "file" {
        source = "files/hostname.sh"
        destination = "/tmp/hostname.sh"
    }

   # Disable swap
    provisioner "shell" {
        scripts = [ 
            "files/swapoff.sh",
        ]
    }

    provisioner "file" {
        source = "files/kubeadm.sh"
        destination = "/tmp/kubeadm.sh"
    }

    provisioner "shell" {
        inline = [ "sudo cp /tmp/*.sh /root" ]
    }   
}
