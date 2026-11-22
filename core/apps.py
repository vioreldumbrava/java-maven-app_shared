import logging

from django.apps import AppConfig


class CoreConfig(AppConfig):
    name = "core"

    def ready(self):
        logging.getLogger(__name__).info("Django app started")
