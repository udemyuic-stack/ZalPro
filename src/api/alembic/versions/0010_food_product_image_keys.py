from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0010"
down_revision: str | None = "0009"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("foods", sa.Column("image_key", sa.Text(), nullable=True))
    op.add_column(
        "products",
        sa.Column("image_keys", sa.ARRAY(sa.Text()), server_default="{}", nullable=False),
    )


def downgrade() -> None:
    op.drop_column("products", "image_keys")
    op.drop_column("foods", "image_key")
