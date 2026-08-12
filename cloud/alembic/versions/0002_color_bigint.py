"""Widen channels.color to BIGINT for Flutter ARGB values.

Revision ID: 0002_color_bigint
Revises: 0001_initial
Create Date: 2026-08-13

"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0002_color_bigint"
down_revision: Union[str, None] = "0001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column(
        "channels",
        "color",
        existing_type=sa.Integer(),
        type_=sa.BigInteger(),
        existing_nullable=False,
    )


def downgrade() -> None:
    op.alter_column(
        "channels",
        "color",
        existing_type=sa.BigInteger(),
        type_=sa.Integer(),
        existing_nullable=False,
    )
