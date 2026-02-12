# ===========================================================
# CHANGES TO app/models/user.py
# ===========================================================

# 1. ADD this constant at the top of the file (after imports):

USER_STATUS_CHOICES = [
    'pending_approval',       # Signed up in Flutter, waiting for union approval
    'pending_registration',   # Union approved, hasn't requested cuff yet
    'pending_cuff',           # Cuff requested, waiting for delivery
    'pending_first_reading',  # Cuff delivered, waiting for first BP reading
    'active',                 # Has at least one BP reading
    'deactivated',            # No reading in 8+ months (auto) or admin manual
    'enrollment_only',        # MS Forms registrant, never used the app
]


# 2. REPLACE these fields:
#      is_approved = db.Column(db.Boolean, default=False)
#      enrollment_source = db.Column(db.String(20), nullable=True)
#
#    WITH this single field:

    user_status = db.Column(db.String(30), nullable=False, default='pending_approval', index=True)


# 3. KEEP is_active as a convenience flag (True for everyone except deactivated):
#      is_active = db.Column(db.Boolean, default=True)
#    The migration script will sync is_active with user_status.


# 4. REMOVE from to_dict():
#      'is_approved': self.is_approved,
#      'enrollment_source': self.enrollment_source,
#
#    ADD to to_dict():

            'user_status': self.user_status,


# 5. ADD this helper property:

    @property
    def is_approved(self):
        """Backward compatibility for Flutter app — True if past the approval stage."""
        return self.user_status not in ('pending_approval', None)


# 6. PHQ-2 fields (keep from previous migration):
    phq2_interest = db.Column(db.String(50), nullable=True)
    phq2_depressed = db.Column(db.String(50), nullable=True)
