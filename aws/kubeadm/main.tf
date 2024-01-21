# Define the Terraform Cloud settings
terraform {
  cloud {
    organization = "josh-deeden" # Specify your Terraform Cloud organization
    workspaces {
      name = "vms" # Name of the workspace in Terraform Cloud
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.33.0" # Specify the AWS provider version
    }
  }
}

# Define the AWS region as a variable
variable "region" {
  type = string
}

# Configure the AWS provider with the specified region
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Terraform   = "true"
      Environment = "dev"
      Project     = local.project_name
    }
  }
}

# Define local variables for common tags and project name
locals {
  project_name = "k8s"
}

# Define variables for AMI ID, instance type, and hostnames
variable "ami_id" {
  description = "The Amazon Machine Image (AMI) ID to be used for launching the instances. This defines the initial software and settings of the instance."
  type        = string
}

variable "instance_type" {
  description = "The type of the instance (e.g., t2.micro, m5.large). This determines the hardware specifications like CPU, memory, etc., of the launched instances."
  type        = string
}

variable "controlplane_hostname" {
  description = "The hostname to be assigned to the control plane instance. This is used to identify the instance within the network."
  type        = string
}

variable "worker1_hostname" {
  description = "The hostname for the first worker instance in the Kubernetes cluster. It uniquely identifies the instance in the network."
  type        = string
}

variable "worker2_hostname" {
  description = "The hostname for the second worker instance in the Kubernetes cluster. It uniquely identifies the instance in the network."
  type        = string
}

# Create the VPC using the terraform-aws-modules/vpc/aws module
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false
}

# Create an AWS key pair for SSH access
resource "aws_key_pair" "node_key_pair" {
  key_name   = "node_key_pair"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGFHZwZIhmzA8BMwbJDuTBcXu82bdJk3yPIfm3QF7DAw josh@deeden.org"
}

# Create a security group for SSH access and egress rules
module "sg_allow_ssh_and_egress" {
  source      = "./modules/security_group"
  name        = "allow_ssh_and_egress"
  description = "Allow SSH inbound traffic"
  vpc_id      = module.vpc.vpc_id
  ingress_rules = [
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["10.0.1.0/24"] },   # Private subnet 1
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["10.0.2.0/24"] },   # Private subnet 2
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["10.0.3.0/24"] },   # Private subnet 3
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["10.0.101.0/24"] }, # Public subnet 1
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["10.0.102.0/24"] }, # Public subnet 2
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["10.0.103.0/24"] }  # Public subnet 3
  ]
  egress_rules = [
    { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
  ]
}

# Create a security group for Kubernetes nodes
module "sg_k8s" {
  source      = "./modules/security_group"
  name        = "k8s-security-group"
  description = "Security group for Kubernetes nodes"
  vpc_id      = module.vpc.vpc_id
  ingress_rules = [
    { from_port = 6443, to_port = 6443, protocol = "tcp", cidr_blocks = module.vpc.private_subnets_cidr_blocks },   # Kubernetes API server
    { from_port = 2379, to_port = 2380, protocol = "tcp", cidr_blocks = module.vpc.private_subnets_cidr_blocks },   # etcd server client API
    { from_port = 10250, to_port = 10250, protocol = "tcp", cidr_blocks = module.vpc.private_subnets_cidr_blocks }, # Kubelet API
    { from_port = 10255, to_port = 10255, protocol = "tcp", cidr_blocks = module.vpc.private_subnets_cidr_blocks }, # Kubelet read-only API (Optional)
    { from_port = 30000, to_port = 32767, protocol = "tcp", cidr_blocks = module.vpc.private_subnets_cidr_blocks }, # NodePort Services

    { from_port = 6443, to_port = 6443, protocol = "tcp", cidr_blocks = module.vpc.public_subnets_cidr_blocks },   # Kubernetes API server
    { from_port = 2379, to_port = 2380, protocol = "tcp", cidr_blocks = module.vpc.public_subnets_cidr_blocks },   # etcd server client API
    { from_port = 10250, to_port = 10250, protocol = "tcp", cidr_blocks = module.vpc.public_subnets_cidr_blocks }, # Kubelet API
    { from_port = 10255, to_port = 10255, protocol = "tcp", cidr_blocks = module.vpc.public_subnets_cidr_blocks }, # Kubelet read-only API (Optional)
    { from_port = 30000, to_port = 32767, protocol = "tcp", cidr_blocks = module.vpc.public_subnets_cidr_blocks }, # NodePort Services    
  ]
  egress_rules = [
    { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
  ]
}

# Create cloud-init configurations for control plane and worker instances
data "cloudinit_config" "controlplane_config" {
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content = templatefile("./cloud-init/cloud-init.cp.yaml", {
      hostname = var.controlplane_hostname
    })
  }
}

data "cloudinit_config" "worker1_config" {
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content = templatefile("./cloud-init/cloud-init.worker.yaml", {
      hostname = var.worker1_hostname
    })
  }
}

data "cloudinit_config" "worker2_config" {
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content = templatefile("./cloud-init/cloud-init.worker.yaml", {
      hostname = var.worker2_hostname
    })
  }
}

# Create an IAM role for EC2 instances
resource "aws_iam_role" "node_access_role" {
  name = "node_access_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# Attach an IAM policy for SSM access to the IAM role
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.node_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

# Create an instance profile and attach the IAM role
resource "aws_iam_instance_profile" "ec2_s3_access_profile" {
  name = "ec2_s3_access_profile"
  role = aws_iam_role.node_access_role.name
}

# Create the control plane EC2 instance
module "controlplane_instance" {
  source                      = "./modules/ec2_instance"
  project_name                = local.project_name
  ami_id                      = var.ami_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.node_key_pair.key_name
  vpc_security_group_ids      = [module.sg_allow_ssh_and_egress.id, module.sg_k8s.id]
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  user_data                   = data.cloudinit_config.controlplane_config.rendered
  iam_instance_profile        = aws_iam_instance_profile.ec2_s3_access_profile.name
  tags                        = { Name = "${local.project_name}-controlplane" }
}

# Create the worker1 EC2 instance
module "worker1_instance" {
  source                      = "./modules/ec2_instance"
  project_name                = local.project_name
  ami_id                      = var.ami_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.node_key_pair.key_name
  vpc_security_group_ids      = [module.sg_allow_ssh_and_egress.id, module.sg_k8s.id]
  subnet_id                   = module.vpc.public_subnets[1]
  associate_public_ip_address = true
  user_data                   = data.cloudinit_config.worker1_config.rendered
  iam_instance_profile        = aws_iam_instance_profile.ec2_s3_access_profile.name
  tags                        = { Name = "${local.project_name}-worker1" }
}

# Create the worker2 EC2 instance
module "worker2_instance" {
  source                      = "./modules/ec2_instance"
  project_name                = local.project_name
  ami_id                      = var.ami_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.node_key_pair.key_name
  vpc_security_group_ids      = [module.sg_allow_ssh_and_egress.id, module.sg_k8s.id]
  subnet_id                   = module.vpc.public_subnets[2]
  associate_public_ip_address = true
  user_data                   = data.cloudinit_config.worker2_config.rendered
  iam_instance_profile        = aws_iam_instance_profile.ec2_s3_access_profile.name
  tags                        = { Name = "${local.project_name}-worker2" }
}

# # Define a data source to find the latest Amazon Linux 2 AMI
# data "aws_ami" "amazon_linux" {
#   most_recent = true

#   filter {
#     name   = "name"
#     values = ["al2023-*-x86_64"]
#   }

#   filter {
#     name   = "architecture"
#     values = ["x86_64"]
#   }

#   owners = ["amazon"]
# }
