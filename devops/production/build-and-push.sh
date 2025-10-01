#!/bin/bash
set -e

# Load environment variables from .env file if it exists
ENV_FILE="./production.env"
if [ -f "$ENV_FILE" ]; then
    echo "Loading environment variables from $ENV_FILE"
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        [[ $line =~ ^#.*$ ]] || [ -z "$line" ] && continue
        # Export the variable
        export "$line"
    done < "$ENV_FILE"
fi

# Configuration (use environment variables if available, otherwise use defaults)
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-771743056837}"
REGION="${REGION:-us-east-1}"
REPO_NAME="${REPO_NAME:-todo_app_server}"
DOCKER_IMAGE="${DOCKER_IMAGE:-todo-app-server}"

# Get tag name from command line argument or use timestamp
TAG_NAME=${1:-$(date +%Y%m%d%H%M%S)}

echo "Using tag: $TAG_NAME"

# Verify AWS credentials
echo "Verifying AWS credentials..."
aws sts get-caller-identity || {
    echo "ERROR: AWS credentials not configured properly"
    exit 1
}

# Ensure ECR repository exists
echo "Checking ECR repository..."
if ! aws ecr describe-repositories --repository-names $REPO_NAME --region $REGION > /dev/null 2>&1; then
    echo "Creating ECR repository: $REPO_NAME"
    aws ecr create-repository --repository-name $REPO_NAME --region $REGION
else
    echo "ECR repository already exists: $REPO_NAME"
fi

# Authenticate Docker to ECR
echo "Authenticating Docker to ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Build and tag
echo "Building Docker image..."
# Pass environment variables as build arguments if needed
docker build \
  --build-arg DATABASE_HOST="${DATABASE_HOST}" \
  --build-arg DATABASE_USERNAME="${DATABASE_USERNAME}" \
  --build-arg DATABASE_PASSWORD="${DATABASE_PASSWORD}" \
  --build-arg MYSQL_DATABASE="${MYSQL_DATABASE}" \
  --build-arg RAILS_ENV="${RAILS_ENV:-production}" \
  --build-arg SECRET_KEY_BASE="${SECRET_KEY_BASE}" \
  -t $DOCKER_IMAGE:latest ../..

echo "Tagging image..."
docker tag $DOCKER_IMAGE:latest $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:latest
docker tag $DOCKER_IMAGE:latest $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:$TAG_NAME

# Push
echo "Pushing images to ECR..."
docker push $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:$TAG_NAME

echo "Build and push completed successfully!"
echo "Images pushed:"
echo "  - $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:latest"
echo "  - $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:$TAG_NAME"