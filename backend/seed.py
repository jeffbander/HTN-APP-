"""
Seed script to populate the database with initial data.
Run from backend/: python seed.py
"""
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from app import create_app, db
from app.models.union import Union
from app.models.user import User

UNIONS = [
    (1, "UFOA"),
    (2, "UFA"),
    (3, "UFADBA"),
    (4, "LBA"),
    (5, "Mount Sinai"),
    (6, "Other"),
]

def seed():
    app = create_app()
    with app.app_context():
        # Seed unions
        for uid, name in UNIONS:
            existing = db.session.get(Union, uid)
            if existing:
                print(f"  Union '{name}' (id={uid}) already exists, skipping.")
                continue
            union = Union(id=uid, name=name)
            db.session.add(union)
            print(f"  Added union '{name}' (id={uid})")
        db.session.commit()
        print(f"Unions seeded: {Union.query.count()} total.\n")

        # Seed admin user
        admin_email = "admin@bp-app.local"
        admin = User.find_by_email(admin_email)
        if admin:
            print(f"  Admin user already exists (id={admin.id}), skipping.")
        else:
            admin = User()
            admin.name = "Admin"
            admin.email = admin_email
            admin.union_id = 1
            admin.is_approved = True
            admin.is_admin = True
            admin.is_email_verified = True
            db.session.add(admin)
            db.session.commit()
            print(f"  Created admin user (id={admin.id}, email={admin_email})")

        print("\nDone.")


if __name__ == "__main__":
    seed()
