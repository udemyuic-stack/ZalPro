import asyncio
import contextlib
import logging
import shutil
import tempfile
import uuid
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from sqlalchemy import select

from zalpro_api.models import Exercise, Message
from zalpro_api.services import chat_media
from zalpro_api.services.message_view import message_out, message_payload

logger = logging.getLogger(__name__)

VIDEO_CONTENT_TYPE = "video/mp4"
TRANSCODE_TIMEOUT_SECONDS = 15 * 60
VIDEO_FILTER = (
    "scale='min(1280,iw)':'min(1280,ih)':force_original_aspect_ratio=decrease"
    ":force_divisible_by=2,fps=30"
)

Transcode = Callable[[Path, Path], Awaitable[None]]


class TranscodeError(Exception):
    pass


def raw_prefix(exercise_id: str) -> str:
    return f"exercises/{exercise_id}/raw/"


def video_prefix(exercise_id: str) -> str:
    return f"exercises/{exercise_id}/video/"


def build_raw_key(exercise_id: str) -> str:
    return f"{raw_prefix(exercise_id)}{uuid.uuid4().hex}"


def build_video_key(exercise_id: str) -> str:
    return f"{video_prefix(exercise_id)}{uuid.uuid4().hex}.mp4"


def ffmpeg_args(source: Path, target: Path) -> list[str]:
    return [
        "-y",
        "-i",
        str(source),
        "-vf",
        VIDEO_FILTER,
        "-c:v",
        "libx264",
        "-preset",
        "veryfast",
        "-crf",
        "23",
        "-maxrate",
        "2500k",
        "-bufsize",
        "5000k",
        "-profile:v",
        "high",
        "-pix_fmt",
        "yuv420p",
        "-movflags",
        "+faststart",
        "-c:a",
        "aac",
        "-b:a",
        "96k",
        "-threads",
        "1",
        str(target),
    ]


async def run_ffmpeg(source: Path, target: Path) -> None:
    binary = shutil.which("ffmpeg")
    if binary is None:
        raise TranscodeError("ffmpeg topilmadi")
    process = await asyncio.create_subprocess_exec(
        binary,
        *ffmpeg_args(source, target),
        stdin=asyncio.subprocess.DEVNULL,
        stdout=asyncio.subprocess.DEVNULL,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        async with asyncio.timeout(TRANSCODE_TIMEOUT_SECONDS):
            _, stderr = await process.communicate()
    except TimeoutError as error:
        raise TranscodeError("ffmpeg vaqt chegarasidan oshdi") from error
    finally:
        if process.returncode is None:
            process.kill()
            await process.wait()
    if process.returncode != 0:
        tail = stderr[-2000:].decode(errors="replace")
        raise TranscodeError(f"ffmpeg {process.returncode} kod bilan tugadi: {tail}")


@dataclass(frozen=True)
class VideoJob:
    exercise_id: str
    raw_key: str
    target: str = "exercise"

    @property
    def is_message(self) -> bool:
        return self.target == "message"


class VideoWorker:
    def __init__(self, state: Any, transcode: Transcode = run_ffmpeg) -> None:
        self._state = state
        self.transcode = transcode
        self._queue: asyncio.Queue[VideoJob] = asyncio.Queue()
        self._task: asyncio.Task[None] | None = None

    def enqueue(self, job: VideoJob) -> None:
        self._queue.put_nowait(job)

    async def join(self) -> None:
        await self._queue.join()

    async def start(self) -> None:
        if self._task is None:
            self._task = asyncio.create_task(self._run())

    async def stop(self) -> None:
        task = self._task
        if task is None:
            return
        self._task = None
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task

    async def _run(self) -> None:
        await self.recover()
        while True:
            job = await self._queue.get()
            try:
                await self.process(job)
            except Exception:
                logger.exception("video_job_crashed", extra={"exercise_id": job.exercise_id})
            finally:
                self._queue.task_done()

    async def recover(self) -> None:
        try:
            async with self._state.sessionmaker() as session:
                pending = (
                    await session.scalars(
                        select(Exercise).where(Exercise.video_status == "processing")
                    )
                ).all()
                for exercise in pending:
                    keys = await self._raw_keys(exercise.id)
                    if keys:
                        self.enqueue(VideoJob(exercise.id, keys[0]))
                        continue
                    exercise.video_status = "failed"
                    logger.error("video_recovery_raw_missing", extra={"exercise_id": exercise.id})
                await session.commit()
                await self._recover_messages(session)
        except Exception:
            logger.exception("video_recovery_failed")

    async def _recover_messages(self, session: Any) -> None:
        pending = (
            await session.scalars(
                select(Message).where(
                    Message.media_status == "processing", Message.media_kind == "video"
                )
            )
        ).all()
        for message in pending:
            if message.media_key is not None and await self._state.storage.head(message.media_key):
                self.enqueue(VideoJob(str(message.id), message.media_key, "message"))
                continue
            message.media_status = "failed"
            await session.commit()
            await self._publish_updated(message)
            logger.error("video_recovery_raw_missing", extra={"message_id": str(message.id)})

    async def _raw_keys(self, exercise_id: str) -> list[str]:
        try:
            return await self._state.storage.list_keys(raw_prefix(exercise_id))
        except Exception:
            logger.exception("video_recovery_list_failed", extra={"exercise_id": exercise_id})
            return []

    async def process(self, job: VideoJob) -> None:
        storage = self._state.storage
        key = await self._new_key(job)
        if key is None:
            await self._delete(job.raw_key)
            return
        try:
            with tempfile.TemporaryDirectory(prefix="zalpro-video-") as directory:
                source = Path(directory) / "in"
                target = Path(directory) / "out.mp4"
                await storage.download(job.raw_key, source)
                await self.transcode(source, target)
                if not target.is_file() or target.stat().st_size == 0:
                    raise TranscodeError("ffmpeg natija fayl yaratmadi")
                await storage.upload(target, key, VIDEO_CONTENT_TYPE)
        except Exception:
            logger.exception("video_transcode_failed", extra={"exercise_id": job.exercise_id})
            await self._fail(job)
            return
        await self._finish(job, key)

    async def _new_key(self, job: VideoJob) -> str | None:
        if not job.is_message:
            return build_video_key(job.exercise_id)
        async with self._state.sessionmaker() as session:
            message = await session.get(Message, uuid.UUID(job.exercise_id))
        if message is None:
            return None
        return chat_media.build_video_key(message.chat_uid)

    async def _publish_updated(self, message: Message) -> None:
        settings = self._state.settings
        out = await message_out(self._state.storage, settings, message)
        payload = message_payload(message, out.media_url)
        payload["updated"] = True
        self._state.hub.publish(message.chat_uid, payload)

    async def _finish_message(self, job: VideoJob, key: str) -> None:
        async with self._state.sessionmaker() as session:
            message = await session.get(Message, uuid.UUID(job.exercise_id))
            if message is None or message.media_status != "processing":
                await self._delete(job.raw_key, key)
                return
            message.media_key = key
            message.media_status = "ready"
            await session.commit()
            await session.refresh(message)
        await self._publish_updated(message)
        await self._delete(job.raw_key)
        logger.info("video_transcode_ready", extra={"message_id": job.exercise_id})

    async def _fail_message(self, job: VideoJob) -> None:
        await self._delete(job.raw_key)
        async with self._state.sessionmaker() as session:
            message = await session.get(Message, uuid.UUID(job.exercise_id))
            if message is None or message.media_status != "processing":
                return
            message.media_status = "failed"
            await session.commit()
            await session.refresh(message)
        await self._publish_updated(message)

    async def _finish(self, job: VideoJob, key: str) -> None:
        if job.is_message:
            await self._finish_message(job, key)
            return
        async with self._state.sessionmaker() as session:
            exercise = await session.get(Exercise, job.exercise_id)
            if exercise is None or exercise.video_status is None:
                await self._delete(job.raw_key, key)
                return
            previous = exercise.video_key
            exercise.video_key = key
            exercise.video_status = "ready"
            await session.commit()
        stale = [job.raw_key]
        if previous is not None and previous != key:
            stale.append(previous)
        await self._delete(*stale)
        logger.info("video_transcode_ready", extra={"exercise_id": job.exercise_id})

    async def _fail(self, job: VideoJob) -> None:
        if job.is_message:
            await self._fail_message(job)
            return
        await self._delete(job.raw_key)
        async with self._state.sessionmaker() as session:
            exercise = await session.get(Exercise, job.exercise_id)
            if exercise is not None and exercise.video_status == "processing":
                exercise.video_status = "failed"
                await session.commit()

    async def _delete(self, *keys: str) -> None:
        storage = self._state.storage
        for key in keys:
            try:
                await storage.delete(key)
            except Exception:
                logger.exception("video_object_delete_failed", extra={"key": key})
