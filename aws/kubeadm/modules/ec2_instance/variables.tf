# modules/ec2_instance/variables.tf
variable "project_name" {
  description = "The name of the stack / project."
  type        = string
}
variable "instance_type" {
  description = "The type of EC2 instance to be created. Determines the CPU, memory, storage, and networking capacity."
  type        = string
}

variable "ami_id" {
  description = "The ID of the Amazon Machine Image (AMI) to use for the instance."
  type        = string
}

variable "key_name" {
  description = "The name of the key pair to attach to the EC2 instance for SSH access."
  type        = string
  nullable    = true
  default     = null  
}

variable "vpc_security_group_ids" {
  description = "A list of security group IDs to associate with the EC2 instance."
  type        = list(string)
}

variable "subnet_id" {
  description = "The ID of the subnet in which to launch the instance."
  type        = string
}

variable "user_data" {
  description = "The user data to provide when launching the instance. This is optional and can be used to run scripts or provide configuration settings at instance startup."
  type        = string
  nullable    = true
  default     = null
}

variable "iam_instance_profile" {
  description = "The IAM instance profile to attach to the instance. This is optional and allows the instance to assume an IAM role."
  type        = string
  nullable    = true
  default     = null
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IP address with the instance. If false, the instance will be assigned only a private IP address."
  type        = bool
  default     = false
}

variable "tags" {
  description = "A map of tags to assign to the EC2 instance for identification and organization."
  type        = map(string)
}
