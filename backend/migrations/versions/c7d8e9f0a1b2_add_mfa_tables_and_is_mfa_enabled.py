"""add MFA tables and is_mfa_enabled column

Revision ID: c7d8e9f0a1b2
Revises: 42327788a4a8
Create Date: 2026-02-05 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'c7d8e9f0a1b2'
down_revision = '42327788a4a8'
branch_labels = None
depends_on = None


def upgrade():
    # MFA secrets table
    op.create_table('mfa_secrets',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('totp_secret', sa.Text(), nullable=False),
        sa.Column('backup_codes', sa.Text(), nullable=True),
        sa.Column('mfa_type', sa.String(length=10), nullable=False, server_default='totp'),
        sa.Column('is_active', sa.Boolean(), nullable=True, server_default='false'),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('last_used_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id'),
    )

    # MFA sessions table
    op.create_table('mfa_sessions',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('session_token', sa.String(length=64), nullable=False),
        sa.Column('otp_code', sa.String(length=6), nullable=True),
        sa.Column('mfa_type', sa.String(length=10), nullable=False, server_default='email'),
        sa.Column('attempts', sa.Integer(), nullable=True, server_default='0'),
        sa.Column('expires_at', sa.DateTime(), nullable=False),
        sa.Column('verified_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('session_token'),
    )
    with op.batch_alter_table('mfa_sessions', schema=None) as batch_op:
        batch_op.create_index('ix_mfa_sessions_session_token', ['session_token'], unique=True)

    # Add is_mfa_enabled to users
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.add_column(sa.Column('is_mfa_enabled', sa.Boolean(), server_default='false', nullable=True))


def downgrade():
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.drop_column('is_mfa_enabled')

    with op.batch_alter_table('mfa_sessions', schema=None) as batch_op:
        batch_op.drop_index('ix_mfa_sessions_session_token')
    op.drop_table('mfa_sessions')

    op.drop_table('mfa_secrets')
