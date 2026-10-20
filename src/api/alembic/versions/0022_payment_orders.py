from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0022"
down_revision: str | None = "0021"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "payment_orders",
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column("seq", sa.BigInteger(), sa.Identity(always=True), nullable=False, unique=True),
        sa.Column(
            "user_id",
            sa.Text(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("provider", sa.Text(), nullable=False),
        sa.Column("months", sa.Integer(), nullable=False),
        sa.Column("amount", sa.Integer(), nullable=False),
        sa.Column("currency", sa.Text(), server_default="UZS", nullable=False),
        sa.Column("status", sa.Text(), server_default="pending", nullable=False),
        sa.Column("provider_trans_id", sa.Text()),
        sa.Column("provider_time", sa.BigInteger()),
        sa.Column(
            "subscription_id",
            sa.Text(),
            sa.ForeignKey("subscriptions.id", ondelete="SET NULL"),
        ),
        sa.Column("cancel_reason", sa.Integer()),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column("transaction_at", sa.DateTime(timezone=True)),
        sa.Column("performed_at", sa.DateTime(timezone=True)),
        sa.Column("canceled_at", sa.DateTime(timezone=True)),
        sa.CheckConstraint(
            "provider in ('payme', 'click')", name="ck_payment_orders_provider_valid"
        ),
        sa.CheckConstraint(
            "status in ('pending', 'created', 'paid', 'canceled')",
            name="ck_payment_orders_status_valid",
        ),
        sa.CheckConstraint("months between 1 and 24", name="ck_payment_orders_months_range"),
        sa.CheckConstraint("amount > 0", name="ck_payment_orders_amount_positive"),
        sa.CheckConstraint("currency = 'UZS'", name="ck_payment_orders_currency_valid"),
    )
    op.create_index(
        "ix_payment_orders_user_id_created_at", "payment_orders", ["user_id", "created_at"]
    )
    op.create_index(
        "ix_payment_orders_provider_time", "payment_orders", ["provider", "provider_time"]
    )
    op.create_index(
        "uq_payment_orders_provider_trans_id",
        "payment_orders",
        ["provider", "provider_trans_id"],
        unique=True,
        postgresql_where=sa.text("provider_trans_id is not null"),
    )


def downgrade() -> None:
    op.drop_table("payment_orders")
