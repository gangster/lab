# modules/security_group/variables.tf

variable "name" {
  description = "The name of the security group."
  type        = string
}

variable "description" {
  description = "The description of the security group."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the security group will be created."
  type        = string
}

variable "ingress_rules" {
  description = "A list of ingress rule maps, where each map contains from_port, to_port, protocol, and cidr_blocks. These define the inbound rules for the security group."
  type        = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}

variable "egress_rules" {
  description = "A list of egress rule maps, where each map contains from_port, to_port, protocol, and cidr_blocks. These define the outbound rules for the security group."
  type        = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}

variable "tags" {
  description = "A map of tags to assign to the security group resource for identification and organization."
  type        = map(string)
  default     = {}
}
