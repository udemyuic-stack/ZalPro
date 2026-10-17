from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0011"
down_revision: str | None = "0010"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

NEW_TEXT_CHECK = "char_length(text) <= 2000 and (char_length(text) >= 1 or media_key is not null)"
OLD_TEXT_CHECK = "char_length(text) between 1 and 2000"


def upgrade() -> None:
    op.add_column("messages", sa.Column("media_key", sa.Text(), nullable=True))
    op.add_column("messages", sa.Column("media_kind", sa.Text(), nullable=True))
    op.add_column("messages", sa.Column("media_status", sa.Text(), nullable=True))
    op.drop_constraint(op.f("ck_messages_text_length"), "messages", type_="check")
    op.create_check_constraint(op.f("ck_messages_text_length"), "messages", NEW_TEXT_CHECK)
    op.create_check_constraint(
        op.f("ck_messages_media_kind_valid"),
        "messages",
        "media_kind is null or media_kind in ('image', 'video')",
    )
    op.create_check_constraint(
        op.f("ck_messages_media_status_valid"),
        "messages",
        "media_status is null or media_status in ('processing', 'ready', 'failed')",
    )


def downgrade() -> None:
    op.drop_constraint(op.f("ck_messages_media_status_valid"), "messages", type_="check")
    op.drop_constraint(op.f("ck_messages_media_kind_valid"), "messages", type_="check")
    op.drop_constraint(op.f("ck_messages_text_length"), "messages", type_="check")
    op.execute("delete from messages where char_length(text) = 0")
    op.create_check_constraint(op.f("ck_messages_text_length"), "messages", OLD_TEXT_CHECK)
    op.drop_column("messages", "media_status")
    op.drop_column("messages", "media_kind")
    op.drop_column("messages", "media_key")
