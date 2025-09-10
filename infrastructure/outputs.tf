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

output "ssh_via_session_manager_setup" {
  description = "Simple setup instructions for SSH via Session Manager"
  value = <<-EOT
    SSH via Session Manager Setup (one-time per user):

    1. Install Session Manager plugin:
       brew install --cask session-manager-plugin

    2. Add to ~/.ssh/config:
       Host i-* mi-*
           ProxyCommand sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
           User ec2-user

    3. Generate SSH key:
       ssh-keygen -t rsa -b 4096 -f ~/.ssh/session-manager-key

    4. Connect:
       ssh -i ~/.ssh/session-manager-key ec2-user@${aws_instance.main.id}

    ✅ Uses your existing AWS IAM credentials
    ✅ No SSH ports open to internet
    ✅ Individual authentication & audit trails
  EOT
}

output "authorized_users" {
  description = "IAM users authorized for SSH access"
  value = length(var.iam_ssh_users) > 0 ? var.iam_ssh_users : ["No users configured - add to iam_ssh_users variable"]
}
