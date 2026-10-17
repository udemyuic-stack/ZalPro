import asyncio
import re
import shutil
import time
import uuid
from collections.abc import Awaitable, Callable
from pathlib import Path
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from tests.conftest import FakeStorage
from zalpro_api.models import Exercise, User
from zalpro_api.services import video_transcode
from zalpro_api.services.video_transcode import (
    TranscodeError,
    VideoJob,
    ffmpeg_args,
    run_ffmpeg,
)

UserFactory = Callable[..., Awaitable[User]]
ExerciseFactory = Callable[..., Awaitable[Exercise]]
HeadersFactory = Callable[[User], dict[str, str]]


def raw_key(exercise: Exercise) -> str:
    return f"exercises/{exercise.id}/raw/{uuid.uuid4().hex}"


def legacy_key() -> str:
    return f"videos/abc/{uuid.uuid4().hex}"


async def refresh(db_session: AsyncSession, exercise: Exercise) -> Exercise:
    await db_session.refresh(exercise)
    return exercise


async def failing_transcode(source: Path, target: Path) -> None:
    raise TranscodeError("buzuq fayl")


def fake_binary(tmp_path: Path, body: str) -> str:
    script = tmp_path / "ffmpeg"
    script.write_text(f"#!/bin/sh\n{body}\n")
    script.chmod(0o755)
    return str(script)


async def test_processing_then_ready_keeps_old_video_playable_meanwhile(
    client: AsyncClient,
    storage: FakeStorage,
    video_worker: Any,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="owner")
    old = legacy_key()
    exercise = await make_exercise(video_key=old, video_status="ready")
    raw = raw_key(exercise)
    storage.objects[raw] = 1000
    storage.contents[raw] = b"phone-video"
    gate = asyncio.Event()

    async def gated_transcode(source: Path, target: Path) -> None:
        await gate.wait()
        data = await asyncio.to_thread(source.read_bytes)
        await asyncio.to_thread(target.write_bytes, b"compressed:" + data)

    video_worker.transcode = gated_transcode
    url = f"/v1/exercises/{exercise.id}/video"

    confirmed = await client.put(url, headers=auth_headers(actor), json={"key": raw})
    during = await client.get(url, headers=auth_headers(actor))
    listing = await client.get("/v1/exercises", headers=auth_headers(actor))
    gate.set()
    await video_worker.join()
    after = await client.get(url, headers=auth_headers(actor))

    assert confirmed.status_code == 202
    assert confirmed.json() == {"status": "processing"}
    assert during.json()["status"] == "processing"
    assert during.json()["url"] == f"https://storage.test/get/{old}?type=video/mp4"
    assert listing.json()[0]["video_status"] == "processing"
    assert listing.json()[0]["has_video"] is True
    refreshed = await refresh(db_session, exercise)
    assert refreshed.video_status == "ready"
    assert re.fullmatch(rf"exercises/{exercise.id}/video/[0-9a-f]{{32}}\.mp4", refreshed.video_key)
    assert storage.uploads[refreshed.video_key] == (b"compressed:phone-video", "video/mp4")
    assert sorted(storage.deleted) == sorted([raw, old])
    assert after.json()["status"] == "ready"
    assert after.json()["url"] == f"https://storage.test/get/{refreshed.video_key}?type=video/mp4"


async def test_failure_marks_failed_deletes_raw_and_keeps_old_video(
    client: AsyncClient,
    storage: FakeStorage,
    video_worker: Any,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    old = legacy_key()
    exercise = await make_exercise(video_key=old, video_status="ready")
    raw = raw_key(exercise)
    storage.objects[raw] = 1000
    video_worker.transcode = failing_transcode

    response = await client.put(
        f"/v1/exercises/{exercise.id}/video", headers=auth_headers(actor), json={"key": raw}
    )
    await video_worker.join()

    assert response.status_code == 202
    refreshed = await refresh(db_session, exercise)
    assert refreshed.video_status == "failed"
    assert refreshed.video_key == old
    assert storage.deleted == [raw]
    assert storage.uploads == {}


async def test_worker_keeps_running_after_a_failed_job(
    storage: FakeStorage,
    video_worker: Any,
    make_exercise: ExerciseFactory,
    db_session: AsyncSession,
) -> None:
    broken = await make_exercise(video_status="processing")
    good = await make_exercise(video_status="processing")
    good_raw = raw_key(good)
    storage.objects[good_raw] = 10

    video_worker.enqueue(VideoJob(broken.id, raw_key(broken)))
    video_worker.enqueue(VideoJob(good.id, good_raw))
    await video_worker.join()

    assert (await refresh(db_session, broken)).video_status == "failed"
    assert (await refresh(db_session, good)).video_status == "ready"


async def test_missing_ffmpeg_marks_failed(
    storage: FakeStorage,
    video_worker: Any,
    make_exercise: ExerciseFactory,
    db_session: AsyncSession,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(video_transcode.shutil, "which", lambda name: None)
    video_worker.transcode = run_ffmpeg
    exercise = await make_exercise(video_status="processing")
    raw = raw_key(exercise)
    storage.objects[raw] = 10

    video_worker.enqueue(VideoJob(exercise.id, raw))
    await video_worker.join()

    assert (await refresh(db_session, exercise)).video_status == "failed"
    assert storage.deleted == [raw]


async def test_deleted_exercise_discards_result(
    storage: FakeStorage,
    video_worker: Any,
    make_exercise: ExerciseFactory,
    db_session: AsyncSession,
) -> None:
    exercise = await make_exercise(video_status="processing")
    raw = raw_key(exercise)
    storage.objects[raw] = 10
    await db_session.delete(exercise)
    await db_session.commit()

    video_worker.enqueue(VideoJob(exercise.id, raw))
    await video_worker.join()

    assert len(storage.uploads) == 1
    assert sorted(storage.deleted) == sorted([raw, *storage.uploads])


async def test_video_deleted_while_processing_stays_deleted(
    client: AsyncClient,
    storage: FakeStorage,
    video_worker: Any,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    exercise = await make_exercise()
    raw = raw_key(exercise)
    storage.objects[raw] = 10
    gate = asyncio.Event()

    async def gated_transcode(source: Path, target: Path) -> None:
        await gate.wait()
        await asyncio.to_thread(target.write_bytes, b"mp4")

    video_worker.transcode = gated_transcode
    url = f"/v1/exercises/{exercise.id}/video"

    await client.put(url, headers=auth_headers(actor), json={"key": raw})
    deleted = await client.delete(url, headers=auth_headers(actor))
    gate.set()
    await video_worker.join()

    assert deleted.status_code == 204
    refreshed = await refresh(db_session, exercise)
    assert refreshed.video_key is None
    assert refreshed.video_status is None
    assert sorted(storage.deleted) == sorted([raw, *storage.uploads])


async def test_startup_recovery_requeues_processing_with_raw_and_fails_without(
    storage: FakeStorage,
    video_worker: Any,
    make_exercise: ExerciseFactory,
    db_session: AsyncSession,
) -> None:
    recoverable = await make_exercise(video_status="processing")
    lost = await make_exercise(video_status="processing")
    finished = await make_exercise(video_key=legacy_key(), video_status="ready")
    older = raw_key(recoverable)
    newest = raw_key(recoverable)
    storage.objects[older] = 10
    storage.objects[newest] = 10
    storage.contents[newest] = b"newest"

    await video_worker.recover()
    await video_worker.join()

    refreshed = await refresh(db_session, recoverable)
    assert refreshed.video_status == "ready"
    assert storage.uploads[refreshed.video_key][0] == b"mp4:newest"
    assert newest in storage.deleted
    assert (await refresh(db_session, lost)).video_status == "failed"
    assert (await refresh(db_session, finished)).video_status == "ready"


async def test_startup_recovery_survives_storage_errors(
    app: Any,
    video_worker: Any,
    make_exercise: ExerciseFactory,
    db_session: AsyncSession,
) -> None:
    exercise = await make_exercise(video_status="processing")
    original = app.state.storage

    class BrokenStorage(FakeStorage):
        async def list_keys(self, prefix: str) -> list[str]:
            raise RuntimeError("r2 down")

    app.state.storage = BrokenStorage()
    try:
        await video_worker.recover()
        await video_worker.join()
    finally:
        app.state.storage = original

    assert (await refresh(db_session, exercise)).video_status == "failed"


def test_ffmpeg_args_match_spec() -> None:
    args = ffmpeg_args(Path("/tmp/in"), Path("/tmp/out.mp4"))

    assert " ".join(args) == (
        "-y -i /tmp/in -vf scale='min(1280,iw)':'min(1280,ih)':force_original_aspect_ratio="
        "decrease:force_divisible_by=2,fps=30 -c:v libx264 -preset veryfast -crf 23 "
        "-maxrate 2500k -bufsize 5000k -profile:v high -pix_fmt yuv420p -movflags +faststart "
        "-c:a aac -b:a 96k -threads 1 /tmp/out.mp4"
    )


async def test_ffmpeg_timeout_kills_process(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    binary = fake_binary(tmp_path, "exec sleep 30")
    monkeypatch.setattr(video_transcode.shutil, "which", lambda name: binary)
    monkeypatch.setattr(video_transcode, "TRANSCODE_TIMEOUT_SECONDS", 0.3)
    started = time.monotonic()

    with pytest.raises(TranscodeError, match="vaqt"):
        await run_ffmpeg(tmp_path / "in", tmp_path / "out.mp4")

    assert time.monotonic() - started < 5


async def test_ffmpeg_nonzero_exit_raises_with_stderr(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    binary = fake_binary(tmp_path, "echo 'Invalid data found' >&2; exit 3")
    monkeypatch.setattr(video_transcode.shutil, "which", lambda name: binary)

    with pytest.raises(TranscodeError, match="Invalid data found"):
        await run_ffmpeg(tmp_path / "in", tmp_path / "out.mp4")


@pytest.mark.skipif(shutil.which("ffmpeg") is None, reason="ffmpeg o'rnatilmagan")
@pytest.mark.parametrize(
    ("size", "expected"), [("1920x1080", (1280, 720)), ("1081x1921", (720, 1280))]
)
async def test_real_ffmpeg_compresses_to_720p_faststart(
    tmp_path: Path, size: str, expected: tuple[int, int]
) -> None:
    source = tmp_path / "in.mp4"
    target = tmp_path / "out.mp4"
    process = await asyncio.create_subprocess_exec(
        "ffmpeg",
        "-y",
        "-f",
        "lavfi",
        "-i",
        f"testsrc2=size={size}:rate=30",
        "-f",
        "lavfi",
        "-i",
        "sine=frequency=440",
        "-t",
        "2",
        str(source),
        stdout=asyncio.subprocess.DEVNULL,
        stderr=asyncio.subprocess.DEVNULL,
    )
    assert await process.wait() == 0

    await run_ffmpeg(source, target)

    probe = await asyncio.create_subprocess_exec(
        "ffprobe",
        "-v",
        "error",
        "-select_streams",
        "v:0",
        "-show_entries",
        "stream=width,height,codec_name",
        "-of",
        "csv=p=0",
        str(target),
        stdout=asyncio.subprocess.PIPE,
    )
    output, _ = await probe.communicate()
    codec, width, height = output.decode().strip().split(",")
    assert codec == "h264"
    assert (int(width), int(height)) == expected
    data = await asyncio.to_thread(target.read_bytes)
    assert data.index(b"moov") < data.index(b"mdat")
