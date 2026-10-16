import re

from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.errors import ApiError, not_found
from zalpro_api.models import Exercise
from zalpro_api.models.exercise import MAX_VIDEO_BYTES
from zalpro_api.schemas.exercise_video import VideoUploadOut, VideoUrlOut
from zalpro_api.services.storage import Storage, build_key

VIDEO_CONTENT_TYPE = "video/mp4"


def video_prefix(exercise_id: str) -> str:
    return f"videos/{exercise_id}/"


async def create_upload(
    storage: Storage, exercise: Exercise, size: int, expires: int
) -> VideoUploadOut:
    key = build_key("video", exercise.id)
    upload_url = await storage.presign_put(key, size, expires)
    return VideoUploadOut(key=key, upload_url=upload_url, expires_in=expires)


async def confirm_upload(
    session: AsyncSession, storage: Storage, exercise: Exercise, key: str
) -> None:
    if re.fullmatch(re.escape(video_prefix(exercise.id)) + r"[0-9a-f]{32}", key) is None:
        raise ApiError(422, "video_key_invalid", "Video kaliti bu mashqqa tegishli emas")
    size = await storage.head(key)
    if size is None:
        raise ApiError(422, "video_not_uploaded", "Video yuklanmagan")
    if size > MAX_VIDEO_BYTES:
        await storage.delete(key)
        raise ApiError(422, "video_too_large", "Video hajmi chegaradan katta")
    previous = exercise.video_key
    exercise.video_key = key
    await session.commit()
    if previous is not None and previous != key:
        await storage.delete(previous)


async def read_url(storage: Storage, exercise: Exercise, expires: int) -> VideoUrlOut:
    if exercise.video_key is None:
        raise not_found("Mashqda video yo'q")
    url = await storage.presign_get(exercise.video_key, expires, VIDEO_CONTENT_TYPE)
    return VideoUrlOut(url=url, expires_in=expires)


async def remove_video(session: AsyncSession, storage: Storage, exercise: Exercise) -> None:
    key = exercise.video_key
    if key is None:
        return
    exercise.video_key = None
    await session.commit()
    await storage.delete(key)
