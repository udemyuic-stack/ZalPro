from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def create_gyms() -> None:
    op.create_table(
        "gyms",
        sa.Column("id", sa.Text(), nullable=False),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("address", sa.Text(), server_default="", nullable=False),
        sa.Column("country", sa.Text(), server_default="", nullable=False),
        sa.Column("region", sa.Text(), server_default="", nullable=False),
        sa.Column("district", sa.Text(), server_default="", nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_gyms")),
    )


def create_users() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Text(), nullable=False),
        sa.Column("name", sa.Text(), server_default="", nullable=False),
        sa.Column("phone", sa.Text(), nullable=False),
        sa.Column("password_hash", sa.Text(), nullable=False),
        sa.Column("role", sa.Text(), server_default="user", nullable=False),
        sa.Column("gender", sa.Text(), nullable=True),
        sa.Column("age", sa.Integer(), nullable=True),
        sa.Column("height", sa.Float(), nullable=True),
        sa.Column("weight", sa.Float(), server_default="0", nullable=False),
        sa.Column("activity", sa.Float(), nullable=True),
        sa.Column("metabolism", sa.Text(), nullable=True),
        sa.Column("goal", sa.Text(), nullable=True),
        sa.Column("plan_id", sa.Text(), nullable=True),
        sa.Column("plan_assigned_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("trainer_id", sa.Text(), nullable=True),
        sa.Column("gym_id", sa.Text(), nullable=True),
        sa.Column("gym_days", sa.ARRAY(sa.Integer()), server_default="{}", nullable=False),
        sa.Column("home_workout_date", sa.Text(), nullable=True),
        sa.Column("subscription_expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_weigh_in", sa.DateTime(timezone=True), nullable=True),
        sa.Column("program", postgresql.JSONB(), server_default="{}", nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint(
            "role in ('user', 'admin', 'owner', 'barmen')", name=op.f("ck_users_role_valid")
        ),
        sa.ForeignKeyConstraint(
            ["trainer_id"],
            ["users.id"],
            name=op.f("fk_users_trainer_id_users"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["gym_id"], ["gyms.id"], name=op.f("fk_users_gym_id_gyms"), ondelete="SET NULL"
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_users")),
        sa.UniqueConstraint("phone", name=op.f("uq_users_phone")),
    )
    op.create_index(op.f("ix_users_trainer_id"), "users", ["trainer_id"])
    op.create_index(op.f("ix_users_gym_id"), "users", ["gym_id"])


def create_trainers() -> None:
    op.create_table(
        "trainers",
        sa.Column("id", sa.Text(), nullable=False),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("bio", sa.Text(), server_default="", nullable=False),
        sa.Column("accepting", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column("gym_id", sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(
            ["id"], ["users.id"], name=op.f("fk_trainers_id_users"), ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["gym_id"], ["gyms.id"], name=op.f("fk_trainers_gym_id_gyms"), ondelete="SET NULL"
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_trainers")),
    )


def create_refresh_tokens() -> None:
    op.create_table(
        "refresh_tokens",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Text(), nullable=False),
        sa.Column("token_hash", sa.Text(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_refresh_tokens_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_refresh_tokens")),
        sa.UniqueConstraint("token_hash", name=op.f("uq_refresh_tokens_token_hash")),
    )
    op.create_index(op.f("ix_refresh_tokens_user_id"), "refresh_tokens", ["user_id"])


def upgrade() -> None:
    create_gyms()
    create_users()
    create_trainers()
    create_refresh_tokens()


def downgrade() -> None:
    op.drop_table("refresh_tokens")
    op.drop_table("trainers")
    op.drop_table("users")
    op.drop_table("gyms")
