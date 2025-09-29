# HTTPS Upgrade Guide

## Current Setup: HTTP-Only ALB

Your infrastructure currently uses:
- Application Load Balancer (ALB) with HTTP on port 80
- EC2 instance in public subnet accessible only via ALB
- No SSL certificate or domain required

**Access your app:** `http://[ALB-DNS-NAME]/`

## Adding HTTPS When You Get a Domain

### Step 1: Domain Prerequisites

You'll need:
- A registered domain name (e.g., `yourdomain.com`)
- Domain managed in AWS Route53 with a hosted zone

**Set up Route53 (if not already done):**
```bash
# Create hosted zone in AWS Console or via CLI
aws route53 create-hosted-zone --name yourdomain.com --caller-reference $(date +%s)
```

### Step 2: Update Terraform Configuration

Add these variables to your `terraform.tfvars`:
```hcl
# Add these lines to infrastructure/terraform.tfvars
domain_name = "api.yourdomain.com"           # Your API subdomain
route53_zone_id = "Z1234567890ABC"           # Your Route53 hosted zone ID
```

**Find your Zone ID:**
```bash
aws route53 list-hosted-zones --query 'HostedZones[?Name==`yourdomain.com.`].Id' --output text
```

### Step 3: Deploy HTTPS

```bash
cd infrastructure
terraform plan    # Review the changes
terraform apply   # Deploy HTTPS
```

## What Terraform Will Add

When you add a domain, these resources are automatically created:

**Note:** ALB and security groups are already configured and ready for HTTPS - only SSL certificate resources need to be added.

### SSL Certificate Resources
```hcl
# Free SSL certificate from AWS Certificate Manager
resource "aws_acm_certificate" "main"

# DNS validation records (proves you own the domain)  
resource "aws_route53_record" "validation"

# Certificate validation process
resource "aws_acm_certificate_validation" "main"
```

### Updated ALB Listeners
```hcl
# New HTTPS listener on port 443
resource "aws_lb_listener" "https"

# HTTP listener updated to redirect to HTTPS
resource "aws_lb_listener" "http" {
  # Changes from "forward" to "redirect"
}
```

### Security Group Updates
```hcl
# ALB security group already has HTTPS port configured
resource "aws_security_group" "alb_sg" {
  ingress {
    from_port = 443  # HTTPS port (already configured)
  }
}
```

## After HTTPS Deployment

**Your app will be accessible at:**
- `https://api.yourdomain.com/` (primary)
- `http://api.yourdomain.com/` (redirects to HTTPS)
- Old ALB DNS name will still work but redirect to HTTPS

**DNS Setup:**
Add a CNAME record pointing your subdomain to the ALB:
```
api.yourdomain.com  CNAME  your-alb-dns-name.elb.amazonaws.com
```

## What You CAN'T Destroy

These resources are required for HTTPS and should **never** be destroyed:

### Critical HTTPS Resources
- `aws_acm_certificate.main` - Your SSL certificate
- `aws_acm_certificate_validation.main` - Certificate validation
- `aws_route53_record.validation` - Domain validation records
- `aws_lb_listener.https` - HTTPS traffic handler

### Core Infrastructure
- `aws_lb.main` - Application Load Balancer
- `aws_lb_target_group.main` - Routes traffic to EC2
- `aws_security_group.alb_sg` - ALB security rules

## What You CAN Destroy (If Needed)

### Development/Testing Resources
```bash
# Remove test endpoints (keep core app)
# Modify hello_world.ex to remove /db/test routes

# Scale down during off-hours
terraform apply -var="instance_type=t4g.nano"  # Smaller instance
```

### Database Resources (Data Loss Warning!)
```bash
# Only if you want to start over with database
terraform destroy -target=aws_db_instance.main
terraform destroy -target=aws_db_parameter_group.main
# This DELETES all your data!
```

### Storage Resources
```bash
# Remove S3 bucket (if not needed)
terraform destroy -target=aws_s3_bucket.artifacts

# Remove ECR repository (loses Docker images)
terraform destroy -target=aws_ecr_repository.rukmer_app
```

## Cost Optimization

### Current Monthly Costs (~$35-50)
- ALB: ~$20/month
- EC2 t4g.medium: ~$15/month  
- RDS t3.micro: ~$15/month (free tier eligible)
- Data transfer: ~$5/month

### Cost Reduction Options
```hcl
# Use smaller instances
instance_type = "t4g.small"     # Save ~$8/month
db_instance_class = "db.t3.micro"  # Free tier

# Remove ALB and use EC2 directly (not recommended for production)
# Saves $20/month but loses HTTPS, security, and scalability
```

## Rollback Process

If you need to remove HTTPS and go back to HTTP-only:

```bash
# 1. Remove domain from terraform.tfvars
domain_name = ""
route53_zone_id = ""

# 2. Apply changes
terraform apply

# 3. HTTPS resources will be destroyed automatically
# 4. HTTP traffic will resume on port 80
```

## Testing After HTTPS Setup

```bash
# Test HTTPS
curl https://api.yourdomain.com/health

# Test HTTP redirect
curl -v http://api.yourdomain.com/health
# Should return 301 redirect to HTTPS

# Test database
curl https://api.yourdomain.com/db/test
curl -X POST https://api.yourdomain.com/db/create-test-table
```

## Troubleshooting

### Certificate Validation Stuck
- Check that your domain's nameservers point to Route53
- Validation can take 5-20 minutes
- DNS propagation may take up to 48 hours globally

### HTTPS Not Working
- Verify ALB security group allows port 443
- Check certificate status in AWS Console
- Ensure domain CNAME points to ALB DNS name

### Cost Alerts
- Set up AWS billing alerts for $50/month threshold
- Monitor CloudWatch metrics for resource usage
- Review monthly AWS cost reports

---

**Questions?** Check the Terraform plan output before applying any changes.
