#!/bin/bash

new_hostname="$HOSTNAME"

# Change the hostname
sudo echo "$new_hostname" > /etc/hostname
sudo hostnamectl set-hostname "$new_hostname"

# Update /etc/hosts
sudo sed -i "s/127\.0\.1\.1.*/127.0.1.1\t$new_hostname/" /etc/hosts

echo "Hostname changed to $new_hostname"
