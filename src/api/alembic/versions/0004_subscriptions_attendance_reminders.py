from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0004"
down_revision: str | None = "0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "reminders",
        sa.Column("id", sa.Text(), nullable=False),
        sa.Column("client_id", sa.Text(), nullable=False),
        sa.Column("client_name", sa.Text(), server_default="", nullable=False),
        sa.Column("trainer_id", sa.Text(), server_default="", nullable=False),
        sa.Column("sent_by", sa.Text(), nullable=False),
        sa.Column(
            "sent_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False
        ),
        sa.Column("days_left", sa.Integer(), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_reminders")),
    )
    op.create_index(
        "ix_reminders_trainer_id_sent_at", "reminders", ["trainer_id", "sent_at"], unique=False
    )
    op.create_table(
        "attendance",
        sa.Column("user_id", sa.Text(), nullable=False),
        sa.Column("day", sa.Date(), nullable=False),
        sa.Column("present", sa.Boolean(), nullable=False),
        sa.Column("marked_by", sa.Text(), nullable=False),
        sa.Column(
            "marked_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name=op.f("fk_attendance_user_id_users"), ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("user_id", "day", name=op.f("pk_attendance")),
    )
    op.create_table(
        "memberships",
        sa.Column("user_id", sa.Text(), nullable=False),
        sa.Column("name", sa.Text(), server_default="", nullable=False),
        sa.Column("gym_id", sa.Text(), server_default="", nullable=False),
        sa.Column("months", sa.Integer(), server_default="0", nullable=False),
        sa.Column("days", sa.Integer(), server_default="0", nullable=False),
        sa.Column("price", sa.Integer(), server_default="0", nullable=False),
        sa.Column("currency", sa.Text(), server_default="UZS", nullable=False),
        sa.Column("paid_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "currency in ('UZS', 'USD')", name=op.f("ck_memberships_currency_valid")
        ),
        sa.CheckConstraint("days between 0 and 31", name=op.f("ck_memberships_days_range")),
        sa.CheckConstraint("months between 0 and 24", name=op.f("ck_memberships_months_range")),
        sa.CheckConstraint("price >= 0", name=op.f("ck_memberships_price_non_negative")),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name=op.f("fk_memberships_user_id_users"), ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("user_id", name=op.f("pk_memberships")),
    )
    op.create_table(
        "subscriptions",
        sa.Column("id", sa.Text(), nullable=False),
        sa.Column("user_id", sa.Text(), nullable=False),
        sa.Column("start_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("months", sa.Integer(), server_default="0", nullable=False),
        sa.Column("days", sa.Integer(), server_default="0", nullable=False),
        sa.Column("price", sa.Integer(), server_default="0", nullable=False),
        sa.Column("currency", sa.Text(), server_default="UZS", nullable=False),
        sa.Column("paid_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "currency in ('UZS', 'USD')", name=op.f("ck_subscriptions_currency_valid")
        ),
        sa.CheckConstraint(
            "(months > 0) <> (days > 0)", name=op.f("ck_subscriptions_kind_exclusive")
        ),
        sa.CheckConstraint("days between 0 and 31", name=op.f("ck_subscriptions_days_range")),
        sa.CheckConstraint("months between 0 and 24", name=op.f("ck_subscriptions_months_range")),
        sa.CheckConstraint("price >= 0", name=op.f("ck_subscriptions_price_non_negative")),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_subscriptions_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_subscriptions")),
    )
    op.create_index("ix_subscriptions_paid_date", "subscriptions", ["paid_date"], unique=False)
    op.create_index(
        "ix_subscriptions_user_id_start_date",
        "subscriptions",
        ["user_id", "start_date"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_subscriptions_user_id_start_date", table_name="subscriptions")
    op.drop_index("ix_subscriptions_paid_date", table_name="subscriptions")
    op.drop_table("subscriptions")
    op.drop_table("memberships")
    op.drop_table("attendance")
    op.drop_index("ix_reminders_trainer_id_sent_at", table_name="reminders")
    op.drop_table("reminders")
