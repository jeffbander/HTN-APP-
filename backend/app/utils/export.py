"""
Export utilities for CSV and PDF generation.
"""
import csv
import io
import json
import logging
from datetime import datetime
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle

logger = logging.getLogger(__name__)


def generate_users_csv(users, include_phi=True):
    """Generate CSV export of users.

    Args:
        users: List of User model objects
        include_phi: Whether to include PHI fields (default True for admin export)

    Returns:
        StringIO object containing CSV data
    """
    output = io.StringIO()

    fieldnames = [
        'id', 'union_name', 'gender', 'race', 'ethnicity', 'work_status', 'rank',
        'height_inches', 'weight_lbs', 'chronic_conditions', 'has_high_blood_pressure',
        'smoking_status', 'on_bp_medication', 'missed_doses',
        'is_active', 'is_approved', 'is_email_verified', 'is_flagged', 'created_at',
        'exercise_days_per_week', 'exercise_minutes_per_session', 'financial_stress',
        'stress_level', 'loneliness', 'sleep_quality',
    ]

    if include_phi:
        fieldnames = ['name', 'email', 'dob', 'phone', 'address', 'medications'] + fieldnames

    writer = csv.DictWriter(output, fieldnames=fieldnames)
    writer.writeheader()

    for user in users:
        row = {
            'id': user.id,
            'union_name': user.union.name if user.union else '',
            'gender': user.gender or '',
            'race': user.race or '',
            'ethnicity': user.ethnicity or '',
            'work_status': user.work_status or '',
            'rank': user.rank or '',
            'height_inches': user.height_inches or '',
            'weight_lbs': user.weight_lbs or '',
            'chronic_conditions': user.chronic_conditions or '',
            'has_high_blood_pressure': user.has_high_blood_pressure if user.has_high_blood_pressure is not None else '',
            'smoking_status': user.smoking_status or '',
            'on_bp_medication': user.on_bp_medication if user.on_bp_medication is not None else '',
            'missed_doses': user.missed_doses if user.missed_doses is not None else '',
            'is_active': user.is_active,
            'is_approved': user.is_approved,
            'is_email_verified': user.is_email_verified,
            'is_flagged': user.is_flagged,
            'created_at': user.created_at.isoformat() if user.created_at else '',
            'exercise_days_per_week': user.exercise_days_per_week if user.exercise_days_per_week is not None else '',
            'exercise_minutes_per_session': user.exercise_minutes_per_session if user.exercise_minutes_per_session is not None else '',
            'financial_stress': user.financial_stress or '',
            'stress_level': user.stress_level or '',
            'loneliness': user.loneliness or '',
            'sleep_quality': user.sleep_quality if user.sleep_quality is not None else '',
        }

        if include_phi:
            try:
                row['name'] = user.name or ''
                row['email'] = user.email or ''
                row['dob'] = user.dob or ''
                row['phone'] = user.phone or ''
                row['address'] = user.address or ''
                row['medications'] = user.medications or ''
            except Exception as e:
                logger.error(f"Error decrypting PHI for user {user.id}: {e}")
                row['name'] = f'User #{user.id}'
                row['email'] = ''
                row['dob'] = ''
                row['phone'] = ''
                row['address'] = ''
                row['medications'] = ''

        writer.writerow(row)

    output.seek(0)
    return output


def generate_readings_csv(readings, user_names=None):
    """Generate CSV export of blood pressure readings.

    Args:
        readings: List of BloodPressureReading model objects
        user_names: Optional dict mapping user_id to name

    Returns:
        StringIO object containing CSV data
    """
    output = io.StringIO()

    fieldnames = [
        'id', 'user_id', 'user_name', 'systolic', 'diastolic', 'heart_rate',
        'bp_category', 'reading_date', 'created_at'
    ]

    writer = csv.DictWriter(output, fieldnames=fieldnames)
    writer.writeheader()

    user_names = user_names or {}

    for reading in readings:
        row = {
            'id': reading.id,
            'user_id': reading.user_id,
            'user_name': user_names.get(reading.user_id, f'User #{reading.user_id}'),
            'systolic': reading.systolic,
            'diastolic': reading.diastolic,
            'heart_rate': reading.heart_rate or '',
            'bp_category': _classify_bp(reading.systolic, reading.diastolic),
            'reading_date': reading.reading_date.isoformat() if reading.reading_date else '',
            'created_at': reading.created_at.isoformat() if reading.created_at else '',
        }
        writer.writerow(row)

    output.seek(0)
    return output


def generate_call_reports_csv(attempts, user_names=None):
    """Generate CSV export of call reports.

    Args:
        attempts: List of CallAttempt model objects
        user_names: Optional dict mapping user_id to name

    Returns:
        StringIO object containing CSV data
    """
    output = io.StringIO()

    fieldnames = [
        'id', 'patient_id', 'patient_name', 'list_type', 'outcome',
        'follow_up_needed', 'follow_up_date', 'materials_sent', 'materials_desc',
        'referral_made', 'referral_to', 'admin_id', 'created_at'
    ]

    writer = csv.DictWriter(output, fieldnames=fieldnames)
    writer.writeheader()

    user_names = user_names or {}

    for attempt in attempts:
        row = {
            'id': attempt.id,
            'patient_id': attempt.user_id,
            'patient_name': user_names.get(attempt.user_id, f'User #{attempt.user_id}'),
            'list_type': attempt.call_list_item.list_type if attempt.call_list_item else '',
            'outcome': attempt.outcome or '',
            'follow_up_needed': attempt.follow_up_needed if attempt.follow_up_needed is not None else '',
            'follow_up_date': attempt.follow_up_date.isoformat() if attempt.follow_up_date else '',
            'materials_sent': attempt.materials_sent if attempt.materials_sent is not None else '',
            'materials_desc': attempt.materials_desc or '',
            'referral_made': attempt.referral_made if attempt.referral_made is not None else '',
            'referral_to': attempt.referral_to or '',
            'admin_id': attempt.admin_id or '',
            'created_at': attempt.created_at.isoformat() if attempt.created_at else '',
        }
        writer.writerow(row)

    output.seek(0)
    return output


def generate_patient_pdf(user, readings, avg_7=None, avg_30=None):
    """Generate a PDF report for an individual patient.

    Args:
        user: User model object
        readings: List of BloodPressureReading objects for this user
        avg_7: Optional dict with 7-day average {'systolic': x, 'diastolic': y}
        avg_30: Optional dict with 30-day average

    Returns:
        BytesIO object containing PDF data
    """
    output = io.BytesIO()
    doc = SimpleDocTemplate(output, pagesize=letter, topMargin=0.5*inch, bottomMargin=0.5*inch)

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Heading1'],
        fontSize=18,
        spaceAfter=20,
    )
    heading_style = ParagraphStyle(
        'CustomHeading',
        parent=styles['Heading2'],
        fontSize=14,
        spaceBefore=15,
        spaceAfter=10,
    )
    normal_style = styles['Normal']

    elements = []

    # Title
    try:
        patient_name = user.name or f'Patient #{user.id}'
    except Exception:
        patient_name = f'Patient #{user.id}'

    elements.append(Paragraph(f"Patient Report: {patient_name}", title_style))
    elements.append(Paragraph(f"Generated: {datetime.utcnow().strftime('%B %d, %Y at %H:%M UTC')}", normal_style))
    elements.append(Spacer(1, 20))

    # Patient Demographics
    elements.append(Paragraph("Patient Information", heading_style))

    demo_data = []
    try:
        demo_data.append(['Name:', user.name or 'N/A'])
        demo_data.append(['Email:', user.email or 'N/A'])
        demo_data.append(['Phone:', user.phone or 'N/A'])
        demo_data.append(['Date of Birth:', user.dob or 'N/A'])
    except Exception:
        demo_data.append(['Name:', f'Patient #{user.id}'])
        demo_data.append(['Email:', 'N/A'])
        demo_data.append(['Phone:', 'N/A'])
        demo_data.append(['Date of Birth:', 'N/A'])

    demo_data.append(['Gender:', user.gender or 'N/A'])
    demo_data.append(['Union:', user.union.name if user.union else 'N/A'])
    demo_data.append(['Work Status:', user.work_status or 'N/A'])
    demo_data.append(['Rank:', user.rank or 'N/A'])

    if user.height_inches:
        feet = user.height_inches // 12
        inches = user.height_inches % 12
        demo_data.append(['Height:', f"{feet}' {inches}\""])
    else:
        demo_data.append(['Height:', 'N/A'])

    demo_data.append(['Weight:', f"{user.weight_lbs} lbs" if user.weight_lbs else 'N/A'])

    demo_table = Table(demo_data, colWidths=[2*inch, 4*inch])
    demo_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('ALIGN', (0, 0), (0, -1), 'RIGHT'),
        ('ALIGN', (1, 0), (1, -1), 'LEFT'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
    ]))
    elements.append(demo_table)
    elements.append(Spacer(1, 15))

    # Health Information
    elements.append(Paragraph("Health Information", heading_style))

    health_data = []
    try:
        chronic = json.loads(user.chronic_conditions) if user.chronic_conditions else []
        health_data.append(['Chronic Conditions:', ', '.join(chronic) if chronic else 'None reported'])
    except Exception:
        health_data.append(['Chronic Conditions:', 'N/A'])

    health_data.append(['High Blood Pressure:', 'Yes' if user.has_high_blood_pressure else 'No' if user.has_high_blood_pressure is False else 'N/A'])
    health_data.append(['On BP Medication:', 'Yes' if user.on_bp_medication else 'No' if user.on_bp_medication is False else 'N/A'])
    health_data.append(['Missed Doses:', str(user.missed_doses) if user.missed_doses is not None else 'N/A'])
    health_data.append(['Smoking Status:', user.smoking_status or 'N/A'])

    try:
        health_data.append(['Medications:', user.medications or 'None reported'])
    except Exception:
        health_data.append(['Medications:', 'N/A'])

    health_table = Table(health_data, colWidths=[2*inch, 4*inch])
    health_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('ALIGN', (0, 0), (0, -1), 'RIGHT'),
        ('ALIGN', (1, 0), (1, -1), 'LEFT'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
    ]))
    elements.append(health_table)
    elements.append(Spacer(1, 15))

    # BP Summary
    elements.append(Paragraph("Blood Pressure Summary", heading_style))

    bp_summary = []
    bp_summary.append(['Total Readings:', str(len(readings))])

    if avg_7:
        bp_summary.append(['7-Day Average:', f"{avg_7['systolic']}/{avg_7['diastolic']} mmHg"])
    else:
        bp_summary.append(['7-Day Average:', 'Insufficient data'])

    if avg_30:
        bp_summary.append(['30-Day Average:', f"{avg_30['systolic']}/{avg_30['diastolic']} mmHg"])
    else:
        bp_summary.append(['30-Day Average:', 'Insufficient data'])

    if readings:
        latest = readings[0]
        bp_summary.append(['Latest Reading:', f"{latest.systolic}/{latest.diastolic} mmHg ({_classify_bp(latest.systolic, latest.diastolic)})"])
        bp_summary.append(['Latest Date:', latest.reading_date.strftime('%B %d, %Y') if latest.reading_date else 'N/A'])

    bp_table = Table(bp_summary, colWidths=[2*inch, 4*inch])
    bp_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('ALIGN', (0, 0), (0, -1), 'RIGHT'),
        ('ALIGN', (1, 0), (1, -1), 'LEFT'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
    ]))
    elements.append(bp_table)
    elements.append(Spacer(1, 15))

    # Recent Readings Table
    if readings:
        elements.append(Paragraph("Recent Readings (Last 20)", heading_style))

        reading_data = [['Date', 'Systolic', 'Diastolic', 'Heart Rate', 'Category']]
        for r in readings[:20]:
            reading_data.append([
                r.reading_date.strftime('%m/%d/%Y %H:%M') if r.reading_date else 'N/A',
                str(r.systolic),
                str(r.diastolic),
                str(r.heart_rate) if r.heart_rate else 'N/A',
                _classify_bp(r.systolic, r.diastolic),
            ])

        reading_table = Table(reading_data, colWidths=[1.5*inch, 1*inch, 1*inch, 1*inch, 1*inch])
        reading_table.setStyle(TableStyle([
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.black),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
            ('TOPPADDING', (0, 0), (-1, -1), 5),
        ]))
        elements.append(reading_table)

    doc.build(elements)
    output.seek(0)
    return output


def _classify_bp(systolic, diastolic):
    """Classify blood pressure reading into a category."""
    if systolic > 180 or diastolic > 120:
        return 'Crisis'
    if systolic >= 140 or diastolic >= 90:
        return 'Stage 2'
    if systolic >= 130 or diastolic >= 80:
        return 'Stage 1'
    if systolic >= 120 and diastolic < 80:
        return 'Elevated'
    return 'Normal'
