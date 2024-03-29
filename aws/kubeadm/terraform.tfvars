instance_type         = "t2.micro"
ami_id                = "ami-0cf43e6df06a5fd8a"
region                = "us-west-2"
controlplane_hostname = "controlplane"
worker1_hostname      = "worker1"
worker2_hostname      = "worker2"
vpc_name              = "dev"
cidr_block            = "10.0.0.0/16"
public_subnets        = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
