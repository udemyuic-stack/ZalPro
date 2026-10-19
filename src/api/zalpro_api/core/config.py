from zoneinfo import ZoneInfo

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str
    jwt_secret: str = Field(min_length=32)
    access_token_minutes: int = Field(default=15, ge=1)
    refresh_token_days: int = Field(default=30, ge=1)
    gym_timezone: str = "Asia/Tashkent"
    auto_reminders_enabled: bool = True
    r2_endpoint_url: str = ""
    r2_access_key_id: str = ""
    r2_secret_access_key: str = ""
    r2_bucket: str = ""
    photo_url_seconds: int = Field(default=600, ge=60)
    video_url_seconds: int = Field(default=3600, ge=60)
    legacy_scrypt_signer_key: str = ""
    legacy_scrypt_salt_separator: str = ""
    legacy_scrypt_rounds: int = Field(default=8, ge=1)
    legacy_scrypt_mem_cost: int = Field(default=14, ge=1, le=20)
    login_max_attempts: int = Field(default=10, ge=1)
    login_window_seconds: int = Field(default=900, ge=1)
    cors_origins: str = ""
    backup_r2_endpoint_url: str = ""
    backup_r2_access_key_id: str = ""
    backup_r2_secret_access_key: str = ""
    backup_r2_bucket: str = ""
    backup_ping_url: str = ""
    backup_prefix: str = "zalpro"
    min_app_build: int = Field(default=0, ge=0)
    app_download_url: str = ""

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @property
    def r2_configured(self) -> bool:
        return all(
            (self.r2_endpoint_url, self.r2_access_key_id, self.r2_secret_access_key, self.r2_bucket)
        )

    @property
    def backup_configured(self) -> bool:
        return all(
            (
                self.backup_r2_endpoint_url,
                self.backup_r2_access_key_id,
                self.backup_r2_secret_access_key,
                self.backup_r2_bucket,
            )
        )

    @property
    def legacy_scrypt_configured(self) -> bool:
        return bool(self.legacy_scrypt_signer_key and self.legacy_scrypt_salt_separator)

    @field_validator("database_url")
    @classmethod
    def normalize_database_url(cls, value: str) -> str:
        for prefix in ("postgres://", "postgresql://"):
            if value.startswith(prefix):
                value = "postgresql+asyncpg://" + value[len(prefix) :]
                break
        return value.replace("sslmode=", "ssl=")

    @field_validator("gym_timezone")
    @classmethod
    def validate_timezone(cls, value: str) -> str:
        ZoneInfo(value)
        return value
