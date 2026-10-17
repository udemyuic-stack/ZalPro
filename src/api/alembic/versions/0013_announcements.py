from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0013"
down_revision: str | None = "0012"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "announcements",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("title", sa.Text(), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("author_id", sa.Text(), nullable=False),
        sa.Column("trainer_id", sa.Text(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["author_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["trainer_id"], ["users.id"], ondelete="CASCADE"),
        sa.CheckConstraint("char_length(title) between 1 and 80", name="title_length"),
        sa.CheckConstraint("char_length(body) between 1 and 500", name="body_length"),
    )
    op.create_index("ix_announcements_created_at", "announcements", ["created_at"])
    op.create_index("ix_announcements_author_id", "announcements", ["author_id"])
    op.create_index("ix_announcements_trainer_id", "announcements", ["trainer_id"])


def downgrade() -> None:
    op.drop_table("announcements")
