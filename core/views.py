import os
import platform
import socket
from datetime import datetime, timezone

import django
from django.http import JsonResponse
from django.shortcuts import render

STARTED_AT = datetime.now(timezone.utc)


def app_info():
    return {
        "status": "OK",
        "version": os.environ.get("APP_VERSION", "dev"),
        "hostname": socket.gethostname(),
        "python": platform.python_version(),
        "django": django.get_version(),
        "started_at": STARTED_AT.isoformat(timespec="seconds"),
    }


def index(request):
    return render(request, "core/index.html", {"info": app_info(), "started_at": STARTED_AT})


def health(request):
    return JsonResponse(app_info())
