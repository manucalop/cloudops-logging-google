import logging
import os

import google.cloud.logging


class CloudopsLogging:
    def __init__(self):
        self.running_on_gcloud = self._is_running_on_google_cloud()
        if self.running_on_gcloud:
            client = google.cloud.logging.Client()
            client.setup_logging()

    def get_logger(
        self, name: str, level: int = logging.DEBUG
    ) -> logging.Logger:
        if self.running_on_gcloud:
            return self._get_google_cloud_logger(name)
        else:
            return self._get_local_logger(name, level)

    @staticmethod
    def _get_google_cloud_logger(name: str) -> logging.Logger:
        logger = logging.getLogger(name)
        logger.setLevel(logging.DEBUG)
        return logger

    @staticmethod
    def _is_running_on_google_cloud() -> bool:
        is_google_on_google_cloud = (
            os.environ.get("K_SERVICE", False)
            or os.environ.get("CLOUD_RUN_JOB", False)
            or os.environ.get("GCP_PROJECT", False)
        )
        if is_google_on_google_cloud:
            return True
        return False

    @staticmethod
    def _get_local_logger(name: str, level: int) -> logging.Logger:
        logger = logging.getLogger(name)
        for handler in logger.handlers:
            logger.removeHandler(handler)
        handler = logging.StreamHandler()
        try:
            import colorlog
            formatter = colorlog.ColoredFormatter(
                "%(reset)s%(asctime)s - %(name)s - %(log_color)s%(levelname)s%(reset)s - %(message)s"
            )
        except ImportError:
            formatter = logging.Formatter(
                "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
            )
        handler.setFormatter(formatter)
        logger.addHandler(handler)
        logger.setLevel(level)
        return logger


cloudops_logging = CloudopsLogging()


def get_logger(name: str, level: int = logging.DEBUG) -> logging.Logger:
    return cloudops_logging.get_logger(name, level)
