resource "aws_security_group" "sg" {
  # Basic configuration of the security group
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id

  # Dynamic block for ingress rules
  dynamic "ingress" {
    for_each = var.ingress_rules  # Iterates over each ingress rule defined in the variable
    content {
      from_port   = ingress.value.from_port   # Start port range for ingress rule
      to_port     = ingress.value.to_port     # End port range for ingress rule
      protocol    = ingress.value.protocol    # Protocol for ingress rule (e.g., tcp, udp)
      cidr_blocks = ingress.value.cidr_blocks # CIDR blocks for the ingress rule
    }
  }

  # Dynamic block for egress rules
  dynamic "egress" {
    for_each = var.egress_rules  # Iterates over each egress rule defined in the variable
    content {
      from_port   = egress.value.from_port   # Start port range for egress rule
      to_port     = egress.value.to_port     # End port range for egress rule
      protocol    = egress.value.protocol    # Protocol for egress rule (e.g., tcp, udp)
      cidr_blocks = egress.value.cidr_blocks # CIDR blocks for the egress rule
    }
  }

  # Tags assigned to the security group for identification and organization
  tags = var.tags
}
