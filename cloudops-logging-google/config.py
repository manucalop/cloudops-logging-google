import pydantic
from pyaml_env import parse_config

from cloudops-logging-google.logging import get_logger

logger = get_logger(__name__)


class Config(pydantic.BaseModel):
    env_name: str


def get_config(config_file: str) -> Config:
    logger.info(f"Loading config from {config_file}...")
    config = Config(**parse_config(config_file))
    return config
