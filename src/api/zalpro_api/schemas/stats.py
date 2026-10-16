from zalpro_api.schemas.base import OutModel


class TrainerStatOut(OutModel):
    trainer_id: str
    name: str
    client_count: int
    tracked_days: int
    meals_done: int
    meals_expected: int
    adherence: float | None
    plan_coverage: float | None
    reply_rate: float | None
    progress_rate: float | None
    messages_sent: int
    score: int | None
    stars: int | None
    average_rating: float | None
    rating_count: int
