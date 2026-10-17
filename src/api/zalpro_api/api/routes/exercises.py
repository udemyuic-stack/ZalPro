import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Response
from sqlalchemy import delete, select

from zalpro_api.api.deps import (
    CurrentUser,
    SessionDep,
    SettingsDep,
    StaffUser,
    StorageDep,
    VideoWorkerDep,
)
from zalpro_api.models import Exercise, User
from zalpro_api.schemas.exercise import ExerciseCreate, ExerciseIn, ExerciseOut
from zalpro_api.schemas.exercise_video import (
    VideoConfirmIn,
    VideoConfirmOut,
    VideoUploadIn,
    VideoUploadOut,
    VideoUrlOut,
)
from zalpro_api.services import catalog, permissions
from zalpro_api.services import exercise_videos as videos_service

router = APIRouter(prefix="/exercises", tags=["exercises"])


def to_out(exercise: Exercise, actor: User) -> ExerciseOut:
    out = ExerciseOut.model_validate(exercise).model_copy(
        update={"video_status": videos_service.video_status_of(exercise)}
    )
    if permissions.can_see_exercise_level(actor):
        return out
    return out.model_copy(update={"level": ""})


@router.get("", response_model=list[ExerciseOut])
async def list_exercises(actor: CurrentUser, session: SessionDep) -> list[ExerciseOut]:
    exercises = await session.scalars(select(Exercise).order_by(Exercise.name, Exercise.id))
    return [to_out(exercise, actor) for exercise in exercises.all()]


@router.get("/{exercise_id}", response_model=ExerciseOut)
async def read_exercise(exercise_id: str, actor: CurrentUser, session: SessionDep) -> ExerciseOut:
    return to_out(await catalog.get_exercise_or_404(session, exercise_id), actor)


@router.post("", response_model=ExerciseOut, status_code=201)
async def create_exercise(
    body: ExerciseCreate, actor: StaffUser, session: SessionDep
) -> ExerciseOut:
    exercise = Exercise(
        id=uuid.uuid4().hex,
        created_by=actor.id,
        created_at=datetime.now(UTC),
        **body.model_dump(),
    )
    session.add(exercise)
    await session.commit()
    return to_out(exercise, actor)


@router.put("/{exercise_id}", response_model=ExerciseOut)
async def update_exercise(
    exercise_id: str, body: ExerciseIn, actor: StaffUser, session: SessionDep
) -> ExerciseOut:
    exercise = await catalog.get_exercise_or_404(session, exercise_id)
    for field, value in body.model_dump().items():
        setattr(exercise, field, value)
    await session.commit()
    return to_out(exercise, actor)


@router.delete("/{exercise_id}", status_code=204)
async def delete_exercise(
    exercise_id: str, actor: StaffUser, session: SessionDep, storage: StorageDep
) -> Response:
    exercise = await catalog.get_exercise_or_404(session, exercise_id)
    video_key = exercise.video_key
    await session.execute(delete(Exercise).where(Exercise.id == exercise_id))
    await session.commit()
    if video_key is not None:
        await storage.delete(video_key)
    return Response(status_code=204)


@router.post("/{exercise_id}/video/upload-url", response_model=VideoUploadOut, status_code=201)
async def create_video_upload_url(
    exercise_id: str,
    body: VideoUploadIn,
    actor: StaffUser,
    session: SessionDep,
    storage: StorageDep,
    settings: SettingsDep,
) -> VideoUploadOut:
    exercise = await catalog.get_exercise_or_404(session, exercise_id)
    return await videos_service.create_upload(
        storage, exercise, body.size, settings.video_url_seconds
    )


@router.put("/{exercise_id}/video", response_model=VideoConfirmOut, status_code=202)
async def confirm_video(
    exercise_id: str,
    body: VideoConfirmIn,
    actor: StaffUser,
    session: SessionDep,
    storage: StorageDep,
    worker: VideoWorkerDep,
) -> VideoConfirmOut:
    exercise = await catalog.get_exercise_or_404(session, exercise_id)
    return await videos_service.confirm_upload(session, storage, worker, exercise, body.key)


@router.get("/{exercise_id}/video", response_model=VideoUrlOut)
async def read_video_url(
    exercise_id: str,
    actor: CurrentUser,
    session: SessionDep,
    storage: StorageDep,
    settings: SettingsDep,
) -> VideoUrlOut:
    exercise = await catalog.get_exercise_or_404(session, exercise_id)
    return await videos_service.read_url(storage, exercise, settings.video_url_seconds)


@router.delete("/{exercise_id}/video", status_code=204)
async def delete_video(
    exercise_id: str, actor: StaffUser, session: SessionDep, storage: StorageDep
) -> Response:
    exercise = await catalog.get_exercise_or_404(session, exercise_id)
    await videos_service.remove_video(session, storage, exercise)
    return Response(status_code=204)
