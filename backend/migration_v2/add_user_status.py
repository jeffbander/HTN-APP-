"""Replace is_approved and enrollment_source with user_status.

Revision ID: migration_002
"""
from alembic import op
import sqlalchemy as sa

revision = 'migration_002'
down_revision = 'migration_001'  # Update to match your actual previous revision
branch_labels = None
depends_on = None


def upgrade():
    # Add user_status column
    op.add_column('users', sa.Column('user_status', sa.String(30), nullable=True, index=True))

    # Backfill user_status from existing data before making it NOT NULL.
    # This will be refined by the fix_user_statuses.py script,
    # but we set safe defaults here so the column can become NOT NULL.
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

    # pre-existing users (NULL enrollment_source) — default to active
    conn.execute(sa.text(
        "UPDATE users SET user_status = 'active' "
        "WHERE user_status IS NULL"
    ))

    # Now make it NOT NULL
    op.alter_column('users', 'user_status', nullable=False, server_default='pending_approval')

    # Drop old columns
    op.drop_column('users', 'is_approved')
    op.drop_column('users', 'enrollment_source')


def downgrade():
    # Restore old columns
    op.add_column('users', sa.Column('is_approved', sa.Boolean(), nullable=True, server_default='false'))
    op.add_column('users', sa.Column('enrollment_source', sa.String(20), nullable=True))

    # Backfill from user_status
    conn = op.get_bind()
    conn.execute(sa.text(
        "UPDATE users SET enrollment_source = 'enrollment_only', is_approved = true "
        "WHERE user_status = 'enrollment_only'"
    ))
    conn.execute(sa.text(
        "UPDATE users SET enrollment_source = 'app', is_approved = true "
        "WHERE user_status IN ('active', 'pending_first_reading', 'pending_cuff', "
        "'pending_registration', 'deactivated')"
    ))
    conn.execute(sa.text(
        "UPDATE users SET is_approved = false "
        "WHERE user_status = 'pending_approval'"
    ))

    op.drop_column('users', 'user_status')
