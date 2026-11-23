#!/usr/bin/env bash
# Runs ON EC2. deploy.sh copies it to ~/django-app/ (next to docker-compose.yaml) and runs it.
#
# 1. Remembers the image that is running now (from .env)
# 2. Writes .env with the new image and starts it with docker-compose
# 3. Checks /health/ (also checks the database connection)
# 4. If the new version is not healthy: shows its logs and rolls back to the previous image
#
# Usage:
#   from Jenkins (password on stdin, so it is never in a command line):
#     printf '%s\n' "$POSTGRES_PASSWORD" | ssh ec2-user@<ip> "bash ~/django-app/server-cmds.sh <image>"
#   by hand on EC2, e.g. to go back to an older version (password is taken from .env):
#     cd ~/django-app && bash server-cmds.sh vioreldv2/learn-devops:django-v1.3
set -euo pipefail
cd "$(dirname "$0")"   # the folder with docker-compose.yaml and .env

NEW_IMAGE="${1:?usage: server-cmds.sh <image>}"
HEALTH_URL="${HEALTH_URL:-http://localhost:8000/health/}"

# Value of KEY from .env (empty if there is no .env yet). Not `source`d, so special
# characters in the password can't break anything.
env_get() {
    if [ -f .env ]; then sed -n "s/^$1=//p" .env | head -n 1; fi
}

# Write .env for the given image, readable only by this user
write_env() {
    (umask 077 && printf 'IMAGE_NAME=%s\nPOSTGRES_PASSWORD=%s\n' "$1" "$POSTGRES_PASSWORD" > .env.tmp)
    mv .env.tmp .env
}

# Up to 30 s for the app to answer /health/ with HTTP 200 (503 = database not reachable)
health_ok() {
    for attempt in $(seq 1 15); do
        if curl -fs --max-time 5 "$HEALTH_URL" > /dev/null; then
            echo "Health check passed (attempt $attempt)"
            return 0
        fi
        sleep 2
    done
    echo "Health check FAILED: $HEALTH_URL did not return 200"
    return 1
}

# Start the given image and verify it. --pull missing: pull from Docker Hub only if
# the image is not on this server yet (a new build tag always is pulled; a rollback
# to an image that is still here starts without a download).
start() {
    echo "Starting $1"
    write_env "$1"
    docker-compose up -d --pull missing --wait --wait-timeout 120 && health_ok
}

# Password: from stdin when piped (Jenkins), otherwise keep the one in .env
POSTGRES_PASSWORD=""
if [ ! -t 0 ]; then IFS= read -r POSTGRES_PASSWORD || true; fi
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(env_get POSTGRES_PASSWORD)}"
if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "ERROR: no POSTGRES_PASSWORD (pipe it on stdin, or keep it in .env)" >&2
    exit 1
fi

PREVIOUS_IMAGE="$(env_get IMAGE_NAME)"
echo "Running now: ${PREVIOUS_IMAGE:-nothing}"
echo "Deploying:   $NEW_IMAGE"

if start "$NEW_IMAGE"; then
    docker-compose ps
    echo "Deploy OK: $NEW_IMAGE"
    exit 0
fi

echo "---- last log lines of the new version ----"
docker-compose logs --tail 40 django-app || true

if [ -n "$PREVIOUS_IMAGE" ] && [ "$PREVIOUS_IMAGE" != "$NEW_IMAGE" ]; then
    echo "Rolling back to $PREVIOUS_IMAGE"
    if start "$PREVIOUS_IMAGE"; then
        echo "Rolled back to $PREVIOUS_IMAGE (deploy of $NEW_IMAGE FAILED)"
    else
        echo "Rollback FAILED as well - check: docker-compose logs"
    fi
else
    echo "No previous version to roll back to"
fi
# Non-zero exit -> the Jenkins build is marked as failed, even after a successful rollback
exit 1
