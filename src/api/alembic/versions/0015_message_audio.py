from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0015"
down_revision: str | None = "0014"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("messages", sa.Column("media_duration_ms", sa.Integer(), nullable=True))
    op.drop_constraint(op.f("ck_messages_media_kind_valid"), "messages", type_="check")
    op.create_check_constraint(
        op.f("ck_messages_media_kind_valid"),
        "messages",
        "media_kind is null or media_kind in ('image', 'video', 'audio')",
    )
    op.create_check_constraint(
        op.f("ck_messages_media_duration_valid"),
        "messages",
        "media_duration_ms is null or "
        "(media_kind = 'audio' and media_duration_ms between 1 and 300000)",
    )


def downgrade() -> None:
    op.execute("delete from messages where media_kind = 'audio'")
    op.drop_constraint(op.f("ck_messages_media_duration_valid"), "messages", type_="check")
    op.drop_constraint(op.f("ck_messages_media_kind_valid"), "messages", type_="check")
    op.create_check_constraint(
        op.f("ck_messages_media_kind_valid"),
        "messages",
        "media_kind is null or media_kind in ('image', 'video')",
    )
    op.drop_column("messages", "media_duration_ms")
