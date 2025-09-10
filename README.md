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

### use this command after terraform apply
```bash
# Setup SSH via Session Manager (one-time per user)
terraform -chdir=infrastructure output ssh_via_session_manager_setup

# Connect using SSH through Session Manager
ssh -i ~/.ssh/session-manager-key ec2-user@$(terraform -chdir=infrastructure output -raw instance_id)
```