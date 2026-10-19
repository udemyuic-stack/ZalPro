from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0017"
down_revision: str | None = "0016"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "reminders",
        sa.Column("auto", sa.Boolean(), server_default=sa.false(), nullable=False),
    )
    op.add_column("reminders", sa.Column("expires_ref", sa.DateTime(timezone=True), nullable=True))
    op.add_column("reminders", sa.Column("auto_stage", sa.SmallInteger(), nullable=True))
    op.create_index(
        "uq_reminders_auto_stage",
        "reminders",
        ["client_id", "auto_stage", "expires_ref"],
        unique=True,
        postgresql_where=sa.text("auto"),
    )


def downgrade() -> None:
    op.drop_index("uq_reminders_auto_stage", table_name="reminders")
    op.drop_column("reminders", "auto_stage")
    op.drop_column("reminders", "expires_ref")
    op.drop_column("reminders", "auto")
