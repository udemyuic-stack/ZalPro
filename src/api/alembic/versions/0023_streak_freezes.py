from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0023"
down_revision: str | None = "0022"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "streak_freezes",
        sa.Column(
            "user_id", sa.Text(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("week_start", sa.Date(), nullable=False),
        sa.Column("granted_by", sa.Text(), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.PrimaryKeyConstraint("user_id", "week_start", name="pk_streak_freezes"),
        sa.CheckConstraint(
            "extract(isodow from week_start) = 1", name="ck_streak_freezes_week_start_monday"
        ),
    )


def downgrade() -> None:
    op.drop_table("streak_freezes")
