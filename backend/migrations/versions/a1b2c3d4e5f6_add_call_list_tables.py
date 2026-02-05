"""add call list tables

Revision ID: a1b2c3d4e5f6
Revises: ec8b8b98a44f
Create Date: 2026-02-02 14:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'a1b2c3d4e5f6'
down_revision = 'f1a2b3c4d5e6'
branch_labels = None
depends_on = None


def upgrade():
    # Call List Items
    op.create_table('call_list_items',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('list_type', sa.String(20), nullable=False),
        sa.Column('status', sa.String(10), nullable=False, server_default='open'),
        sa.Column('close_reason', sa.String(30), nullable=True),
        sa.Column('close_note', sa.Text(), nullable=True),
        sa.Column('priority', sa.String(10), nullable=False, server_default='medium'),
        sa.Column('priority_title', sa.String(200), nullable=True),
        sa.Column('priority_detail', sa.Text(), nullable=True),
        sa.Column('cooldown_until', sa.DateTime(), nullable=True),
        sa.Column('follow_up_date', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.Column('closed_at', sa.DateTime(), nullable=True),
        sa.Column('closed_by', sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.ForeignKeyConstraint(['closed_by'], ['users.id']),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_call_list_items_user_id', 'call_list_items', ['user_id'])
    op.create_index('ix_call_list_items_list_type', 'call_list_items', ['list_type'])
    op.create_index('ix_call_list_items_status', 'call_list_items', ['status'])

    # Call Attempts
    op.create_table('call_attempts',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('call_list_item_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('admin_id', sa.Integer(), nullable=False),
        sa.Column('outcome', sa.String(30), nullable=False),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('follow_up_needed', sa.Boolean(), server_default='false'),
        sa.Column('follow_up_date', sa.DateTime(), nullable=True),
        sa.Column('materials_sent', sa.Boolean(), server_default='false'),
        sa.Column('materials_desc', sa.Text(), nullable=True),
        sa.Column('referral_made', sa.Boolean(), server_default='false'),
        sa.Column('referral_to', sa.String(200), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['call_list_item_id'], ['call_list_items.id']),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.ForeignKeyConstraint(['admin_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_call_attempts_call_list_item_id', 'call_attempts', ['call_list_item_id'])
    op.create_index('ix_call_attempts_user_id', 'call_attempts', ['user_id'])

    # Email Templates
    op.create_table('email_templates',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(200), nullable=False),
        sa.Column('subject', sa.String(500), nullable=False),
        sa.Column('body', sa.Text(), nullable=False),
        sa.Column('list_type', sa.String(20), nullable=False, server_default='all'),
        sa.Column('is_active', sa.Boolean(), server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )

    # Seed default email templates
    op.execute("""
        INSERT INTO email_templates (name, subject, body, list_type, is_active)
        VALUES
        ('No-Reading Reminder', 'Reminder: Please submit your blood pressure reading',
         'Hi {{patient_name}},\n\nWe noticed you haven''t taken a blood pressure reading recently. Regular monitoring is important for managing your health.\n\nPlease take a reading at your earliest convenience and submit it through the app.\n\nIf you have any questions or need assistance, don''t hesitate to reach out.\n\nBest regards,\nHTN Monitor Team',
         'no_reading', true),
        ('Follow-Up Resources', 'Follow-Up: Resources from your recent call',
         'Hi {{patient_name}},\n\nThank you for speaking with us today. As discussed, here are the materials and resources we mentioned:\n\n[Insert materials here]\n\nPlease review these at your convenience. If you have any questions, feel free to call us back.\n\nBest regards,\nHTN Monitor Team',
         'all', true),
        ('Appointment Reminder', 'Reminder: Upcoming appointment',
         'Hi {{patient_name}},\n\nThis is a reminder about your upcoming appointment. Please make sure to:\n\n- Take your blood pressure reading before the appointment\n- Bring a list of your current medications\n- Note any symptoms or concerns you''d like to discuss\n\nIf you need to reschedule, please contact us as soon as possible.\n\nBest regards,\nHTN Monitor Team',
         'all', true)
    """)


def downgrade():
    op.drop_table('email_templates')
    op.drop_index('ix_call_attempts_user_id', table_name='call_attempts')
    op.drop_index('ix_call_attempts_call_list_item_id', table_name='call_attempts')
    op.drop_table('call_attempts')
    op.drop_index('ix_call_list_items_status', table_name='call_list_items')
    op.drop_index('ix_call_list_items_list_type', table_name='call_list_items')
    op.drop_index('ix_call_list_items_user_id', table_name='call_list_items')
    op.drop_table('call_list_items')
