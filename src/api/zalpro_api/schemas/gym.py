from pydantic import Field

from zalpro_api.schemas.base import Name, OutModel, StrictModel


class GymIn(StrictModel):
    name: Name
    address: str = Field(default="", max_length=200)
    country: str = Field(default="", max_length=60)
    region: str = Field(default="", max_length=60)
    district: str = Field(default="", max_length=60)
    map_url: str = Field(default="", max_length=500, pattern=r"^(https?://\S+)?$")


class GymOut(OutModel):
    id: str
    name: str
    address: str
    country: str
    region: str
    district: str
    map_url: str
