import asyncio
import os
import random
import sys
import uuid
from datetime import UTC, date, datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from seed_dev import assert_local_database
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.config import Settings
from zalpro_api.db.session import create_engine, create_sessionmaker
from zalpro_api.models import CoinLedger, RepSession, User
from zalpro_api.services.game import EXERCISES, STREAK_BONUSES, reward, streak_length

MARK = 0x5EED << 112
ARCHETYPES = (
    ("elite", 0.08, 0.9, 3, 2),
    ("regular", 0.3, 0.6, 2, 1),
    ("casual", 0.3, 0.3, 1, 1),
    ("idle", 0.32, 0.0, 0, 0),
)
EXERCISE_WEIGHTS = (
    ("pushup", 5),
    ("squat", 4),
    ("situp", 3),
    ("lunge", 2),
    ("pullup", 1),
    ("shoulder", 1),
    ("auto", 1),
)
DAYS = 45


def session_id(counter: int) -> str:
    return uuid.UUID(int=MARK | counter).hex


def pick_archetype(rng: random.Random) -> tuple[str, float, float, int, int]:
    roll = rng.random()
    acc = 0.0
    for item in ARCHETYPES:
        acc += item[1]
        if roll < acc:
            return item
    return ARCHETYPES[-1]


def pick_exercise(rng: random.Random) -> str:
    keys, weights = zip(*EXERCISE_WEIGHTS, strict=True)
    return rng.choices(keys, weights)[0]


def reps_for(rng: random.Random, key: str, tier: str) -> int:
    base = {"pushup": 18, "squat": 30, "situp": 28, "lunge": 24, "pullup": 8, "shoulder": 22}.get(
        key, 25
    )
    scale = {"elite": 1.9, "regular": 1.2, "casual": 0.8}[tier]
    return max(4, min(95, round(base * scale * rng.uniform(0.7, 1.25))))


async def purge(session: AsyncSession) -> None:
    low = uuid.UUID(int=MARK).hex
    high = uuid.UUID(int=MARK | ((1 << 112) - 1)).hex
    ids = select(RepSession.id).where(RepSession.id.between(low, high))
    await session.execute(delete(CoinLedger).where(CoinLedger.ref_id.in_(ids)))
    await session.execute(delete(RepSession).where(RepSession.id.between(low, high)))


async def seed(session: AsyncSession) -> dict[str, int]:
    rng = random.Random(50)
    await purge(session)
    students = (
        (await session.execute(select(User).where(User.role == "user").order_by(User.id)))
        .scalars()
        .all()
    )
    today = datetime.now(UTC).date()
    counter = 0
    stats = {"students": 0, "sessions": 0, "flagged": 0}
    for student in students:
        tier, _, active, per_day, _ = pick_archetype(rng)
        if tier == "idle":
            continue
        stats["students"] += 1
        history: set[date] = set()
        for back in range(DAYS - 1, -1, -1):
            day = today - timedelta(days=back)
            if rng.random() > active:
                continue
            xp_today = 0
            for _ in range(rng.randint(1, per_day + 1)):
                key = pick_exercise(rng)
                rule = EXERCISES[key]
                reps = reps_for(rng, key, tier)
                duration = max(30, round(reps * rng.uniform(1.8, 3.2)))
                flagged = rng.random() < 0.02
                if flagged:
                    reps = min(100, reps + 60)
                    duration = max(5, round(reps * 0.3))
                started = datetime(
                    day.year, day.month, day.day, rng.randint(6, 21), rng.randint(0, 59), tzinfo=UTC
                )
                if started > datetime.now(UTC) - timedelta(minutes=30):
                    started -= timedelta(hours=3)
                counter += 1
                sid = session_id(counter)
                xp = 0 if flagged else reward(rule, reps, xp_today)
                xp_today += xp
                session.add(
                    RepSession(
                        id=sid,
                        user_id=student.id,
                        exercise_key=key,
                        reps=reps,
                        duration_s=duration,
                        visibility_pct=rng.randint(78, 100),
                        started_at=started,
                        coins=0,
                        xp=xp,
                        status="flagged" if flagged else "valid",
                    )
                )
                if flagged:
                    stats["flagged"] += 1
                    continue
                stats["sessions"] += 1
                if day not in history:
                    history.add(day)
                    bonus = STREAK_BONUSES.get(streak_length(history, day), 0)
                    if bonus:
                        session.add(
                            CoinLedger(user_id=student.id, delta=bonus, reason="streak", ref_id=sid)
                        )
        await session.flush()
    await session.commit()
    return stats


async def main() -> None:
    settings = Settings()
    assert_local_database(settings.database_url, os.environ.get("SEED_ALLOW_HOST"))
    engine = create_engine(settings.database_url)
    try:
        async with create_sessionmaker(engine)() as session:
            print(await seed(session))
    finally:
        await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
