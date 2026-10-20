import argparse
import asyncio
import os
import re
import sys
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select

from scripts.seed_dev import assert_local_database
from zalpro_api.core.config import Settings
from zalpro_api.db.session import create_engine, create_sessionmaker
from zalpro_api.models import Exercise
from zalpro_api.models.exercise import MAX_VIDEO_BYTES
from zalpro_api.services.storage import build_storage
from zalpro_api.services.video_transcode import VideoJob, VideoWorker, build_raw_key

VIDEO_SUFFIXES = frozenset({".mp4", ".m4v", ".mov", ".webm"})


def slug(name: str) -> str:
    plain = re.sub("[’'ʻ‘`ʼ\"«»]", "", name.lower())
    return re.sub(r"[^\w]+", "_", plain).strip("_")


def find_videos(folder: Path) -> dict[str, Path]:
    return {
        slug(path.stem): path
        for path in sorted(folder.iterdir())
        if path.suffix.lower() in VIDEO_SUFFIXES
    }


async def main() -> None:
    parser = argparse.ArgumentParser(
        description="Papkadagi videolarni mashqlarga biriktiradi. Fayl nomi mashq nomiga mos "
        "bo'lishi kerak: 'Otjimaniya.mp4', 'planka.mov', 'shtanga_bilan_yotib_siqish.mp4'."
    )
    parser.add_argument("folder", type=Path)
    parser.add_argument("--list", action="store_true", help="kutilayotgan fayl nomlarini chiqarish")
    args = parser.parse_args()

    settings = Settings()
    assert_local_database(settings.database_url, os.environ.get("SEED_ALLOW_HOST"))
    if not args.list and not settings.r2_configured:
        raise SystemExit("R2_* o'zgaruvchilari sozlanmagan: videolarni saqlash mumkin emas.")
    engine = create_engine(settings.database_url)
    sessionmaker = create_sessionmaker(engine)
    try:
        async with sessionmaker() as session:
            exercises = (await session.scalars(select(Exercise).order_by(Exercise.name))).all()
        if args.list:
            for exercise in exercises:
                print(f"{slug(exercise.name)}.mp4  <-  {exercise.name}")
            return
        videos = find_videos(args.folder)
        state = SimpleNamespace(
            sessionmaker=sessionmaker, storage=build_storage(settings), settings=settings
        )
        worker = VideoWorker(state)
        done = 0
        for exercise in exercises:
            path = videos.pop(slug(exercise.name), None)
            if path is None:
                continue
            if path.stat().st_size > MAX_VIDEO_BYTES:
                print(f"O'tkazildi (100 MB dan katta): {path.name}")
                continue
            key = build_raw_key(exercise.id)
            await state.storage.upload(path, key, "application/octet-stream")
            async with sessionmaker() as session:
                row = await session.get(Exercise, exercise.id)
                row.video_status = "processing"
                await session.commit()
            await worker.process(VideoJob(exercise.id, key))
            async with sessionmaker() as session:
                status = (await session.get(Exercise, exercise.id)).video_status
            print(f"{status:<10}{exercise.name}  <-  {path.name}")
            done += status == "ready"
        for leftover in videos.values():
            print(f"Mos mashq topilmadi: {leftover.name}")
        print(f"{done} ta video tayyor")
    finally:
        await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
