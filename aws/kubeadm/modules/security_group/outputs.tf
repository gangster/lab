# modules/security_group/outputs.tf

output "id" {
  description = "The ID of the created security group."
  value       = aws_security_group.sg.id
}
