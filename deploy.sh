#!/usr/bin/env bash
# Deploy the Django app + PostgreSQL to EC2.
#
# Runs on the Jenkins agent (called from the Jenkinsfile "deploy" stage, inside
# sshagent, which provides the SSH key). It copies the files EC2 needs and starts
# server-cmds.sh there, which does the actual deploy, health check and rollback.
#
# It can also be run by hand:
#   POSTGRES_PASSWORD=... bash deploy.sh ec2-user@13.60.47.84 vioreldv2/learn-devops:django-v1.5
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

# 2. Run the server script on EC2. The password goes through stdin.
#    Its exit code becomes ours, so a failed deploy fails the Jenkins build.
printf '%s\n' "$POSTGRES_PASSWORD" \
    | ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "bash ~/$DEPLOY_DIR/server-cmds.sh '$IMAGE_NAME'"
