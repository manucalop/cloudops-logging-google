import unittest

from cloudops.logging.google import get_logger


class TestConfig(unittest.TestCase):
    def setUp(self):
        pass

    def test_config(self):
        logger = get_logger(__name__)
        logger.info("test_config")
        self.assertTrue(True)


if __name__ == "__main__":
    unittest.main()
