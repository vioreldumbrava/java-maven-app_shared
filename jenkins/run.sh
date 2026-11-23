#!/usr/bin/env bash
# Build and run the JCasC Jenkins with plain `docker` (for hosts without docker compose).
# Usage: ./run.sh            (reads settings from ./.env, secrets from ./secrets/)
set -euo pipefail
cd "$(dirname "$0")"

if [ -f .env ]; then set -a; . ./.env; set +a; fi
: "${REPO_URL:?Set REPO_URL in .env}"

NAME="${CONTAINER_NAME:-jenkins-casc}"
PORT="${JENKINS_PORT:-8090}"
VOLUME="${JENKINS_VOLUME:-jenkins_casc_home}"

docker build -t jenkins-casc:latest .

# DOCKER_SOCKET=1 lets pipelines use the host's Docker (docker build/push/run).
# This gives Jenkins root-equivalent control of the host, so it is opt-in.
DOCKER_ARGS=()
if [ "${DOCKER_SOCKET:-0}" = "1" ]; then
  DOCKER_ARGS=(-v /var/run/docker.sock:/var/run/docker.sock
               --group-add "$(stat -c %g /var/run/docker.sock)")
fi

# Replaces only this container; Jenkins data lives in the volume and is kept.
docker rm -f "$NAME" >/dev/null 2>&1 || true

docker run -d --name "$NAME" --restart unless-stopped \
  -p "$PORT:8080" \
  "${DOCKER_ARGS[@]}" \
  -e JENKINS_URL="${JENKINS_URL:-http://localhost:$PORT/}" \
  -e JENKINS_ADMIN_ID="${JENKINS_ADMIN_ID:-admin}" \
  -e DOCKER_HUB_USER="${DOCKER_HUB_USER:-}" \
  -e GITLAB_USER="${GITLAB_USER:-}" \
  -e AWS_ECR_ACCESS_KEY_ID="${AWS_ECR_ACCESS_KEY_ID:-}" \
  -e REPO_URL="$REPO_URL" \
  -e REPO_BRANCH="${REPO_BRANCH:-master}" \
  -e DJANGO_REPO_URL="${DJANGO_REPO_URL:-https://github.com/vioreldumbrava/java-maven-app_shared.git}" \
  -e DJANGO_BRANCH="${DJANGO_BRANCH:-django-app}" \
  -v "$VOLUME:/var/jenkins_home" \
  -v "$PWD/casc:/var/jenkins_casc:ro" \
  -v "$PWD/secrets:/run/secrets:ro" \
  jenkins-casc:latest

echo "Started $NAME on port $PORT. Follow logs with: docker logs -f $NAME"
