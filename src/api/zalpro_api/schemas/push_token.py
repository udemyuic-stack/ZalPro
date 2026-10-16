from typing import Annotated, Literal

from pydantic import StringConstraints

from zalpro_api.models.push_token import MAX_PUSH_TOKEN_LENGTH
from zalpro_api.schemas.base import StrictModel

PushTokenValue = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=MAX_PUSH_TOKEN_LENGTH)
]


class PushTokenIn(StrictModel):
    token: PushTokenValue
    platform: Literal["android", "web", "ios"]
