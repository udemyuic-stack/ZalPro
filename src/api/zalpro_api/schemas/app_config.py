from zalpro_api.schemas.base import OutModel


class AppConfigOut(OutModel):
    min_app_build: int
    download_url: str
