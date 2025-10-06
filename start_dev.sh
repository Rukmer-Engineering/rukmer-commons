#!/bin/bash

# Rukmer Commons - Local Development Startup Script
# This script sets up environment variables from Terraform and starts Phoenix

set -e  # Exit on any error

echo "🚀 Rukmer Commons - Local Development Setup"
echo "============================================="
echo ""

# Get the script directory (project root)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# ---------------------------------------------
# Step 1: Check AWS CLI Installation
# ---------------------------------------------
echo "📋 Step 1: Checking AWS CLI installation..."

if ! command -v aws &> /dev/null; then
    echo "   ❌ AWS CLI is not installed."
    echo ""
    echo "   Please install it manually:"
    echo "      macOS:   brew install awscli"
    echo "      Linux:   https://aws.amazon.com/cli/"
    echo "      Windows: https://aws.amazon.com/cli/"
    echo ""
    exit 1
fi

echo "   ✅ AWS CLI installed"
echo ""

# ---------------------------------------------
# Step 2: Check AWS Credentials File
# ---------------------------------------------
echo "📋 Step 2: Checking AWS credentials..."

if [ ! -f "$HOME/.aws/credentials" ]; then
    echo "   ❌ AWS credentials file not found at ~/.aws/credentials"
    echo ""
    echo "   Please set up your AWS credentials:"
    echo "      Run: aws configure"
    echo ""
    echo "   You'll need:"
    echo "      - AWS Access Key ID (aws_access_key_id)"
    echo "      - AWS Secret Access Key (aws_secret_access_key)"
    echo "      - Default region (e.g., us-west-2)"
    echo ""
    exit 1
fi

echo "   ✅ AWS credentials file found"
echo ""

# ---------------------------------------------
# Step 3: Verify and Confirm IAM Identity
# ---------------------------------------------
echo "📋 Step 3: Verifying IAM identity..."

if ! aws sts get-caller-identity &> /dev/null; then
    echo "   ❌ Unable to verify AWS credentials"
    echo "   Please check your AWS configuration and try again"
    exit 1
fi

# Display current IAM identity
echo ""
echo "   Current IAM Identity:"
aws sts get-caller-identity | sed 's/^/   /'
echo ""

read -p "   Do you want to proceed with these IAM credentials? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "   Setup cancelled by user"
    exit 0
fi

echo "   ✅ IAM credentials confirmed"
echo ""

# ---------------------------------------------
# Step 4: Check Terraform Installation
# ---------------------------------------------
echo "📋 Step 4: Checking Terraform installation..."

if ! terraform version &> /dev/null; then
    echo "   ❌ Terraform is not installed."
    echo ""
    echo "   Please install it manually:"
    echo "      macOS:   brew install terraform"
    echo "      Linux/Windows: https://www.terraform.io/downloads"
    echo ""
    exit 1
fi

echo "   ✅ Terraform installed"
echo ""

# ---------------------------------------------
# Step 5: Sync Terraform State from Cloud
# ---------------------------------------------
echo "📋 Step 5: Syncing Terraform state from cloud..."

cd "$SCRIPT_DIR/infrastructure"

# Check if Terraform Cloud credentials exist
TERRAFORM_CREDS="$HOME/.terraform.d/credentials.tfrc.json"

if [ -f "$TERRAFORM_CREDS" ]; then
    echo "   ✅ Terraform credentials found"
    echo "   Verifying credentials are still valid..."
    
    # Try to access Terraform Cloud to verify credentials work
    if terraform workspace list &> /dev/null; then
        echo "   ✅ Terraform Cloud credentials are valid"
    else
        echo "   ⚠️  Terraform Cloud credentials expired or invalid"
        echo "   Please login again..."
        terraform login
    fi
else
    echo "   ⚠️  No Terraform Cloud credentials found"
    echo "   Logging into Terraform Cloud..."
    terraform login
fi

echo ""
read -p "   Do you want to run 'terraform refresh' to sync with remote state? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "   Running terraform refresh to sync remote state..."
    terraform refresh
    echo "   ✅ Terraform state synced with remote"
else
    echo "   ⚠️  Skipping terraform refresh - using existing local state"
fi

echo ""

# ---------------------------------------------
# Step 6: Display Current Terraform State
# ---------------------------------------------
echo "📋 Step 6: Current Terraform infrastructure state:"
echo ""
terraform output | sed 's/^/   /'
echo ""

# ---------------------------------------------
# Step 7: Load Environment Variables
# ---------------------------------------------
echo "📋 Step 7: Loading environment variables from Terraform..."

# Export the variables from Terraform output
eval "$(terraform output -raw phoenix_env_vars | grep export)"

echo "   ✅ Environment variables loaded:"
echo "      - SECRET_KEY_BASE: ${SECRET_KEY_BASE:0:20}..."
echo "      - SIGNING_SALT: ${SIGNING_SALT:0:20}..."
echo "      - COGNITO_USER_POOL_ID: $COGNITO_USER_POOL_ID"
echo "      - COGNITO_CLIENT_ID: ${COGNITO_CLIENT_ID:0:20}..."
echo "      - AWS_REGION: $AWS_REGION"
echo ""

# ---------------------------------------------
# Step 8: Install Dependencies
# ---------------------------------------------
cd "$SCRIPT_DIR/src/marketplace-api"

echo "📋 Step 8: Installing/updating Phoenix dependencies..."

echo "   Running mix deps.get..."
mix deps.get 2>&1 | sed 's/^/   /'
echo ""

if [ ! -d "lib/marketplace_api_web/components/layouts" ]; then
    echo "   Running SaladUI initialization..."
    mix salad.init 2>&1 | sed 's/^/   /'
    echo ""
fi

echo "   ✅ Dependencies ready"
echo ""

# ---------------------------------------------
# Step 9: Start Phoenix Server
# ---------------------------------------------
echo "🎉 Starting Phoenix server..."
echo "============================================="
echo ""
echo "Visit: http://localhost:4000"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

mix phx.server

