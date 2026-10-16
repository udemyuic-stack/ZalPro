import uuid
from typing import Annotated

from pydantic import AwareDatetime, StringConstraints

from zalpro_api.schemas.base import OutModel, StrictModel

MAX_MESSAGE_LENGTH = 2000
DEFAULT_MESSAGES_LIMIT = 50
MAX_MESSAGES_LIMIT = 200

MessageText = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=MAX_MESSAGE_LENGTH)
]


class MessageIn(StrictModel):
    text: MessageText


class MessageOut(OutModel):
    id: uuid.UUID
    chat_uid: str
    sender_id: str
    kind: str
    text: str
    created_at: AwareDatetime
