variable "instance_type" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "key_name" {
  type = string
}

variable "vpc_security_group_ids" {
  type = list(string)
}

variable "subnet_id" {
  type = string
}

variable "user_data" {
  type = string
  nullable = true
  default = null
}

variable "iam_instance_profile" {
  type = string
  nullable = true
  default = null
}

variable "associate_public_ip_address" {
  type = bool
  default = false
}

variable "tags" {
  type = map(string)
}
