from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0019"
down_revision: str | None = "0018"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "rep_sessions",
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column(
            "user_id", sa.Text(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("exercise_key", sa.Text(), nullable=False),
        sa.Column("reps", sa.Integer(), nullable=False),
        sa.Column("duration_s", sa.Integer(), nullable=False),
        sa.Column("visibility_pct", sa.Integer(), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("coins", sa.Integer(), server_default="0", nullable=False),
        sa.Column("xp", sa.Integer(), server_default="0", nullable=False),
        sa.Column("status", sa.Text(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint(
            "status in ('valid', 'flagged', 'voided')", name="ck_rep_sessions_status_valid"
        ),
        sa.CheckConstraint("reps > 0 and duration_s > 0", name="ck_rep_sessions_positive_counts"),
        sa.CheckConstraint(
            "visibility_pct between 0 and 100", name="ck_rep_sessions_visibility_range"
        ),
    )
    op.create_index("ix_rep_sessions_user_started", "rep_sessions", ["user_id", "started_at"])
    op.create_index("ix_rep_sessions_status_started", "rep_sessions", ["status", "started_at"])
    op.create_table(
        "coin_ledger",
        sa.Column("id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column(
            "user_id", sa.Text(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("delta", sa.Integer(), nullable=False),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column("ref_id", sa.Text(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint(
            "reason in ('session', 'streak', 'purchase', 'void')",
            name="ck_coin_ledger_reason_valid",
        ),
    )
    op.create_index("ix_coin_ledger_user_id", "coin_ledger", ["user_id"])


def downgrade() -> None:
    op.drop_table("coin_ledger")
    op.drop_table("rep_sessions")
