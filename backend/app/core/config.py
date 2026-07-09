"""应用配置，从环境变量读取。"""
from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    POSTGRES_HOST: str = "db"
    POSTGRES_PORT: int = 5432
    POSTGRES_USER: str = "audiobook"
    POSTGRES_PASSWORD: str = "audiobook_secret"
    POSTGRES_DB: str = "audiobook"

    REDIS_HOST: str = "redis"
    REDIS_PORT: int = 6379
    REDIS_DB: int = 0

    CELERY_BROKER_URL: str = "redis://localhost:6379/0"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/1"

    JWT_SECRET_KEY: str = "change-me-to-a-real-secret-key-in-production"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080

    STORAGE_TYPE: str = "local"
    LOCAL_STORAGE_ROOT: str = "/app/storage"
    LOCAL_STORAGE_BASE_URL: str = "http://localhost:8000/storage"

    CORS_ORIGINS: str = "http://localhost:8000,http://localhost:3000"

    @property
    def database_url(self) -> str:
        return (
            f"postgresql+psycopg2://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}"
            f"@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
        )

    @property
    def cors_origins_list(self) -> List[str]:
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]


settings = Settings()
