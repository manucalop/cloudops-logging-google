import logging
import os

import google.cloud.logging


def is_running_on_google_cloud() -> bool:
    is_google_on_google_cloud = (
        os.environ.get("K_SERVICE", False)
        or os.environ.get("CLOUD_RUN_JOB", False)
        or os.environ.get("GCP_PROJECT", False)
    )
    if is_google_on_google_cloud:
        return True
    return False


def get_google_cloud_logger(name: str) -> logging.Logger:
    client = google.cloud.logging.Client()
    client.setup_logging()
    logger = logging.getLogger(name)
    logger.setLevel(logging.DEBUG)
    return logger


def get_local_logger(name: str, level: int = logging.DEBUG) -> logging.Logger:
    logger = logging.getLogger(name)
    for handler in logger.handlers:
        logger.removeHandler(handler)
    handler = logging.StreamHandler()
    formatter = logging.Formatter(
        "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    )
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(level)
    return logger


def get_logger(name: str, level: int = logging.DEBUG) -> logging.Logger:
    if is_running_on_google_cloud():
        return get_google_cloud_logger(name)
    else:
        return get_local_logger(name, level)
