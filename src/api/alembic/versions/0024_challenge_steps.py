import uuid
from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0024"
down_revision: str | None = "0023"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

SEED = (
    ("pullup", 20, 20, "arms"),
    ("pushup", 10, 15, "chest"),
    ("squat", 20, 15, "legs"),
    ("pullup", 30, 30, "arms"),
    ("pushup", 25, 30, "chest"),
    ("squat", 50, 30, "legs"),
    ("pullup", 50, 50, "arms"),
    ("pushup", 50, 50, "chest"),
    ("squat", 100, 50, "legs"),
    ("pullup", 100, 100, "arms"),
    ("pushup", 100, 100, "chest"),
    ("squat", 200, 100, "legs"),
)


def upgrade() -> None:
    table = op.create_table(
        "challenge_steps",
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("exercise", sa.Text(), nullable=False),
        sa.Column("target", sa.Integer(), nullable=False),
        sa.Column("coins", sa.Integer(), nullable=False),
        sa.Column("muscle", sa.Text(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint("position >= 0", name="ck_challenge_steps_position_non_negative"),
        sa.CheckConstraint("target > 0", name="ck_challenge_steps_target_positive"),
        sa.CheckConstraint("coins >= 0", name="ck_challenge_steps_coins_non_negative"),
        sa.CheckConstraint(
            "muscle in ('arms', 'chest', 'legs')", name="ck_challenge_steps_muscle_valid"
        ),
        sa.UniqueConstraint("position", name="uq_challenge_steps_position"),
    )
    op.bulk_insert(
        table,
        [
            {
                "id": uuid.uuid4().hex,
                "position": position,
                "exercise": exercise,
                "target": target,
                "coins": coins,
                "muscle": muscle,
            }
            for position, (exercise, target, coins, muscle) in enumerate(SEED)
        ],
    )


def downgrade() -> None:
    op.drop_table("challenge_steps")
