import os
import platform
import socket
import time
from datetime import datetime, timedelta, timezone

import django
from django.db import DatabaseError, connection
from django.http import JsonResponse
from django.shortcuts import render

STARTED_AT = datetime.now(timezone.utc)


def db_info():
    """Check the database connection with a small query and describe the result."""
    settings = connection.settings_dict
    if settings["ENGINE"] == "django.db.backends.dummy":
        return {"status": "not configured"}

    info = {
        "host": settings["HOST"],
        "port": str(settings["PORT"]),
        "name": settings["NAME"],
        "user": settings["USER"],
    }
    start = time.perf_counter()
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT current_setting('server_version'), now() - pg_postmaster_start_time()")
            server_version, db_uptime = cursor.fetchone()
    except DatabaseError as exc:
        # First line only: the full message can be long
        error = str(exc).strip().splitlines()[0] if str(exc).strip() else exc.__class__.__name__
        return {**info, "status": "error", "error": error}
    return {
        **info,
        "status": "connected",
        "server_version": server_version.split()[0],  # "17.12 (Debian ...)" -> "17.12"
        "latency_ms": round((time.perf_counter() - start) * 1000, 1),
        "uptime_seconds": int(db_uptime.total_seconds()),
    }


def app_info():
    database = db_info()
    return {
        # A configured database that can't be reached makes the app DEGRADED
        "status": "DEGRADED" if database["status"] == "error" else "OK",
        "version": os.environ.get("APP_VERSION", "dev"),
        "hostname": socket.gethostname(),
        "python": platform.python_version(),
        "django": django.get_version(),
        "started_at": STARTED_AT.isoformat(timespec="seconds"),
        "database": database,
    }


def index(request):
    info = app_info()
    db_started_at = None
    if info["database"]["status"] == "connected":
        db_started_at = datetime.now(timezone.utc) - timedelta(seconds=info["database"]["uptime_seconds"])
    context = {"info": info, "db": info["database"], "started_at": STARTED_AT, "db_started_at": db_started_at}
    return render(request, "core/index.html", context)


def health(request):
    info = app_info()
    # 503 lets load balancers / health checks see that the database is down
    return JsonResponse(info, status=503 if info["status"] == "DEGRADED" else 200)
