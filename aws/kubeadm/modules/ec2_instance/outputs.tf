output "public_ip" {
  description = "The public IP address of the EC2 instance."
  value       = aws_instance.instance.public_ip
}

output "id" {
  description = "The instance ID of the EC2 instance."
  value       = aws_instance.instance.id
}
