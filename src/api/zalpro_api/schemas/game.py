import uuid
from datetime import datetime
from typing import Literal

from pydantic import Field

from zalpro_api.schemas.base import OutModel, StrictModel


class ExerciseRuleOut(OutModel):
    key: str
    xp_per_rep: int
    max_reps_per_minute: int


class StreakBonusOut(OutModel):
    days: int
    coins: int


class CatalogOut(OutModel):
    exercises: list[ExerciseRuleOut]
    levels: list[int]
    daily_xp_cap: int
    streak_bonuses: list[StreakBonusOut]


class SessionIn(StrictModel):
    id: uuid.UUID
    exercise: str = Field(min_length=1, max_length=40)
    reps: int = Field(strict=True, ge=1, le=1000)
    duration_s: int = Field(strict=True, ge=1, le=7200)
    visibility_pct: int = Field(strict=True, ge=0, le=100)
    started_at: datetime


class ChallengeResultOut(OutModel):
    step: int
    exercise: str
    target: int
    progress: int
    completed: bool
    coins: int
    muscle: str
    finished: bool


class MuscleLevelsOut(OutModel):
    arms: int
    chest: int
    legs: int


class ChallengeStepOut(OutModel):
    index: int
    exercise: str
    target: int
    coins: int
    muscle: str
    state: Literal["done", "current", "locked"]


class ChallengesOut(OutModel):
    step: int
    progress: int
    finished: bool
    muscles: MuscleLevelsOut
    steps: list[ChallengeStepOut]


class SessionOut(OutModel):
    id: str
    status: str
    coins: int
    xp: int
    streak_bonus: int
    streak_days: int
    total_coins: int
    total_xp: int
    level: int
    level_up: bool
    challenge: ChallengeResultOut | None = None


class GameMeOut(OutModel):
    coins: int
    xp: int
    level: int
    level_xp: int
    next_level_xp: int | None
    streak_days: int
    sessions_total: int
    best_sets: dict[str, int]


class GameEntry(OutModel):
    rank: int
    user_id: str
    name: str
    xp: int
    reps: int


class GameMe(OutModel):
    rank: int
    xp: int
    reps: int


class GameLeaderboardOut(OutModel):
    period: Literal["day", "week", "month", "year", "all"]
    exercise: str | None
    top: list[GameEntry]
    me: GameMe | None
