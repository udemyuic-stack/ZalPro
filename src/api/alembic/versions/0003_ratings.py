from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0003"
down_revision: str | None = "0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "ratings",
        sa.Column("trainer_id", sa.Text(), nullable=False),
        sa.Column("stars", sa.Integer(), nullable=False),
        sa.Column("comment", sa.Text(), server_default="", nullable=False),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint("stars between 1 and 5", name=op.f("ck_ratings_stars_range")),
        sa.ForeignKeyConstraint(
            ["trainer_id"],
            ["users.id"],
            name=op.f("fk_ratings_trainer_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("trainer_id", name=op.f("pk_ratings")),
    )


def downgrade() -> None:
    op.drop_table("ratings")
