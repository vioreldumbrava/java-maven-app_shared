# Multi-stage build: base -> test, and base -> runtime.
# Docker only builds the stages needed for the requested target:
#   docker build --target test .                     -> runs the tests (Jenkins "test" stage)
#   docker build --build-arg APP_VERSION=... .       -> builds the deployable image (default/last stage)

# =====================================================================
# Stage 1: base - dependencies, app code and collected static files
# =====================================================================

# Official Python image; "slim" leaves out compilers and extras to stay small.
# "AS base" names the stage so the other stages can start from it.
FROM python:3.13-slim AS base

# PYTHONDONTWRITEBYTECODE: don't write .pyc cache files (not needed in a container)
# PYTHONUNBUFFERED:        print output immediately, so `docker logs` shows it live
# PIP_NO_CACHE_DIR:        don't keep downloaded packages -> smaller image
# PIP_DISABLE_PIP_VERSION_CHECK: skip pip's online "newer version" check
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Create /app and run every following command from there
WORKDIR /app

# Copy only requirements.txt first, then install. Because of Docker's layer cache,
# the slow pip install is reused on the next build if requirements.txt didn't change,
# even when the Python code did.
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy the rest of the project (.dockerignore decides what is left out)
COPY . .

# Gather static files (CSS) into /app/staticfiles with a hash in the file name
# (cache busting); WhiteNoise serves them. --noinput: never ask for confirmation.
RUN python manage.py collectstatic --noinput

# =====================================================================
# Stage 2: test - runs the Django tests
# =====================================================================

# Start from everything in "base". If a test fails, this RUN fails and so does
# the whole `docker build --target test` -> the Jenkins "test" stage fails.
# A plain `docker build .` skips this stage, since "runtime" does not depend on it.
FROM base AS test
RUN python manage.py test

# =====================================================================
# Stage 3: runtime - the image that is pushed to Docker Hub and deployed
# =====================================================================

# Start again from "base" (not "test"), so nothing from the test run ends up here
FROM base AS runtime

# ARG exists only during the build (Jenkins passes --build-arg APP_VERSION=django-v1.N).
# ENV keeps the value in the running container, where the app shows it on the page
# and in /health/. Both are needed because ARG values are gone after the build.
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}

# Run as a normal user instead of root, so a compromised app has almost no rights
RUN useradd --create-home --uid 10001 app
USER app

# Documents the port the app listens on. It does NOT publish it:
# `docker run -p 8000:8000` (or `ports:` in docker-compose) does that.
EXPOSE 8000

# Start command:
#   gunicorn                  production web server (Django's runserver is for development only)
#   config.wsgi:application   the Django app to serve (the "application" object in config/wsgi.py)
#   --bind 0.0.0.0:8000       listen on all interfaces, so port mapping from the host works
#   --workers 2               two processes handle requests in parallel (kept low: EC2 has <1 GB RAM)
#   --access-logfile -        log each request to stdout -> visible in `docker logs`
# The JSON-array form runs gunicorn directly (no shell), so it gets `docker stop` and shuts down cleanly.
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "2", "--access-logfile", "-"]
