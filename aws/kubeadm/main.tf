terraform {
  cloud {
    organization = "josh-deeden"

    workspaces {
      name = "vms"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.33.0"
    }
  }
}

variable "region" {
  type = string
}

provider "aws" {
  region = var.region
}

locals {
  project_name = "k8s"
  common_tags = {
    Terraform   = "true"
    Environment = "dev"
    Project     = local.project_name
  }
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "controlplane_hostname" {
  type = string
}

variable "worker1_hostname" {
  type = string
}


variable "worker2_hostname" {
  type = string
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_key_pair" "node_key_pair" {
  key_name   = "node_key_pair"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGFHZwZIhmzA8BMwbJDuTBcXu82bdJk3yPIfm3QF7DAw josh@deeden.org"
}

# Inbound rule for SSH
module "sg_allow_ssh_and_egress" {
  source      = "./modules/security_group"
  name        = "allow_ssh_and_egress"
  description = "Allow SSH inbound traffic"
  vpc_id      = module.vpc.vpc_id
  ingress_rules = [
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["10.0.1.0/24"] },   // Private subnet 1
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["10.0.2.0/24"] },   // Private subnet 2
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["10.0.3.0/24"] },   // Private subnet 3
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["10.0.101.0/24"] }, // Public subnet 1
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["10.0.102.0/24"] }, // Public subnet 2
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["10.0.103.0/24"] }  // Public subnet 3
  ]
  egress_rules = [
    { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
  ]
  tags = local.common_tags
}

module "sg_k8s" {
  source      = "./modules/security_group"
  name        = "k8s-security-group"
  description = "Security group for Kubernetes nodes"
  vpc_id      = module.vpc.vpc_id
  ingress_rules = [
    { from_port = 6443, to_port = 6443, protocol = "tcp", cidr_blocks = module.vpc.private_subnets_cidr_blocks },   // Kubernetes API server
    { from_port = 2379, to_port = 2380, protocol = "tcp", cidr_blocks = module.vpc.private_subnets_cidr_blocks },   // etcd server client API
    { from_port = 10250, to_port = 10250, protocol = "tcp", cidr_blocks = module.vpc.private_subnets_cidr_blocks }, // Kubelet API
    { from_port = 10255, to_port = 10255, protocol = "tcp", cidr_blocks = module.vpc.private_subnets_cidr_blocks }, // Kubelet read-only API (Optional)
    { from_port = 30000, to_port = 32767, protocol = "tcp", cidr_blocks = module.vpc.private_subnets_cidr_blocks }, // NodePort Services

    { from_port = 6443, to_port = 6443, protocol = "tcp", cidr_blocks = module.vpc.public_subnets_cidr_blocks },   // Kubernetes API server
    { from_port = 2379, to_port = 2380, protocol = "tcp", cidr_blocks = module.vpc.public_subnets_cidr_blocks },   // etcd server client API
    { from_port = 10250, to_port = 10250, protocol = "tcp", cidr_blocks = module.vpc.public_subnets_cidr_blocks }, // Kubelet API
    { from_port = 10255, to_port = 10255, protocol = "tcp", cidr_blocks = module.vpc.public_subnets_cidr_blocks }, // Kubelet read-only API (Optional)
    { from_port = 30000, to_port = 32767, protocol = "tcp", cidr_blocks = module.vpc.public_subnets_cidr_blocks }, // NodePort Services    
  ]
  egress_rules = [
    { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
  ]
  tags = {
    "Name" = "k8s-security-group"
    // Other tags
  }
}


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

# IAM Role for EC2 instances
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

# Attach a predefined AWS policy for S3 Read-Only access
# resource "aws_iam_role_policy_attachment" "s3_read_only_access" {
#   role       = aws_iam_role.node_access_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
# }

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.node_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}
# Instance Profile to attach the role to EC2 instances
resource "aws_iam_instance_profile" "ec2_s3_access_profile" {
  name = "ec2_s3_access_profile"
  role = aws_iam_role.node_access_role.name
}

module "controlplane_instance" {
  source                      = "./modules/ec2_instance"
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

module "worker1_instance" {
  source                      = "./modules/ec2_instance"
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

module "worker2_instance" {
  source                      = "./modules/ec2_instance"
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

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  owners = ["amazon"]
}
