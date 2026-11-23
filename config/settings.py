"""Settings for the Django app. Runtime values come from environment variables."""
import os
from pathlib import Path

from django.core.management.utils import get_random_secret_key

BASE_DIR = Path(__file__).resolve().parent.parent

# The app has no sessions or logins, so a random key per start is fine.
# Set DJANGO_SECRET_KEY if you add features that need a stable key.
SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY") or get_random_secret_key()
DEBUG = os.environ.get("DJANGO_DEBUG", "false").lower() == "true"
# "*" because the app is reached by IP. Set e.g. DJANGO_ALLOWED_HOSTS=16.171.230.252 to restrict.
ALLOWED_HOSTS = os.environ.get("DJANGO_ALLOWED_HOSTS", "*").split(",")

INSTALLED_APPS = [
    "django.contrib.staticfiles",
    "core",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {"context_processors": ["django.template.context_processors.request"]},
    },
]

# PostgreSQL when POSTGRES_HOST is set (docker-compose sets it to "db").
# Without it (tests, plain `docker run`) there is no database and the page
# shows "not configured" instead of failing.
if os.environ.get("POSTGRES_HOST"):
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "HOST": os.environ["POSTGRES_HOST"],
            "PORT": os.environ.get("POSTGRES_PORT", "5432"),
            "NAME": os.environ.get("POSTGRES_DB", "app"),
            "USER": os.environ.get("POSTGRES_USER", "app"),
            "PASSWORD": os.environ.get("POSTGRES_PASSWORD", ""),
            # Give up after 3 s, so a down database doesn't hang the page
            "OPTIONS": {"connect_timeout": 3},
        }
    }
else:
    DATABASES = {}

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = False
USE_TZ = True

# Static files are collected at image build time and served by WhiteNoise
STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {"BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage"},
}

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {"console": {"class": "logging.StreamHandler"}},
    "root": {"handlers": ["console"], "level": "INFO"},
}
