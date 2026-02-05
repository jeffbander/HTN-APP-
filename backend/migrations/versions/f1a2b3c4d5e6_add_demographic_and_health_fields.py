"""add demographic and health fields to users

Revision ID: f1a2b3c4d5e6
Revises: ec8b8b98a44f
Create Date: 2026-02-02 18:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'f1a2b3c4d5e6'
down_revision = 'ec8b8b98a44f'
branch_labels = None
depends_on = None


def upgrade():
    # Encrypted PHI fields
    op.add_column('users', sa.Column('phone', sa.Text(), nullable=True))
    op.add_column('users', sa.Column('address', sa.Text(), nullable=True))
    op.add_column('users', sa.Column('medications', sa.Text(), nullable=True))

    # Non-PHI demographic fields
    op.add_column('users', sa.Column('gender', sa.String(length=50), nullable=True))
    op.add_column('users', sa.Column('race', sa.String(length=100), nullable=True))
    op.add_column('users', sa.Column('ethnicity', sa.String(length=100), nullable=True))
    op.add_column('users', sa.Column('work_status', sa.String(length=50), nullable=True))
    op.add_column('users', sa.Column('rank', sa.String(length=100), nullable=True))
    op.add_column('users', sa.Column('height_inches', sa.Integer(), nullable=True))
    op.add_column('users', sa.Column('weight_lbs', sa.Integer(), nullable=True))
    op.add_column('users', sa.Column('chronic_conditions', sa.Text(), nullable=True))
    op.add_column('users', sa.Column('has_high_blood_pressure', sa.Boolean(), nullable=True))
    op.add_column('users', sa.Column('smoking_status', sa.String(length=100), nullable=True))
    op.add_column('users', sa.Column('on_bp_medication', sa.Boolean(), nullable=True))
    op.add_column('users', sa.Column('missed_doses', sa.Integer(), nullable=True))


def downgrade():
    op.drop_column('users', 'missed_doses')
    op.drop_column('users', 'on_bp_medication')
    op.drop_column('users', 'smoking_status')
    op.drop_column('users', 'has_high_blood_pressure')
    op.drop_column('users', 'chronic_conditions')
    op.drop_column('users', 'weight_lbs')
    op.drop_column('users', 'height_inches')
    op.drop_column('users', 'rank')
    op.drop_column('users', 'work_status')
    op.drop_column('users', 'ethnicity')
    op.drop_column('users', 'race')
    op.drop_column('users', 'gender')
    op.drop_column('users', 'medications')
    op.drop_column('users', 'address')
    op.drop_column('users', 'phone')
