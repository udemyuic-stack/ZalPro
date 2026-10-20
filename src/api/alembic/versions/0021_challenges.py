from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0021"
down_revision: str | None = "0020"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "user_challenges",
        sa.Column(
            "user_id",
            sa.Text(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("step", sa.Integer(), server_default="0", nullable=False),
        sa.Column("progress", sa.Integer(), server_default="0", nullable=False),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint("step >= 0 and progress >= 0", name="ck_user_challenges_non_negative"),
    )
    op.drop_constraint("ck_coin_ledger_reason_valid", "coin_ledger", type_="check")
    op.create_check_constraint(
        "ck_coin_ledger_reason_valid",
        "coin_ledger",
        "reason in ('session', 'streak', 'purchase', 'void', 'challenge')",
    )


def downgrade() -> None:
    op.drop_constraint("ck_coin_ledger_reason_valid", "coin_ledger", type_="check")
    op.create_check_constraint(
        "ck_coin_ledger_reason_valid",
        "coin_ledger",
        "reason in ('session', 'streak', 'purchase', 'void')",
    )
    op.drop_table("user_challenges")
