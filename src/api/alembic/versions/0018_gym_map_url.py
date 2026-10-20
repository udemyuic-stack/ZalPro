from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0018"
down_revision: str | None = "0017"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("gyms", sa.Column("map_url", sa.Text(), server_default="", nullable=False))


def downgrade() -> None:
    op.drop_column("gyms", "map_url")
