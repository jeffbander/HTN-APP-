"""Add notes to blood_pressure_readings

Revision ID: d4e5f6a7b8c9
Revises: 3158f0c0a62e
Create Date: 2026-03-02 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'd4e5f6a7b8c9'
down_revision = '3158f0c0a62e'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('blood_pressure_readings', schema=None) as batch_op:
        batch_op.add_column(sa.Column('notes', sa.Text(), nullable=True))


def downgrade():
    with op.batch_alter_table('blood_pressure_readings', schema=None) as batch_op:
        batch_op.drop_column('notes')
