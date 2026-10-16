from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "0002"
down_revision: str | None = "0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "exercises",
        sa.Column("id", sa.Text(), nullable=False),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("muscle", sa.Text(), nullable=False),
        sa.Column("sets", sa.Text(), server_default="", nullable=False),
        sa.Column("tip", sa.Text(), server_default="", nullable=False),
        sa.Column("also", sa.ARRAY(sa.Text()), server_default="{}", nullable=False),
        sa.Column("video", sa.Text(), server_default="", nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("created_by", sa.Text(), nullable=False),
        sa.Column("base", sa.Text(), server_default="", nullable=False),
        sa.Column("level", sa.Text(), server_default="", nullable=False),
        sa.CheckConstraint(
            "level in ('', 'beginner', 'middle', 'pro')", name=op.f("ck_exercises_level_valid")
        ),
        sa.CheckConstraint(
            "muscle in ('chest', 'shoulders', 'biceps', 'triceps', 'forearms', 'abs', "
            "'back', 'traps', 'glutes', 'quads', 'hamstrings', 'calves')",
            name=op.f("ck_exercises_muscle_valid"),
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_exercises")),
    )
    op.create_table(
        "foods",
        sa.Column("id", sa.Text(), nullable=False),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("kcal", sa.Float(), server_default="0", nullable=False),
        sa.Column("protein", sa.Float(), server_default="0", nullable=False),
        sa.Column("fat", sa.Float(), server_default="0", nullable=False),
        sa.Column("carbs", sa.Float(), server_default="0", nullable=False),
        sa.Column("image", sa.Text(), server_default="", nullable=False),
        sa.CheckConstraint(
            "kcal >= 0 and protein >= 0 and fat >= 0 and carbs >= 0",
            name=op.f("ck_foods_nutrition_non_negative"),
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_foods")),
    )
    op.create_table(
        "plans",
        sa.Column("id", sa.Text(), nullable=False),
        sa.Column("title", sa.Text(), nullable=False),
        sa.Column("note", sa.Text(), server_default="", nullable=False),
        sa.Column("forbidden", sa.ARRAY(sa.Text()), server_default="{}", nullable=False),
        sa.Column(
            "meals", postgresql.JSONB(astext_type=sa.Text()), server_default="[]", nullable=False
        ),
        sa.Column(
            "week", postgresql.JSONB(astext_type=sa.Text()), server_default="{}", nullable=False
        ),
        sa.Column(
            "photos", postgresql.JSONB(astext_type=sa.Text()), server_default="{}", nullable=False
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_plans")),
    )
    op.create_table(
        "days",
        sa.Column("user_id", sa.Text(), nullable=False),
        sa.Column("day", sa.Date(), nullable=False),
        sa.Column("done", sa.ARRAY(sa.Integer()), server_default="{}", nullable=False),
        sa.Column(
            "extras", postgresql.JSONB(astext_type=sa.Text()), server_default="[]", nullable=False
        ),
        sa.Column("gym_started", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("gym_done", sa.ARRAY(sa.Text()), server_default="{}", nullable=False),
        sa.Column("water", sa.Integer(), server_default="0", nullable=False),
        sa.CheckConstraint("water between 0 and 30", name=op.f("ck_days_water_range")),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name=op.f("fk_days_user_id_users"), ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("user_id", "day", name=op.f("pk_days")),
    )
    op.create_table(
        "weights",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Text(), nullable=False),
        sa.Column("date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("weight", sa.Float(), nullable=False),
        sa.CheckConstraint("weight > 0 and weight <= 500", name=op.f("ck_weights_weight_range")),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name=op.f("fk_weights_user_id_users"), ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_weights")),
    )
    op.create_index("ix_weights_user_id_date", "weights", ["user_id", "date"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_weights_user_id_date", table_name="weights")
    op.drop_table("weights")
    op.drop_table("days")
    op.drop_table("plans")
    op.drop_table("foods")
    op.drop_table("exercises")
