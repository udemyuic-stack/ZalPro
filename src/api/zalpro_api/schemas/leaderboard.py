from pydantic import Field

from zalpro_api.schemas.base import OutModel, StrictModel


class LeaderboardEntry(OutModel):
    rank: int
    user_id: str
    name: str
    points: int
    active_days: int


class LeaderboardMe(OutModel):
    rank: int
    points: int
    active_days: int


class LeaderboardOut(OutModel):
    period_days: int
    top: list[LeaderboardEntry]
    me: LeaderboardMe | None


class LeaderboardVisibility(StrictModel):
    visible: bool = Field(strict=True)


class GameToggle(StrictModel):
    enabled: bool = Field(strict=True)
