import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.errors import conflict, forbidden, not_found
from zalpro_api.models import Announcement, User
from zalpro_api.models.announcement import MAX_ACTIVE_PER_AUTHOR, MAX_LISTED
from zalpro_api.schemas.announcement import AnnouncementIn, AnnouncementOut
from zalpro_api.services import pagination, permissions


def active_filter(now: datetime):
    return or_(Announcement.expires_at.is_(None), Announcement.expires_at > now)


def visibility_filter(actor: User):
    if permissions.is_owner(actor):
        return None
    if permissions.is_staff(actor):
        return or_(Announcement.trainer_id.is_(None), Announcement.author_id == actor.id)
    if actor.trainer_id is None:
        return Announcement.trainer_id.is_(None)
    return or_(Announcement.trainer_id.is_(None), Announcement.trainer_id == actor.trainer_id)


def to_out(row: Announcement, author_name: str) -> AnnouncementOut:
    return AnnouncementOut(
        id=str(row.id),
        title=row.title,
        body=row.body,
        audience="all" if row.trainer_id is None else "students",
        author_id=row.author_id,
        author_name=author_name,
        created_at=row.created_at,
        expires_at=row.expires_at,
    )


ANNOUNCEMENT_KEYS = (
    pagination.Key(Announcement.created_at, "created_at", datetime, desc=True),
    pagination.Key(Announcement.id, "id", uuid.UUID, desc=True),
)


def active_statement(actor: User):
    statement = (
        select(Announcement, User.name)
        .join(User, User.id == Announcement.author_id)
        .where(active_filter(datetime.now(UTC)))
        .order_by(Announcement.created_at.desc(), Announcement.id.desc())
    )
    scope = visibility_filter(actor)
    if scope is not None:
        statement = statement.where(scope)
    return statement


async def list_active(session: AsyncSession, actor: User) -> list[AnnouncementOut]:
    rows = (await session.execute(active_statement(actor).limit(MAX_LISTED))).all()
    return [to_out(row, name) for row, name in rows]


async def list_active_page(
    session: AsyncSession, actor: User, page: pagination.PageParams
) -> tuple[list[AnnouncementOut], str | None]:
    rows, cursor = await pagination.fetch_page(
        session, active_statement(actor), ANNOUNCEMENT_KEYS, page, entity=lambda row: row[0]
    )
    return [to_out(row, name) for row, name in rows], cursor


async def create(session: AsyncSession, actor: User, body: AnnouncementIn) -> AnnouncementOut:
    if body.audience == "all" and not permissions.is_owner(actor):
        raise forbidden()
    now = datetime.now(UTC)
    active = await session.scalar(
        select(func.count())
        .select_from(Announcement)
        .where(Announcement.author_id == actor.id, active_filter(now))
    )
    if (active or 0) >= MAX_ACTIVE_PER_AUTHOR:
        raise conflict("too_many_announcements", "Faol e'lonlar soni chegaraga yetdi")
    row = Announcement(
        id=uuid.uuid4(),
        title=body.title,
        body=body.body,
        author_id=actor.id,
        trainer_id=None if body.audience == "all" else actor.id,
        expires_at=None
        if body.expires_in_days is None
        else now + timedelta(days=body.expires_in_days),
    )
    session.add(row)
    await session.commit()
    await session.refresh(row)
    return to_out(row, actor.name)


async def delete(session: AsyncSession, actor: User, announcement_id: uuid.UUID) -> None:
    row = await session.get(Announcement, announcement_id)
    if row is None:
        raise not_found()
    if not permissions.is_owner(actor) and row.author_id != actor.id:
        raise forbidden()
    await session.delete(row)
    await session.commit()
