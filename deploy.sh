#!/bin/bash

# Mental Health IoT Project Deployment Script
# This script builds and deploys the complete infrastructure using Terraform

set -e  # Exit on any error

PROJECT_NAME="mental-health-iot"
AWS_REGION="us-east-1"
ENVIRONMENT="dev"

echo "🚀 Starting deployment of Mental Health IoT Analysis Platform..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Python is installed
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_status "All prerequisites satisfied ✅"
}

# Build TypeScript Lambda
build_typescript_lambda() {
    print_status "Building TypeScript Lambda function..."
    
    cd ts-lambda
    
    # Install dependencies
    npm install
    
    # Compile TypeScript
    npx tsc
    
    # Create deployment package
    zip -r ../ts-lambda.zip . -x "*.ts" "tsconfig.json" "node_modules/@types/*" "*.log"
    
    cd ..
    
    print_status "TypeScript Lambda built successfully ✅"
}

# Build Python Lambda
build_python_lambda() {
    print_status "Building Python Lambda function..."
    
    mkdir -p py-lambda-build
    cp py-lambda/app.py py-lambda-build/
    cp py-lambda/requirements.txt py-lambda-build/
    
    cd py-lambda-build
    
    # Install dependencies in the build directory
    pip3 install -r requirements.txt -t .
    
    # Create deployment package
    zip -r ../py-lambda.zip .
    
    cd ..
    rm -rf py-lambda-build
    
    print_status "Python Lambda built successfully ✅"
}

# Build Mental Insights Lambda
build_mental_insights_lambda() {
    print_status "Building Mental Insights Lambda function..."
    
    mkdir -p mental-insights-build
    
    # Create package.json for the Lambda
    cat > mental-insights-build/package.json << EOF
{
  "name": "mental-insights-lambda",
  "version": "1.0.0",
  "main": "mental_insights.js",
  "dependencies": {
    "aws-sdk": "^2.1490.0"
  }
}
EOF
    
    # Copy the mental insights function
    cp mental_insights.js mental-insights-build/
    
    cd mental-insights-build
    
    # Install dependencies
    npm install --production
    
    # Create deployment package
    zip -r ../mental-insights-lambda.zip .
    
    cd ..
    rm -rf mental-insights-build
    
    print_status "Mental Insights Lambda built successfully ✅"
}

# Initialize and deploy Terraform
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    # Initialize Terraform
    terraform init
    
    # Validate Terraform configuration
    terraform validate
    
    # Plan the deployment
    print_status "Creating Terraform execution plan..."
    terraform plan \
        -var="aws_region=$AWS_REGION" \
        -var="environment=$ENVIRONMENT" \
        -var="project_name=$PROJECT_NAME" \
        -out=tfplan
    
    # Apply the deployment
    print_status "Applying Terraform configuration..."
    terraform apply tfplan
    
    print_status "Infrastructure deployed successfully ✅"
}

# Get deployment outputs
get_outputs() {
    print_status "Retrieving deployment information..."
    
    API_URL=$(terraform output -raw api_gateway_url)
    USER_EVENTS_TABLE=$(terraform output -raw dynamodb_user_events_table)
    INSIGHTS_TABLE=$(terraform output -raw dynamodb_insights_table)
    
    echo ""
    echo "🎉 Deployment completed successfully!"
    echo ""
    echo "📊 API Endpoints:"
    echo "   Main API: $API_URL"
    echo "   Mental Insights: $API_URL/mental-insights"
    echo "   Daily Insights: $API_URL/daily-insights"
    echo "   Create User (TS): $API_URL/user"
    echo "   Create User (Python): $API_URL/user-python"
    echo ""
    echo "🗄️  DynamoDB Tables:"
    echo "   User Events: $USER_EVENTS_TABLE"
    echo "   Mental Health Insights: $INSIGHTS_TABLE"
    echo ""
    echo "🧪 Test the API:"
    echo "   curl $API_URL/mental-insights"
    echo ""
    echo "   curl -X POST $API_URL/user \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"id\":\"test-123\",\"name\":\"Test User\"}'"
    echo ""
}

# Test the deployment
test_deployment() {
    print_status "Testing deployment..."
    
    API_URL=$(terraform output -raw api_gateway_url)
    
    # Test mental insights endpoint
    print_status "Testing mental insights endpoint..."
    RESPONSE=$(curl -s "$API_URL/mental-insights")
    
    if echo "$RESPONSE" | grep -q "top_stress_features"; then
        print_status "Mental insights endpoint working ✅"
    else
        print_warning "Mental insights endpoint test failed"
        echo "Response: $RESPONSE"
    fi
}

# Main execution
main() {
    echo "🏥 Mental Health IoT Analysis Platform Deployment"
    echo "=================================================="
    echo ""
    
    check_prerequisites
    
    print_status "Building Lambda functions..."
    build_typescript_lambda
    build_python_lambda
    build_mental_insights_lambda
    
    deploy_infrastructure
    
    get_outputs
    
    # Wait a moment for API Gateway to be ready
    print_status "Waiting for API Gateway to be ready..."
    sleep 30
    
    test_deployment
    
    echo ""
    print_status "🎉 Deployment completed successfully!"
}

# Cleanup function
cleanup() {
    print_status "Cleaning up build artifacts..."
    rm -f ts-lambda.zip py-lambda.zip mental-insights-lambda.zip tfplan
    rm -f mental_insights.js
}

# Handle script interruption
trap cleanup EXIT

# Run main function
main "$@"