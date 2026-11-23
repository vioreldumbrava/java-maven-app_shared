#!/usr/bin/env bash
# Deploy the Django app + PostgreSQL to EC2.
#
# Runs on the Jenkins agent (called from the Jenkinsfile "deploy" stage, inside
# sshagent, which provides the SSH key). It copies the files EC2 needs and starts
# server-cmds.sh there, which does the actual deploy, health check and rollback.
#
# It can also be run by hand:
#   export POSTGRES_PASSWORD=... AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_REGION=eu-north-1
#   export ECR_REGISTRY=177203142220.dkr.ecr.eu-north-1.amazonaws.com
#   bash deploy.sh ec2-user@16.171.230.252 "$ECR_REGISTRY/my-app:django-v1.5"
#
# The password comes from the environment, not from an argument, so it never
# shows up in the process list or the Jenkins log.
#
# shellcheck disable=SC2029  # variables are meant to expand here, before ssh sends the command
set -euo pipefail

SSH_TARGET="${1:?usage: deploy.sh <user@host> <image>}"
IMAGE_NAME="${2:?usage: deploy.sh <user@host> <image>}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD must be set in the environment}"
# Folder on EC2 that holds docker-compose.yaml, server-cmds.sh and .env
DEPLOY_DIR="${DEPLOY_DIR:-django-app}"
SSH_OPTS=(-o StrictHostKeyChecking=no)

echo "Deploying $IMAGE_NAME to $SSH_TARGET:~/$DEPLOY_DIR"

# 1. Copy the compose file and the server script to EC2
ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "mkdir -p ~/$DEPLOY_DIR"
scp "${SSH_OPTS[@]}" docker-compose.yaml server-cmds.sh "$SSH_TARGET:~/$DEPLOY_DIR/"

# 2. Log EC2's Docker in to Amazon ECR, so docker-compose can pull the private image.
#    Jenkins gets a token (valid 12 h) with its AWS key and sends only the token through
#    stdin, so EC2 needs no AWS key and no IAM role. Skipped when ECR_REGISTRY is not set.
if [ -n "${ECR_REGISTRY:-}" ]; then
    : "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID must be set for ECR}"
    : "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY must be set for ECR}"
    echo "Logging EC2 in to $ECR_REGISTRY"
    docker run --rm -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY "${AWS_CLI:-amazon/aws-cli:2.38.0}" \
        ecr get-login-password --region "${AWS_REGION:?AWS_REGION must be set for ECR}" \
        | ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "docker login --username AWS --password-stdin '$ECR_REGISTRY'"
fi

# 3. Run the server script on EC2. The password goes through stdin.
#    Its exit code becomes ours, so a failed deploy fails the Jenkins build.
printf '%s\n' "$POSTGRES_PASSWORD" \
    | ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "bash ~/$DEPLOY_DIR/server-cmds.sh '$IMAGE_NAME'"
