import asyncio
import os
import random
import sys
import uuid
from dataclasses import dataclass, field
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from seed_dev import GYM_ONE_NAME, assert_local_database, new_id
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.config import Settings
from zalpro_api.core.security import hash_password
from zalpro_api.db.session import create_engine, create_sessionmaker
from zalpro_api.models import (
    Attendance,
    Day,
    Gym,
    Membership,
    Order,
    Product,
    Subscription,
    User,
    Weight,
)

TZ = ZoneInfo("Asia/Tashkent")
DEMO_PASSWORD = "Demo-Analytics-2468"
PHONE_PREFIX = "99891"
PRODUCT_PREFIX = "Demo: "
STUDENT_COUNT = 90
ORDER_COUNT = 700
ORDER_DAYS = 120
COST_WINDOW_DAYS = 45
BATCH = 2000

FIRST_NAMES_MALE = [
    "Jasur",
    "Sardor",
    "Dilshod",
    "Bobur",
    "Aziz",
    "Otabek",
    "Sherzod",
    "Javohir",
    "Rustam",
    "Timur",
    "Akmal",
    "Behzod",
    "Farhod",
    "Ulugbek",
    "Nodir",
    "Islom",
]
FIRST_NAMES_FEMALE = [
    "Malika",
    "Nilufar",
    "Dilnoza",
    "Madina",
    "Zilola",
    "Shahnoza",
    "Gulnora",
    "Sevara",
    "Nargiza",
    "Kamola",
    "Feruza",
    "Lola",
]
LAST_NAMES_MALE = [
    "Karimov",
    "Rahimov",
    "Tursunov",
    "Abdullayev",
    "Yusupov",
    "Ergashev",
    "Qodirov",
    "Nazarov",
    "Saidov",
    "Mirzayev",
]
LAST_NAMES_FEMALE = [name.removesuffix("ov").removesuffix("ev") + "a" for name in LAST_NAMES_MALE]

WEEKDAY_WEIGHTS = (1.4, 1.4, 1.4, 1.4, 1.0, 0.9, 0.35)
ORDER_WEEKDAY_WEIGHTS = (1.3, 1.3, 1.3, 1.3, 1.0, 0.9, 0.4)

PERIODS = (
    (1, 0, 350000),
    (3, 0, 900000),
    (0, 10, 150000),
)
PERIOD_WEIGHTS = (0.6, 0.25, 0.15)

EXERCISES = [f"e{i}" for i in range(1, 13)]


@dataclass(frozen=True)
class ProductSpec:
    name: str
    category: str
    price: int
    cost: int
    weight: float
    stock: int


PRODUCTS: tuple[ProductSpec, ...] = (
    ProductSpec("Demo: Suv 0.5L", "Boshqa", 4000, 2500, 30, 200),
    ProductSpec("Demo: Energetik", "Boshqa", 15000, 10500, 16, 150),
    ProductSpec("Demo: Protein bar", "Boshqa", 18000, 12500, 14, 120),
    ProductSpec("Demo: Protein 2 kg", "Protein", 420000, 310000, 3, 40),
    ProductSpec("Demo: Gainer 3 kg", "Gainer", 380000, 285000, 1.5, 30),
    ProductSpec("Demo: Kreatin 300 g", "Kreatin", 190000, 140000, 3.5, 60),
    ProductSpec("Demo: L-Karnitin", "L-Karnitin", 160000, 120000, 2, 50),
    ProductSpec("Demo: Shaker", "Suv idishlari", 45000, 30000, 4, 80),
    ProductSpec("Demo: Futbolka", "Forma", 120000, 85000, 1, 60),
    ProductSpec("Demo: Qo'lqop", "Anjomlar", 65000, 45000, 1.2, 50),
    ProductSpec("Demo: Belbog'", "Anjomlar", 180000, 130000, 0.6, 25),
    ProductSpec("Demo: Tizza bog'ichi", "Anjomlar", 85000, 60000, 0.8, 35),
)
MULTI_QTY = {"Demo: Suv 0.5L": 4, "Demo: Protein bar": 4, "Demo: Energetik": 2}


@dataclass
class Student:
    user: User
    archetype: str
    trainer_index: int | None
    created: date
    first_visit: date
    last_visit: date
    sub_end: date | None = None
    visit_days: list[date] = field(default_factory=list)


def at(day: date, hour: int, minute: int = 0) -> datetime:
    return datetime(day.year, day.month, day.day, hour, minute, tzinfo=TZ).astimezone(UTC)


def today_local() -> date:
    return datetime.now(TZ).date()


def pick_archetypes(rng: random.Random) -> list[str]:
    counts = {"regular": 32, "declining": 14, "churned": 18, "sporadic": 13, "new": 13}
    items = [name for name, count in counts.items() for _ in range(count)]
    rng.shuffle(items)
    return items[:STUDENT_COUNT]


def weighted_days(rng: random.Random, days: list[date], count: int) -> list[date]:
    pool = list(days)
    chosen: list[date] = []
    for _ in range(min(count, len(pool))):
        weights = [WEEKDAY_WEIGHTS[d.weekday()] for d in pool]
        pick = rng.choices(range(len(pool)), weights=weights)[0]
        chosen.append(pool.pop(pick))
    return chosen


def visits_between(
    rng: random.Random, start: date, end: date, low: int, high: int, today: date
) -> list[date]:
    if end < start:
        return []
    result: list[date] = []
    monday = start - timedelta(days=start.weekday())
    while monday <= end:
        week = [
            monday + timedelta(days=i)
            for i in range(7)
            if start <= monday + timedelta(days=i) <= min(end, today)
        ]
        if week:
            result.extend(weighted_days(rng, week, rng.randint(low, high)))
        monday += timedelta(days=7)
    return sorted(result)


def build_visits(rng: random.Random, student: Student, today: date) -> list[date]:
    archetype = student.archetype
    start = student.first_visit
    if archetype == "regular":
        return visits_between(rng, start, today, 3, 5, today)
    if archetype == "declining":
        drop = student.last_visit
        early = visits_between(rng, start, drop, 3, 5, today)
        late = visits_between(rng, drop + timedelta(days=1), today, 0, 1, today)
        return early + late
    if archetype == "churned":
        return visits_between(rng, start, student.last_visit, 3, 5, today)
    if archetype == "sporadic":
        return visits_between(rng, start, today, 1, 2, today)
    return visits_between(rng, start, today, 2, 4, today)


def build_subscriptions(
    rng: random.Random, student: Student, today: date, expiring: bool
) -> list[tuple[date, int, int, int, date]]:
    for _ in range(80):
        periods: list[tuple[date, int, int, int, date]] = []
        cursor = student.created
        while True:
            months, days, price = rng.choices(PERIODS, weights=PERIOD_WEIGHTS)[0]
            if student.archetype == "new":
                months, days, price = (1, 0, 350000) if rng.random() < 0.7 else (0, 10, 150000)
            end = cursor + timedelta(days=months * 30 + days)
            periods.append((cursor, months, days, price, end))
            cursor = end
            if student.archetype == "churned":
                if cursor > student.last_visit:
                    break
            elif cursor > today:
                break
        final_end = periods[-1][4]
        if student.archetype == "churned":
            if final_end < today - timedelta(days=1):
                return periods
        elif expiring:
            if today <= final_end <= today + timedelta(days=7):
                return periods
        elif student.archetype == "new":
            if final_end >= today:
                return periods
        elif final_end > today + timedelta(days=7):
            return periods
    return periods


def weight_series(
    rng: random.Random, student: Student, today: date
) -> list[tuple[datetime, float]]:
    goal = student.user.goal
    current = student.user.weight
    end = student.last_visit if student.archetype == "churned" else today
    day = student.created
    series: list[tuple[datetime, float]] = []
    while day <= end:
        series.append((at(day, 9, rng.randint(0, 59)), round(current, 1)))
        if goal == "lose":
            step = -rng.uniform(0.3, 0.6)
        elif goal == "gain":
            step = rng.uniform(0.2, 0.4)
        else:
            step = 0.0
        current = max(40.0, current + step + rng.gauss(0, 0.25))
        day += timedelta(days=7)
    return series


def hard_probability(trainer_index: int | None) -> float:
    if trainer_index == 0:
        return 0.15
    if trainer_index == 1:
        return 0.35
    return 0.20


def make_student(
    rng: random.Random,
    index: int,
    archetype: str,
    today: date,
    gym_id: str,
    trainers: list[User],
    password_hash: str,
) -> Student:
    female = rng.random() < 0.4
    if female:
        name = f"{rng.choice(FIRST_NAMES_FEMALE)} {rng.choice(LAST_NAMES_FEMALE)}"
    else:
        name = f"{rng.choice(FIRST_NAMES_MALE)} {rng.choice(LAST_NAMES_MALE)}"
    if archetype == "new":
        created = today - timedelta(days=rng.randint(1, 29))
    elif archetype == "churned":
        created = today - timedelta(days=rng.randint(80, 150))
    else:
        created = today - timedelta(days=rng.randint(35, 150))
    trainer_index: int | None = None
    if rng.random() < 0.7:
        trainer_index = 0 if rng.random() < 0.6 else 1
    goal = rng.choices(["lose", "gain", "maintain"], weights=[0.45, 0.4, 0.15])[0]
    height = round(rng.uniform(155, 172) if female else rng.uniform(168, 192), 1)
    weight = round(rng.uniform(50, 78) if female else rng.uniform(65, 105), 1)
    user = User(
        id=new_id(),
        name=name,
        phone=f"{PHONE_PREFIX}{1000000 + index * 7919 % 8999999:07d}",
        password_hash=password_hash,
        role="user",
        gender="female" if female else "male",
        age=rng.randint(18, 45),
        height=height,
        weight=weight,
        activity=rng.choice([1.375, 1.55, 1.725]),
        metabolism=rng.choice(["slow", "normal", "fast"]),
        goal=goal,
        gym_id=gym_id,
        trainer_id=trainers[trainer_index].id if trainer_index is not None else None,
        created_at=at(created, rng.randint(9, 20), rng.randint(0, 59)),
    )
    first_visit = created + timedelta(days=rng.randint(0, 2))
    if archetype == "churned":
        last_visit = today - timedelta(days=rng.randint(21, 56))
    elif archetype == "declining":
        last_visit = today - timedelta(days=rng.randint(14, 21))
    else:
        last_visit = today
    return Student(user, archetype, trainer_index, created, first_visit, last_visit)


async def purge(session: AsyncSession) -> None:
    ids = list(await session.scalars(select(User.id).where(User.phone.like(f"{PHONE_PREFIX}%"))))
    product_ids = list(
        await session.scalars(select(Product.id).where(Product.name.like(f"{PRODUCT_PREFIX}%")))
    )
    if ids:
        await session.execute(delete(Order).where(Order.client_id.in_(ids)))
    if product_ids:
        await session.execute(delete(Order).where(Order.product_id.in_(product_ids)))
    if ids:
        await session.execute(delete(User).where(User.id.in_(ids)))
    if product_ids:
        await session.execute(delete(Product).where(Product.id.in_(product_ids)))
    await session.flush()


async def flush_batches(session: AsyncSession, rows: list) -> None:
    for offset in range(0, len(rows), BATCH):
        session.add_all(rows[offset : offset + BATCH])
        await session.flush()


def build_orders(
    rng: random.Random,
    students: list[Student],
    products: list[Product],
    gym_id: str,
    barmen_id: str,
    today: date,
) -> list[Order]:
    eligible = [s for s in students if s.visit_days]
    by_name = {p.name: p for p in products}
    popularity = [spec.weight for spec in PRODUCTS]
    spec_by_name = {spec.name: spec for spec in PRODUCTS}
    now = datetime.now(UTC)
    cost_cutoff = now - timedelta(days=COST_WINDOW_DAYS)
    days = [today - timedelta(days=i) for i in range(ORDER_DAYS)]
    day_weights = [ORDER_WEEKDAY_WEIGHTS[d.weekday()] for d in days]
    orders: list[Order] = []
    for _ in range(ORDER_COUNT):
        day = rng.choices(days, weights=day_weights)[0]
        active = [s for s in eligible if s.first_visit <= day <= max(s.last_visit, s.first_visit)]
        if not active:
            active = eligible
        student = rng.choice(active)
        spec = rng.choices(PRODUCTS, weights=popularity)[0]
        product = by_name[spec.name]
        hour = (
            rng.randint(16, 20)
            if rng.random() < 0.8
            else rng.choice([8, 9, 10, 11, 12, 13, 14, 15, 21])
        )
        created = at(day, hour, rng.randint(0, 59))
        if created > now:
            created = now - timedelta(minutes=rng.randint(5, 600))
        max_qty = MULTI_QTY.get(spec.name, 2 if spec.price < 100000 else 1)
        qty = rng.randint(1, max_qty)
        if spec_by_name[spec.name].price >= 100000:
            qty = 1 if rng.random() < 0.9 else 2
        age_days = (now - created).days
        roll = rng.random()
        if age_days <= 7 and roll < 0.7:
            status = "new"
        elif roll < 0.04:
            status = "canceled"
        else:
            status = "given"
        given_at = None
        updated_at = None
        given_by = ""
        if status == "given":
            given_at = min(created + timedelta(minutes=rng.randint(3, 180)), now)
            updated_at = given_at
            given_by = barmen_id
        elif status == "canceled":
            updated_at = created + timedelta(minutes=rng.randint(5, 120))
        cost = None
        if status == "given" and given_at is not None and given_at >= cost_cutoff:
            cost = product.cost_price
        orders.append(
            Order(
                id=new_id(),
                client_id=student.user.id,
                client_name=student.user.name,
                client_phone=student.user.phone,
                trainer_id=student.user.trainer_id or "",
                gym_id=gym_id,
                product_id=product.id,
                product_name=product.name,
                category=product.category,
                price=product.price,
                cost_price=cost,
                currency="UZS",
                qty=qty,
                status=status,
                created_at=created,
                updated_at=updated_at,
                given_by=given_by,
                given_at=given_at,
            )
        )
    return orders


async def seed(session: AsyncSession) -> dict[str, int]:
    rng = random.Random(42)
    today = today_local()
    gym = await session.scalar(select(Gym).where(Gym.name == GYM_ONE_NAME))
    if gym is None:
        raise SystemExit(f"Gym {GYM_ONE_NAME!r} not found; run seed_dev.py first.")
    trainer_two = await session.scalar(select(User).where(User.phone == "998900000002"))
    trainer_three = await session.scalar(select(User).where(User.phone == "998900000003"))
    barmen = await session.scalar(select(User).where(User.phone == "998900000004"))
    if trainer_two is None or trainer_three is None or barmen is None:
        raise SystemExit("Dev accounts missing; run seed_dev.py first.")
    trainers = [trainer_two, trainer_three]

    await purge(session)

    password_hash = await hash_password(DEMO_PASSWORD)
    archetypes = pick_archetypes(rng)
    students = [
        make_student(rng, i, archetype, today, gym.id, trainers, password_hash)
        for i, archetype in enumerate(archetypes)
    ]
    session.add_all([s.user for s in students])
    await session.flush()

    products = [
        Product(
            id=new_id(),
            category=spec.category,
            name=spec.name,
            note="Demo analitika mahsuloti",
            price=spec.price,
            cost_price=spec.cost,
            stock=spec.stock,
            currency="UZS",
            active=True,
        )
        for spec in PRODUCTS
    ]
    session.add_all(products)
    await session.flush()

    marker_ids = [barmen.id, trainer_two.id, trainer_three.id]
    active_pool = [s for s in students if s.archetype in ("regular", "declining")]
    expiring_ids = {s.user.id for s in rng.sample(active_pool, 8)}

    subscriptions: list[Subscription] = []
    memberships: list[Membership] = []
    attendance: list[Attendance] = []
    days_rows: list[Day] = []
    weights: list[Weight] = []

    for student in students:
        user = student.user
        periods = build_subscriptions(rng, student, today, user.id in expiring_ids)
        for start, months, days, price, _ in periods:
            subscriptions.append(
                Subscription(
                    id=new_id(),
                    user_id=user.id,
                    start_date=at(start, 10),
                    months=months,
                    days=days,
                    price=price,
                    currency="UZS",
                    paid_date=at(start, 10),
                )
            )
        start, months, days, price, end = periods[-1]
        student.sub_end = end
        expires = at(end, 23, 59)
        user.subscription_expires_at = expires
        memberships.append(
            Membership(
                user_id=user.id,
                name=user.name,
                gym_id=gym.id,
                months=months,
                days=days,
                price=price,
                currency="UZS",
                paid_date=at(start, 10),
                expires_at=expires,
            )
        )

        student.visit_days = [d for d in build_visits(rng, student, today) if d >= student.created]
        hard = hard_probability(student.trainer_index)
        for visit in student.visit_days:
            attendance.append(
                Attendance(
                    user_id=user.id,
                    day=visit,
                    present=True,
                    marked_by=rng.choice(marker_ids),
                    marked_at=at(visit, rng.randint(16, 20), rng.randint(0, 59)),
                )
            )
            done: list[str] = []
            feedback = None
            if rng.random() < 0.7:
                done = rng.sample(EXERCISES, rng.randint(3, 6))
                if rng.random() < 0.6:
                    roll = rng.random()
                    if roll < hard:
                        feedback = 3
                    elif roll < hard + (1 - hard) * 0.35:
                        feedback = 1
                    else:
                        feedback = 2
            days_rows.append(
                Day(
                    user_id=user.id,
                    day=visit,
                    gym_started=True,
                    gym_done=done,
                    feedback=feedback,
                )
            )

        series = weight_series(rng, student, today)
        for moment, value in series:
            weights.append(Weight(id=uuid.uuid4(), user_id=user.id, date=moment, weight=value))
        if series:
            user.last_weigh_in = series[-1][0]
            user.weight = series[-1][1]

    await flush_batches(session, subscriptions)
    await flush_batches(session, memberships)
    await flush_batches(session, attendance)
    await flush_batches(session, days_rows)
    await flush_batches(session, weights)

    orders = build_orders(rng, students, products, gym.id, barmen.id, today)
    await flush_batches(session, orders)
    await session.commit()

    status_counts: dict[str, int] = {}
    for order in orders:
        status_counts[order.status] = status_counts.get(order.status, 0) + 1
    return {
        "students": len(students),
        "with_trainer": sum(1 for s in students if s.trainer_index is not None),
        "subscriptions": len(subscriptions),
        "memberships": len(memberships),
        "attendance": len(attendance),
        "days": len(days_rows),
        "weights": len(weights),
        "products": len(products),
        "orders": len(orders),
        **{f"orders_{k}": v for k, v in status_counts.items()},
    }


async def main() -> None:
    settings = Settings()
    assert_local_database(settings.database_url, os.environ.get("SEED_ALLOW_HOST"))
    engine = create_engine(settings.database_url)
    try:
        async with create_sessionmaker(engine)() as session:
            summary = await seed(session)
    finally:
        await engine.dispose()
    for key, value in summary.items():
        print(f"{key:<20}{value}")


if __name__ == "__main__":
    asyncio.run(main())
