"""Replace is_approved and enrollment_source with user_status.

Revision ID: a1b2c3d4e5f7
Revises: 9908081b18c4
Create Date: 2026-02-09 15:30:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'a1b2c3d4e5f7'
down_revision = '9908081b18c4'
branch_labels = None
depends_on = None


def upgrade():
    # Step 1: Add user_status column (nullable first for backfill)
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.add_column(sa.Column('user_status', sa.String(length=30), nullable=True))

    # Step 2: Backfill user_status from existing data
    conn = op.get_bind()

    # enrollment_only users
    conn.execute(sa.text(
        "UPDATE users SET user_status = 'enrollment_only' "
        "WHERE enrollment_source = 'enrollment_only'"
    ))

    # app users with BP readings → active
    conn.execute(sa.text(
        "UPDATE users SET user_status = 'active' "
        "WHERE enrollment_source = 'app' "
        "AND id IN (SELECT DISTINCT user_id FROM blood_pressure_readings)"
    ))

    # app users without BP readings → pending_first_reading
    conn.execute(sa.text(
        "UPDATE users SET user_status = 'pending_first_reading' "
        "WHERE enrollment_source = 'app' "
        "AND id NOT IN (SELECT DISTINCT user_id FROM blood_pressure_readings)"
    ))

    # pre-existing users (NULL enrollment_source) → default to active
    conn.execute(sa.text(
        "UPDATE users SET user_status = 'active' "
        "WHERE user_status IS NULL"
    ))

    # Step 3: Use batch mode for SQLite — make NOT NULL, add index, drop old columns
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.alter_column('user_status', nullable=False, server_default='pending_approval')
        batch_op.create_index('ix_users_user_status', ['user_status'])
        batch_op.drop_column('is_approved')
        batch_op.drop_column('enrollment_source')


def downgrade():
    # Restore old columns
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.add_column(sa.Column('is_approved', sa.Boolean(), nullable=True, server_default='0'))
        batch_op.add_column(sa.Column('enrollment_source', sa.String(length=20), nullable=True))
        batch_op.drop_index('ix_users_user_status')

    # Backfill from user_status
    conn = op.get_bind()
    conn.execute(sa.text(
        "UPDATE users SET enrollment_source = 'enrollment_only', is_approved = 1 "
        "WHERE user_status = 'enrollment_only'"
    ))
    conn.execute(sa.text(
        "UPDATE users SET enrollment_source = 'app', is_approved = 1 "
        "WHERE user_status IN ('active', 'pending_first_reading', 'pending_cuff', "
        "'pending_registration', 'deactivated')"
    ))
    conn.execute(sa.text(
        "UPDATE users SET is_approved = 0 "
        "WHERE user_status = 'pending_approval'"
    ))

    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.drop_column('user_status')
