#!/bin/bash
set -e

# Load env file
ENV_FILE="./.production.env"
echo "ENV FILE: $ENV_FILE"
if [ -f "$ENV_FILE" ]; then
    echo "Loading environment variables from $ENV_FILE"
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        [[ $line =~ ^#.*$ ]] || [ -z "$line" ] && continue
        # Export the variable
        export "$line"
    done < "$ENV_FILE"
fi

# Convert comma separated values into arrays
IFS=',' read -r -a TASK_DEFS <<< "$TASK_DEF_FAMILIES"
IFS=',' read -r -a SERVICE_NAMES <<< "$SERVICES"
ECR_REPO="$AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME"
IMAGE_TAG=$(date +%Y%m%d%H%M)   # timestamp as version
NEW_IMAGE="$ECR_REPO:$IMAGE_TAG"

echo ">>> Building Docker image..."
docker build -t $ECR_REPO:latest ../..

echo ">>> Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REPO

echo ">>> Tagging and pushing image..."
docker tag $ECR_REPO:latest $NEW_IMAGE
docker push $NEW_IMAGE

echo "TASK DEF FAMILIES: $TASK_DEFS"
# Loop through each task definition family
for TASK_DEF_FAMILY in "${TASK_DEFS[@]}"; do
  echo ">>> Processing task definition: $TASK_DEF_FAMILY"

  # Fetch current task definition JSON
  TASK_DEF_JSON=$(aws ecs describe-task-definition \
    --task-definition $TASK_DEF_FAMILY \
    --query "taskDefinition" \
    --region $REGION \
    --output json > task_def.json)

    echo ">>> Current task definition JSON fetched."
    echo "$TASK_DEF_JSON" | jq '.'   # Pretty-print the JSON for debugging

    jq --arg IMAGE "$NEW_IMAGE" '
    .containerDefinitions |= map(.image = $IMAGE)
    | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)
    ' task_def.json > task_def_new.json


  # Replace image for each container in the task definition
  echo ">>> Updating container images to $NEW_IMAGE..."
  NEW_TASK_DEF=$(echo $TASK_DEF_JSON | jq --arg IMAGE "$NEW_IMAGE" '
    .containerDefinitions |= map(.image = $IMAGE)
    | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)
  ')
  echo ">>> Updating container images completed."

  echo ">>> Registering new task definition revision..."
  # Register new revision
NEW_REVISION=$(jq -c . <<< "$NEW_TASK_DEF" | \
  aws ecs register-task-definition \
    --cli-input-json file:///dev/stdin \
    --query "taskDefinition.revision" \
    --region $REGION)

  echo ">>> Registered $TASK_DEF_FAMILY revision: $NEW_REVISION"

  # Update all services with this task definition
  for SERVICE in "${SERVICE_NAMES[@]}"; do
    echo ">>> Updating service $SERVICE with $TASK_DEF_FAMILY..."
    aws ecs update-service \
      --cluster $CLUSTER_NAME \
      --service $SERVICE \
      --task-definition $TASK_DEF_FAMILY \
      --region $REGION \
      --force-new-deployment
  done
done

echo ">>> All task definitions and services updated successfully!"
