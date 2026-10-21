from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0025"
down_revision: str | None = "0024"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "exercise_sets",
        sa.Column(
            "user_id", sa.Text(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("day", sa.Date(), nullable=False),
        sa.Column("exercise_id", sa.Text(), nullable=False),
        sa.Column("set_no", sa.Integer(), nullable=False),
        sa.Column("weight_kg", sa.Numeric(6, 2)),
        sa.Column("reps", sa.Integer()),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.PrimaryKeyConstraint("user_id", "day", "exercise_id", "set_no", name="pk_exercise_sets"),
        sa.CheckConstraint("set_no >= 1", name="ck_exercise_sets_set_no"),
        sa.CheckConstraint("reps is null or reps between 0 and 1000", name="ck_exercise_sets_reps"),
        sa.CheckConstraint(
            "weight_kg is null or weight_kg between 0 and 1000", name="ck_exercise_sets_weight"
        ),
    )


def downgrade() -> None:
    op.drop_table("exercise_sets")
