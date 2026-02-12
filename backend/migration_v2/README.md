# User Status Pipeline — Implementation Guide

## What Changed

Replacing `is_approved` (boolean) and `enrollment_source` (string) with a single
`user_status` field that tracks where each user is in the onboarding pipeline.

## User Status Values

```
pending_approval → pending_registration → pending_cuff → pending_first_reading → active → deactivated
                                                                                           ↑ (8 months no reading OR admin manual)
enrollment_only  (separate — MS Forms registrants who never used the app)
```

| Status | Meaning | How they get here |
|--------|---------|-------------------|
| `pending_approval` | Signed up in Flutter app | Flutter registration |
| `pending_registration` | Union approved them | Admin approves in dashboard |
| `pending_cuff` | Requested cuff from Flutter | Flutter cuff request form |
| `pending_first_reading` | Cuff delivered, no readings yet | Shipping marked delivered |
| `active` | Has BP readings | First BP reading submitted |
| `deactivated` | Inactive 8+ months or admin disabled | Auto-detected or manual |
| `enrollment_only` | MS Forms registrant | Historical data migration |

## Deactivation Logic

**Not stored as a status change** — calculated on the fly:
- "Active" tab shows `user_status='active'` AND last reading within 8 months
- "Deactivated" tab shows `user_status='deactivated'` OR (`user_status='active'` with last reading > 8 months ago)
- Admin can manually set someone to `deactivated` via the dashboard

## Files to Give Claude Code

### 1. user_model_patch_v2.py
Reference for editing `app/models/user.py`:
- Add `user_status` column (String(30), indexed, default='pending_approval')
- Remove `is_approved` and `enrollment_source` columns
- Add backward-compat `is_approved` property
- Keep `is_active` as convenience flag

### 2. add_user_status.py
Alembic migration that:
- Adds `user_status` column
- Backfills from existing `enrollment_source` and BP reading data
- Drops `is_approved` and `enrollment_source`

### 3. admin_user_tabs.py
API endpoints for the dashboard:
- `GET /admin/users/tab-counts` — badge counts for each tab
- `GET /admin/users/tab/<tab_name>` — filtered/paginated user list
- `PUT /admin/users/<int:user_id>/status` — manually change status
- Supports query params: `search`, `union_id`, `gender`, `has_htn`, `sort`, `dir`, `page`, `per_page`

## Claude Code Prompt

```
I need to implement a user status pipeline in my HTN-APP. Here's what needs to happen:

BACKEND CHANGES (backend/):

1. Edit app/models/user.py:
   - Add USER_STATUS_CHOICES list at the top
   - Replace is_approved and enrollment_source with:
     user_status = db.Column(db.String(30), nullable=False, default='pending_approval', index=True)
   - Keep is_active boolean
   - Add is_approved as a @property for backward compat (True if status != pending_approval)
   - Update to_dict() to include user_status instead of is_approved and enrollment_source
   Reference: migration_v2/user_model_patch_v2.py

2. Generate and run Alembic migration:
   - Add user_status column
   - Backfill: enrollment_only users → 'enrollment_only'
   - Backfill: app users WITH bp readings → 'active'
   - Backfill: app users WITHOUT bp readings → 'pending_first_reading'
   - Backfill: pre-existing NULL users → 'active'
   - Make user_status NOT NULL
   - Drop is_approved and enrollment_source columns
   Reference: migration_v2/add_user_status.py

3. Add admin routes to app/routes/admin.py:
   - GET /admin/users/tab-counts (badge counts per tab)
   - GET /admin/users/tab/<tab_name> (paginated user list with filters)
   - PUT /admin/users/<int:user_id>/status (change status)
   Reference: migration_v2/admin_user_tabs.py

4. Update any existing routes that reference is_approved or enrollment_source
   to use user_status instead.

FRONTEND CHANGES (admin-dashboard/):

5. Create a tabbed user management page with these tabs:
   - All Users
   - Active (green badge)
   - Pending Approval (orange badge)
   - Pending Registration (orange badge)
   - Pending Cuff (orange badge)
   - Pending First Reading (blue badge)
   - Enrollment Only (gray badge)
   - Deactivated (red badge)

6. Each tab should have:
   - Search bar (search by name or email)
   - Filter dropdowns: Union, Gender, Has HTN
   - Sortable columns: Name, Email, Union, Status, Last Reading, Reading Count
   - Pagination (50 per page)
   - Click row to open user detail

7. Admin should be able to change user status from the user detail view
   with a dropdown.

Run the Alembic migration after making model changes.
Then verify with: SELECT user_status, COUNT(*) FROM users GROUP BY user_status;
```

## Expected Results After Migration

| user_status | count |
|-------------|-------|
| active | ~668 |
| pending_first_reading | ~4 |
| enrollment_only | 333 |
| (pre-existing/admin) | ~27 as active |
