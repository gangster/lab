output "controlplane_public_ip" {
  description = "The public IP address of the control plane instance."
  value       = module.controlplane_instance.public_ip
}

output "controlplane_instance_id" {
  description = "The id of the control plane instance."
  value       = module.controlplane_instance.id
}

output "worker1_public_ip" {
  description = "The public IP address of the first worker instance."
  value       = module.worker1_instance.public_ip
}

output "worker1_instance" {
  description = "The id address of the first worker instance."
  value       = module.worker1_instance.id
}

output "worker2_public_ip" {
  description = "The id address of the second worker instance."
  value       = module.worker2_instance.public_ip
}

output "worker2_instance_id" {
  description = "The public IP address of the second worker instance."
  value       = module.worker2_instance.id
}

# output "bastion_public_ip" {
#   description = "The public IP address of the second worker instance."
#   value       = module.bastion_instance.public_ip
# }
