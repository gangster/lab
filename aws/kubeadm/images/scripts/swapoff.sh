#!/bin/bash
sudo swapoff -a
sudo sed -i '/\/swap.img/s/^/#/' /etc/fstab