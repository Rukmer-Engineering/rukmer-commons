output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.main.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.main.public_dns
}

output "ssh_key_pair_name" {
  description = "Name of the SSH key pair used for the EC2 instance"
  value       = var.key_pair_name
}

output "ssh_connection_command" {
  description = "SSH command to connect to the EC2 instance"
  value       = var.key_pair_name != "" ? "ssh -i ~/.ssh/${var.key_pair_name} ec2-user@${aws_instance.main.public_ip}" : "No SSH key configured"
}

# Output the generated private key
output "ssh_private_key" {
  description = "Generated SSH private key (save this to ~/.ssh/)"
  value       = var.auto_generate_ssh_key ? tls_private_key.main[0].private_key_pem : null
  sensitive   = true
}

output "ssh_private_key_instructions" {
  description = "Instructions to save the private key"
  value = var.auto_generate_ssh_key ? "Run: terraform output -raw ssh_private_key > ~/.ssh/${var.key_pair_name} && chmod 600 ~/.ssh/${var.key_pair_name}" : "No auto-generated key"
}
