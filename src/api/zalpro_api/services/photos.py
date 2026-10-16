import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.errors import not_found
from zalpro_api.models import Photo
from zalpro_api.schemas.photo import PhotoOut, PhotoUploadOut
from zalpro_api.services.storage import Storage, build_key


async def create_upload(
    session: AsyncSession,
    storage: Storage,
    user_id: str,
    weight: float,
    size: int,
    expires: int,
) -> PhotoUploadOut:
    photo = Photo(
        id=uuid.uuid4(),
        user_id=user_id,
        key=build_key("image", user_id),
        taken_at=datetime.now(UTC),
        weight=weight,
        size=size,
    )
    session.add(photo)
    try:
        await session.flush()
        upload_url = await storage.presign_put(photo.key, size, expires)
        await session.commit()
    except BaseException:
        await session.rollback()
        raise
    return PhotoUploadOut(photo_id=photo.id, upload_url=upload_url, expires_in=expires)


async def list_photos(
    session: AsyncSession, storage: Storage, user_id: str, expires: int
) -> list[PhotoOut]:
    result = await session.scalars(
        select(Photo)
        .where(Photo.user_id == user_id)
        .order_by(Photo.taken_at.desc(), Photo.id.desc())
    )
    return [
        PhotoOut(
            id=photo.id,
            taken_at=photo.taken_at,
            weight=photo.weight,
            size=photo.size,
            download_url=await storage.presign_get(photo.key, expires),
        )
        for photo in result.all()
    ]


async def delete_photo(
    session: AsyncSession, storage: Storage, user_id: str, photo_id: uuid.UUID
) -> None:
    photo = await session.scalar(
        select(Photo).where(Photo.id == photo_id, Photo.user_id == user_id)
    )
    if photo is None:
        raise not_found("Rasm topilmadi")
    key = photo.key
    await session.delete(photo)
    await session.commit()
    await storage.delete(key)
