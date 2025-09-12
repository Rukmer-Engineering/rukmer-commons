output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.main.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.main.public_dns
}

output "instance_id" {
  description = "EC2 instance ID for Session Manager"
  value       = aws_instance.main.id
}

output "connect_to_instance" {
  description = "How to connect to your EC2 instance"
  value = <<-EOT
    Connect to EC2 Instance via Session Manager:

    1. Install Session Manager plugin (one-time):
       brew install --cask session-manager-plugin

    2. Connect to your instance:
       aws ssm start-session --target ${aws_instance.main.id}

    ✅ Uses your existing AWS IAM credentials
    ✅ No SSH ports open to internet
    ✅ Individual authentication & audit trails
    ✅ Works immediately - no key setup required
  EOT
}

output "authorized_users" {
  description = "IAM users authorized for SSH access"
  value = length(var.iam_ssh_users) > 0 ? var.iam_ssh_users : ["No users configured - add to iam_ssh_users variable"]
}

output "connection_command" {
  description = "Ready-to-use command to connect to your instance"
  value = "aws ssm start-session --target ${aws_instance.main.id}"
}
