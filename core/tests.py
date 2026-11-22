from unittest import mock

from django.test import SimpleTestCase
from django.urls import reverse

CONNECTED = {
    "status": "connected",
    "host": "db",
    "port": "5432",
    "name": "app",
    "user": "app",
    "server_version": "17.7",
    "latency_ms": 1.2,
    "uptime_seconds": 120,
}
UNREACHABLE = {
    "status": "error",
    "host": "db",
    "port": "5432",
    "name": "app",
    "user": "app",
    "error": "connection refused",
}


class PageTests(SimpleTestCase):
    def test_index_page_renders(self):
        response = self.client.get(reverse("index"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Django")

    def test_health_returns_ok(self):
        response = self.client.get(reverse("health"))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "OK")


class DatabaseTests(SimpleTestCase):
    # The tests run without POSTGRES_HOST, so the real check reports "not configured"
    def test_without_database_shows_not_configured(self):
        response = self.client.get(reverse("index"))
        self.assertContains(response, "Not configured")
        self.assertEqual(self.client.get(reverse("health")).json()["database"]["status"], "not configured")

    @mock.patch("core.views.db_info", return_value=CONNECTED)
    def test_connected_database_is_shown(self, _):
        response = self.client.get(reverse("index"))
        self.assertContains(response, "Connected")
        self.assertContains(response, "17.7")
        self.assertEqual(self.client.get(reverse("health")).status_code, 200)

    @mock.patch("core.views.db_info", return_value=UNREACHABLE)
    def test_unreachable_database_degrades_health(self, _):
        response = self.client.get(reverse("index"))
        self.assertContains(response, "Unreachable")
        self.assertContains(response, "connection refused")
        health = self.client.get(reverse("health"))
        self.assertEqual(health.status_code, 503)
        self.assertEqual(health.json()["status"], "DEGRADED")
