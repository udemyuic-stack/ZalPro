from datetime import datetime

from zalpro_api.schemas.base import OutModel


class MembershipOut(OutModel):
    user_id: str
    name: str
    gym_id: str
    months: int
    days: int
    price: int
    currency: str
    paid_date: datetime
    expires_at: datetime
    updated_at: datetime
