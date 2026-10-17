import re

from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.errors import ApiError
from zalpro_api.models import Exercise
from zalpro_api.models.exercise import MAX_VIDEO_BYTES
from zalpro_api.schemas.exercise_video import (
    VideoConfirmOut,
    VideoStatus,
    VideoUploadOut,
    VideoUrlOut,
)
from zalpro_api.services.storage import Storage
from zalpro_api.services.video_transcode import (
    VIDEO_CONTENT_TYPE,
    VideoJob,
    VideoWorker,
    build_raw_key,
    raw_prefix,
)


def video_status_of(exercise: Exercise) -> VideoStatus | None:
    if exercise.video_status is not None:
        return exercise.video_status
    if exercise.video_key is not None:
        return "ready"
    return None


async def create_upload(
    storage: Storage, exercise: Exercise, size: int, expires: int
) -> VideoUploadOut:
    key = build_raw_key(exercise.id)
    upload_url = await storage.presign_put(key, size, expires)
    return VideoUploadOut(key=key, upload_url=upload_url, expires_in=expires)


async def confirm_upload(
    session: AsyncSession,
    storage: Storage,
    worker: VideoWorker,
    exercise: Exercise,
    key: str,
) -> VideoConfirmOut:
    if re.fullmatch(re.escape(raw_prefix(exercise.id)) + r"[0-9a-f]{32}", key) is None:
        raise ApiError(422, "video_key_invalid", "Video kaliti bu mashqqa tegishli emas")
    size = await storage.head(key)
    if size is None:
        raise ApiError(422, "video_not_uploaded", "Video yuklanmagan")
    if size > MAX_VIDEO_BYTES:
        await storage.delete(key)
        raise ApiError(422, "video_too_large", "Video hajmi chegaradan katta")
    exercise.video_status = "processing"
    await session.commit()
    worker.enqueue(VideoJob(exercise.id, key))
    return VideoConfirmOut(status="processing")


async def read_url(storage: Storage, exercise: Exercise, expires: int) -> VideoUrlOut:
    status = video_status_of(exercise)
    if exercise.video_key is None:
        return VideoUrlOut(status=status, url=None, expires_in=None)
    url = await storage.presign_get(exercise.video_key, expires, VIDEO_CONTENT_TYPE)
    return VideoUrlOut(status=status, url=url, expires_in=expires)


async def remove_video(session: AsyncSession, storage: Storage, exercise: Exercise) -> None:
    key = exercise.video_key
    if key is None and exercise.video_status is None:
        return
    exercise.video_key = None
    exercise.video_status = None
    await session.commit()
    if key is not None:
        await storage.delete(key)
