import uuid

from fastapi import APIRouter, Response

from zalpro_api.api.deps import CurrentUser, SessionDep, SettingsDep, StorageDep
from zalpro_api.schemas.photo import PhotoOut, PhotoUploadIn, PhotoUploadOut
from zalpro_api.services import permissions
from zalpro_api.services import photos as photos_service
from zalpro_api.services import users as users_service

router = APIRouter(prefix="/users", tags=["photos"])


@router.post("/{user_id}/photos/upload-url", response_model=PhotoUploadOut, status_code=201)
async def create_upload_url(
    user_id: str,
    body: PhotoUploadIn,
    actor: CurrentUser,
    session: SessionDep,
    storage: StorageDep,
    settings: SettingsDep,
) -> PhotoUploadOut:
    permissions.ensure_can_write_photos(actor, user_id)
    await users_service.get_user_or_404(session, user_id)
    return await photos_service.create_upload(
        session, storage, user_id, body.weight, body.size, settings.photo_url_seconds
    )


@router.get("/{user_id}/photos", response_model=list[PhotoOut])
async def list_photos(
    user_id: str,
    actor: CurrentUser,
    session: SessionDep,
    storage: StorageDep,
    settings: SettingsDep,
) -> list[PhotoOut]:
    owner = await users_service.get_user_or_404(session, user_id)
    permissions.ensure_can_read_photos(actor, owner)
    return await photos_service.list_photos(session, storage, user_id, settings.photo_url_seconds)


@router.delete("/{user_id}/photos/{photo_id}", status_code=204)
async def delete_photo(
    user_id: str,
    photo_id: uuid.UUID,
    actor: CurrentUser,
    session: SessionDep,
    storage: StorageDep,
) -> Response:
    permissions.ensure_can_write_photos(actor, user_id)
    await photos_service.delete_photo(session, storage, user_id, photo_id)
    return Response(status_code=204)
