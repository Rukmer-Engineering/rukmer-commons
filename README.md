# BASIC Instructions for Terraform

## What to do?

### First thing to do:
Copy the **terraform.tfvars.example** and rename it to **terraform.tfvars** and configure your local environment variables

### use this command to view S3 buckets
```bash
aws s3 ls
```

### sync the state of the existing bucket in Prod with local terraform state
```bash
 cd ./infrastructure && terraform import aws_s3_bucket.artifacts rukmer-commons-artifacts-prod
 ```

### use this command to initialize 
```bash
terraform -chdir=infrastructure init
```

### use this command to see compare the changes made from the existing cloud infrastructure
```bash
terraform -chdir=infrastructure plan
```

### use this command to apply/commit changes to aws
```bash
terraform -chdir=infrastructure apply
```

### use this command to output changes to aws
```bash
terraform -chdir=infrastructure output
```

### Install the AWS session manager 
```bash
 brew install --cask session-manager-plugin
```

### use this command to list all AWS EC2 instances in the terminal
```bash
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0],IamInstanceProfile.Arn]' --output table
```

### use the following command to import an existing instance in AWS EC2
### first, clear the old aws instance state just to be safe
### then let terraform know which main EC2 instance to save in state
### find the instance id in the EC2 instance in the AWS Console UI
### or use the following command to list all existing AWS EC2 instances
```bash
terraform state rm aws_instance.main
terraform import aws_instance.main {i-00000abcdef11111}
```
### IMPORTANT: When first creating the EC2 instance, terraform runs a user data script located in main.tf 

```bash 
#!/bin/bash
yum update -y                              # Update the system
yum install -y httpd amazon-ssm-agent      # Install web server + SSM agent
systemctl start httpd amazon-ssm-agent     # Start both services
systemctl enable httpd amazon-ssm-agent    # Enable them to start on boot
echo "<h1>Hello from ${var.instance_name}</h1>" > /var/www/html/index.html
echo "Instance setup completed at $(date)" >> /var/log/setup.log
echo "SSH-via-Session-Manager enabled" >> /var/log/setup.log
```
# What This Script Does:
* Updates the system (can take 5-15 minutes)
* Installs the SSM agent (amazon-ssm-agent package)
* Starts the SSM agent (systemctl start amazon-ssm-agent)
* Enables it to auto-start on future reboots

Please note that it might take up to 5-15 minutes, before user can ssh into the EC2 via Session Manager, as descibed in the step above


### use this command to ssh into the EC2 via Session Manager
```bash
aws ssm start-session --target {i-00000abcdef11111}
```
