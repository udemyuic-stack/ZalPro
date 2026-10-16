from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0006"
down_revision: str | None = "0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "messages",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("chat_uid", sa.Text(), nullable=False),
        sa.Column("sender_id", sa.Text(), nullable=False),
        sa.Column("kind", sa.Text(), server_default="user", nullable=False),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint("kind in ('user', 'system')", name=op.f("ck_messages_kind_valid")),
        sa.CheckConstraint(
            "char_length(text) between 1 and 2000", name=op.f("ck_messages_text_length")
        ),
        sa.ForeignKeyConstraint(
            ["chat_uid"], ["users.id"], name=op.f("fk_messages_chat_uid_users"), ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_messages")),
    )
    op.create_index(
        "ix_messages_chat_uid_created_at", "messages", ["chat_uid", "created_at"], unique=False
    )
    op.create_table(
        "photos",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Text(), nullable=False),
        sa.Column("key", sa.Text(), nullable=False),
        sa.Column("taken_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("weight", sa.Float(), nullable=False),
        sa.Column("size", sa.Integer(), nullable=False),
        sa.CheckConstraint("size between 1 and 358400", name=op.f("ck_photos_size_range")),
        sa.CheckConstraint("weight > 0 and weight <= 500", name=op.f("ck_photos_weight_range")),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name=op.f("fk_photos_user_id_users"), ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_photos")),
        sa.UniqueConstraint("key", name=op.f("uq_photos_key")),
    )
    op.create_index("ix_photos_user_id_taken_at", "photos", ["user_id", "taken_at"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_photos_user_id_taken_at", table_name="photos")
    op.drop_table("photos")
    op.drop_index("ix_messages_chat_uid_created_at", table_name="messages")
    op.drop_table("messages")
