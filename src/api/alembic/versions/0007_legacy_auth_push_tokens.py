from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0007"
down_revision: str | None = "0006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "push_tokens",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Text(), nullable=False),
        sa.Column("token", sa.Text(), nullable=False),
        sa.Column("platform", sa.Text(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "platform in ('android', 'web', 'ios')",
            name=op.f("ck_push_tokens_platform_valid"),
        ),
        sa.CheckConstraint(
            "char_length(token) between 1 and 4096",
            name=op.f("ck_push_tokens_token_length"),
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_push_tokens_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_push_tokens")),
        sa.UniqueConstraint("token", name=op.f("uq_push_tokens_token")),
    )
    op.create_index(op.f("ix_push_tokens_user_id"), "push_tokens", ["user_id"], unique=False)
    op.add_column("users", sa.Column("legacy_hash", sa.Text(), nullable=True))
    op.add_column("users", sa.Column("legacy_salt", sa.Text(), nullable=True))
    op.add_column("users", sa.Column("legacy_algo", sa.Text(), nullable=True))
    op.create_check_constraint(
        op.f("ck_users_legacy_consistent"),
        "users",
        "(legacy_hash is null and legacy_salt is null and legacy_algo is null) "
        "or (legacy_hash is not null and legacy_algo in ('scrypt', 'bcrypt'))",
    )


def downgrade() -> None:
    op.drop_constraint(op.f("ck_users_legacy_consistent"), "users", type_="check")
    op.drop_column("users", "legacy_algo")
    op.drop_column("users", "legacy_salt")
    op.drop_column("users", "legacy_hash")
    op.drop_index(op.f("ix_push_tokens_user_id"), table_name="push_tokens")
    op.drop_table("push_tokens")
