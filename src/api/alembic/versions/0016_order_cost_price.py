from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0016"
down_revision: str | None = "0015"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("orders", sa.Column("cost_price", sa.Integer(), nullable=True))
    op.create_check_constraint(
        op.f("ck_orders_cost_price_non_negative"),
        "orders",
        "cost_price is null or cost_price >= 0",
    )


def downgrade() -> None:
    op.drop_constraint(op.f("ck_orders_cost_price_non_negative"), "orders", type_="check")
    op.drop_column("orders", "cost_price")
