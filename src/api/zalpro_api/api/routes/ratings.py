from fastapi import APIRouter, Response
from sqlalchemy import delete, func, select
from sqlalchemy.dialects.postgresql import insert

from zalpro_api.api.deps import OwnerUser, SessionDep
from zalpro_api.models import Rating
from zalpro_api.schemas.rating import RatingIn, RatingOut
from zalpro_api.services import users as users_service

router = APIRouter(prefix="/ratings", tags=["ratings"])


@router.get("", response_model=list[RatingOut])
async def list_ratings(actor: OwnerUser, session: SessionDep) -> list[Rating]:
    return list((await session.scalars(select(Rating).order_by(Rating.trainer_id))).all())


@router.put("/{trainer_id}", response_model=RatingOut)
async def save_rating(
    trainer_id: str, body: RatingIn, actor: OwnerUser, session: SessionDep
) -> Rating:
    await users_service.get_trainer_or_404(session, trainer_id)
    values = {"trainer_id": trainer_id, **body.model_dump()}
    statement = insert(Rating).values(values)
    statement = statement.on_conflict_do_update(
        index_elements=[Rating.trainer_id],
        set_={
            "stars": statement.excluded.stars,
            "comment": statement.excluded.comment,
            "updated_at": func.now(),
        },
    ).returning(Rating)
    rating = (
        await session.execute(statement, execution_options={"populate_existing": True})
    ).scalar_one()
    await session.commit()
    return rating


@router.delete("/{trainer_id}", status_code=204)
async def delete_rating(trainer_id: str, actor: OwnerUser, session: SessionDep) -> Response:
    await session.execute(delete(Rating).where(Rating.trainer_id == trainer_id))
    await session.commit()
    return Response(status_code=204)
