from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0012"
down_revision: str | None = "0011"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("days", sa.Column("feedback", sa.SmallInteger(), nullable=True))
    op.create_check_constraint("feedback_range", "days", "feedback between 1 and 3")


def downgrade() -> None:
    op.drop_constraint("feedback_range", "days", type_="check")
    op.drop_column("days", "feedback")
