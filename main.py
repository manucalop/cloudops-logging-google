from cloudops-logging-google.config import get_config


def main():
    config = get_config("config.yaml")
    print(config)


if __name__ == "__main__":
    main()
