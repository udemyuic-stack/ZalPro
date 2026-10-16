from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "0005"
down_revision: str | None = "0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "orders",
        sa.Column("id", sa.Text(), nullable=False),
        sa.Column("client_id", sa.Text(), nullable=False),
        sa.Column("client_name", sa.Text(), server_default="", nullable=False),
        sa.Column("client_phone", sa.Text(), server_default="", nullable=False),
        sa.Column("trainer_id", sa.Text(), server_default="", nullable=False),
        sa.Column("gym_id", sa.Text(), server_default="", nullable=False),
        sa.Column("product_id", sa.Text(), nullable=False),
        sa.Column("product_name", sa.Text(), nullable=False),
        sa.Column("category", sa.Text(), server_default="", nullable=False),
        sa.Column("size", sa.Text(), server_default="", nullable=False),
        sa.Column("color", sa.Text(), server_default="", nullable=False),
        sa.Column("price", sa.Integer(), nullable=False),
        sa.Column("currency", sa.Text(), server_default="UZS", nullable=False),
        sa.Column("qty", sa.Integer(), server_default="1", nullable=False),
        sa.Column("status", sa.Text(), server_default="new", nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("given_by", sa.Text(), server_default="", nullable=False),
        sa.Column("given_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint("currency in ('UZS', 'USD')", name=op.f("ck_orders_currency_valid")),
        sa.CheckConstraint(
            "status in ('new', 'given', 'canceled')", name=op.f("ck_orders_status_valid")
        ),
        sa.CheckConstraint("price >= 0", name=op.f("ck_orders_price_non_negative")),
        sa.CheckConstraint("qty between 1 and 20", name=op.f("ck_orders_qty_range")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_orders")),
    )
    op.create_index(
        "ix_orders_client_id_created_at", "orders", ["client_id", "created_at"], unique=False
    )
    op.create_index("ix_orders_gym_id_created_at", "orders", ["gym_id", "created_at"], unique=False)
    op.create_index("ix_orders_status_given_at", "orders", ["status", "given_at"], unique=False)
    op.create_index(
        "ix_orders_trainer_id_created_at", "orders", ["trainer_id", "created_at"], unique=False
    )
    op.create_table(
        "products",
        sa.Column("id", sa.Text(), nullable=False),
        sa.Column("category", sa.Text(), nullable=False),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("note", sa.Text(), server_default="", nullable=False),
        sa.Column("name_ru", sa.Text(), server_default="", nullable=False),
        sa.Column("name_en", sa.Text(), server_default="", nullable=False),
        sa.Column("note_ru", sa.Text(), server_default="", nullable=False),
        sa.Column("note_en", sa.Text(), server_default="", nullable=False),
        sa.Column("image", sa.Text(), server_default="", nullable=False),
        sa.Column("images", postgresql.ARRAY(sa.Text()), server_default="{}", nullable=False),
        sa.Column("sizes", postgresql.ARRAY(sa.Text()), server_default="{}", nullable=False),
        sa.Column("colors", postgresql.ARRAY(sa.Text()), server_default="{}", nullable=False),
        sa.Column("price", sa.Integer(), server_default="0", nullable=False),
        sa.Column("currency", sa.Text(), server_default="UZS", nullable=False),
        sa.Column("stock", sa.Integer(), server_default="0", nullable=False),
        sa.Column(
            "size_stock",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default="{}",
            nullable=False,
        ),
        sa.Column("cost_price", sa.Integer(), server_default="0", nullable=False),
        sa.Column("active", sa.Boolean(), server_default="true", nullable=False),
        sa.CheckConstraint(
            "category in ('Forma', 'Suv idishlari', 'Anjomlar', 'Protein', 'Gainer', "
            "'Kreatin', 'L-Karnitin', 'L-Arginin', 'Boshqa')",
            name=op.f("ck_products_category_valid"),
        ),
        sa.CheckConstraint("currency in ('UZS', 'USD')", name=op.f("ck_products_currency_valid")),
        sa.CheckConstraint("cost_price >= 0", name=op.f("ck_products_cost_price_non_negative")),
        sa.CheckConstraint("price >= 0", name=op.f("ck_products_price_non_negative")),
        sa.CheckConstraint("stock >= 0", name=op.f("ck_products_stock_non_negative")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_products")),
    )


def downgrade() -> None:
    op.drop_table("products")
    op.drop_index("ix_orders_trainer_id_created_at", table_name="orders")
    op.drop_index("ix_orders_status_given_at", table_name="orders")
    op.drop_index("ix_orders_gym_id_created_at", table_name="orders")
    op.drop_index("ix_orders_client_id_created_at", table_name="orders")
    op.drop_table("orders")
