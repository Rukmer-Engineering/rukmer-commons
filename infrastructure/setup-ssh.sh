#!/bin/bash

# Automated SSH key setup script for Terraform
# This script will generate SSH keys, apply Terraform, and save the private key locally

set -e

KEY_NAME="${1:-rukmer-commons-ec2-key}"
echo "🔑 Setting up SSH key automation for: $KEY_NAME"

# Update terraform.tfvars to enable auto-generation
echo "📝 Configuring terraform.tfvars..."
cp terraform.tfvars.example terraform.tfvars
sed -i '' "s/auto_generate_ssh_key = true/auto_generate_ssh_key = true/" terraform.tfvars
sed -i '' "s/key_pair_name = \".*\"/key_pair_name = \"$KEY_NAME\"/" terraform.tfvars

echo "✅ Updated terraform.tfvars to auto-generate key pair"

# Initialize and apply Terraform
echo "🚀 Running Terraform..."
terraform init
terraform plan
terraform apply -auto-approve

echo "✅ Terraform applied successfully"

# Extract and save the private key
echo "🔐 Saving private key locally..."
mkdir -p ~/.ssh
terraform output -raw ssh_private_key > ~/.ssh/"$KEY_NAME"
chmod 600 ~/.ssh/"$KEY_NAME"

echo "✅ Private key saved to: ~/.ssh/$KEY_NAME"

# Display connection info
echo ""
echo "🎉 SSH key setup complete!"
echo ""
echo "📋 Summary:"
echo "   - Key pair name: $KEY_NAME"
echo "   - Private key: ~/.ssh/$KEY_NAME"
echo "   - EC2 Public IP: $(terraform output -raw ec2_public_ip)"
echo ""
echo "🔧 Connect to your EC2 instance:"
echo "   $(terraform output -raw ssh_connection_command)"
echo ""
echo "🧪 Test the connection:"
echo "   ssh -i ~/.ssh/$KEY_NAME ec2-user@$(terraform output -raw ec2_public_ip)"
