#!/bin/bash

# Update the system
yum update -y
yum install -y httpd amazon-ssm-agent docker

# Start and enable services
systemctl start httpd amazon-ssm-agent docker
systemctl enable httpd amazon-ssm-agent docker

# Add ec2-user to the docker group
usermod -a -G docker ec2-user
echo "ec2-user:100000:65536" >> /etc/subuid
echo "ec2-user:100000:65536" >> /etc/subgid

# Create index.html file to report the instance name
echo "<h1>Hello from ${instance_name}</h1>" > /var/www/html/index.html
echo "<p>Docker ready for Elixir deployment</p>" >> /var/www/html/index.html

# Install AWS CLI for ARM64
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws/

# Create deploy.sh file to deploy the app
# This file will be used to deploy the app to the EC2 instance when user runs it
cat > /home/ec2-user/deploy.sh << 'EOF'
#!/bin/bash
echo "🚀 Deploying app..."
aws ecr get-login-password --region ${region} | docker login --username AWS --password-stdin ${ecr_repo_url}
docker pull ${ecr_repo_url}:latest
docker stop app 2>/dev/null || true
docker rm app 2>/dev/null || true  
docker run -d --name app --restart unless-stopped -p 8080:4000 ${ecr_repo_url}:latest
echo "✅ Done"
EOF

chmod +x /home/ec2-user/deploy.sh
chown ec2-user:ec2-user /home/ec2-user/deploy.sh

echo "Instance setup completed at $(date)" >> /var/log/setup.log
echo "SSH-via-Session-Manager enabled" >> /var/log/setup.log
echo "Docker ready for app deployment" >> /var/log/setup.log