"""
annotation_schema.py — Phase 24 Annotation Data Model

Defines the data structures for DR grading and lesion annotation.
All annotations are stored as CSV files with consistent schema.
"""

import csv
import json
import os
from datetime import datetime, timezone
from pathlib import Path


ANNOTATION_DIR = 'results/phase24_annotations'
GRADING_DIR = os.path.join(ANNOTATION_DIR, 'grading')
LESION_DIR = os.path.join(ANNOTATION_DIR, 'lesions')
MASK_DIR = os.path.join(ANNOTATION_DIR, 'masks')
CONSENSUS_DIR = os.path.join(ANNOTATION_DIR, 'consensus')
AUDIT_DIR = os.path.join(ANNOTATION_DIR, 'audit')

DR_GRADES = {0: 'No DR', 1: 'Mild NPDR', 2: 'Moderate NPDR', 3: 'Severe NPDR', 4: 'PDR'}
LESION_TYPES = ['MA', 'HE', 'EX', 'NV']
READER_IDS = ['R1', 'R2', 'R3']

# Submission states: DRAFT -> SUBMITTED -> LOCKED
STATUS_DRAFT = 'draft'
STATUS_SUBMITTED = 'submitted'
STATUS_LOCKED = 'locked'
VALID_STATUSES = [STATUS_DRAFT, STATUS_SUBMITTED, STATUS_LOCKED]

GRADING_FIELDS = [
    'image_id', 'reader_id', 'dr_grade', 'referable',
    'reader_confidence', 'image_quality', 'notes', 'timestamp',
    'annotation_time_seconds', 'status'
]

LESION_FIELDS = [
    'image_id', 'reader_id', 'lesion_type', 'mask_path',
    'area_pixels', 'timestamp', 'annotation_time_seconds', 'status'
]

CONSENSUS_FIELDS = [
    'image_id', 'dr_grade_r1', 'dr_grade_r2', 'dr_grade_r3',
    'dr_grade_consensus', 'agreement_level', 'disagreement_flag',
    'adjudicator', 'adjudication_reason', 'timestamp'
]


def init_directories():
    """Create annotation directory structure."""
    for d in [ANNOTATION_DIR, GRADING_DIR, LESION_DIR, MASK_DIR, CONSENSUS_DIR]:
        os.makedirs(d, exist_ok=True)
    for reader in READER_IDS:
        os.makedirs(os.path.join(GRADING_DIR, reader), exist_ok=True)
        os.makedirs(os.path.join(MASK_DIR, reader), exist_ok=True)


def grading_csv_path(reader_id):
    """Path to a reader's grading CSV."""
    return os.path.join(GRADING_DIR, reader_id, f'{reader_id}_grading.csv')


def save_grading_annotation(reader_id, image_id, dr_grade, referable,
                             reader_confidence, image_quality, notes='',
                             annotation_time=0, status=None):
    """Save a single grading annotation."""
    path = grading_csv_path(reader_id)
    file_exists = os.path.exists(path)

    if status is None:
        # Check if already submitted/locked
        existing_status = get_submission_status(reader_id, image_id)
        if existing_status in (STATUS_SUBMITTED, STATUS_LOCKED):
            status = existing_status
        else:
            status = STATUS_DRAFT

    row = {
        'image_id': image_id,
        'reader_id': reader_id,
        'dr_grade': dr_grade,
        'referable': str(referable).lower(),
        'reader_confidence': reader_confidence,
        'image_quality': image_quality,
        'notes': notes,
        'timestamp': datetime.now(timezone.utc).isoformat(),
        'annotation_time_seconds': annotation_time,
        'status': status
    }

    with open(path, 'a', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=GRADING_FIELDS)
        if not file_exists:
            writer.writeheader()
        writer.writerow(row)

    audit_log(reader_id, image_id, 'create', {'grade': dr_grade, 'status': status})
    return path


def load_grading_annotations(reader_id=None):
    """Load grading annotations. If reader_id is None, load all readers."""
    annotations = []
    readers = [reader_id] if reader_id else READER_IDS

    for rid in readers:
        path = grading_csv_path(rid)
        if os.path.exists(path):
            with open(path, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    row['dr_grade'] = int(row['dr_grade'])
                    row['reader_confidence'] = int(row['reader_confidence'])
                    row['image_quality'] = int(row['image_quality'])
                    annotations.append(row)

    return annotations


def save_lesion_mask(reader_id, image_id, lesion_type, mask_data):
    """Save a lesion mask as PNG."""
    mask_dir = os.path.join(MASK_DIR, reader_id)
    os.makedirs(mask_dir, exist_ok=True)

    filename = f'{image_id}_{lesion_type}.png'
    mask_path = os.path.join(mask_dir, filename)

    from PIL import Image
    import numpy as np
    img = Image.fromarray(mask_data.astype(np.uint8) * 255, mode='L')
    img.save(mask_path)

    # Log annotation
    log_path = os.path.join(LESION_DIR, reader_id, f'{reader_id}_lesions.csv')
    os.makedirs(os.path.dirname(log_path), exist_ok=True)
    file_exists = os.path.exists(log_path)

    area = int(np.sum(mask_data > 0))

    row = {
        'image_id': image_id,
        'reader_id': reader_id,
        'lesion_type': lesion_type,
        'mask_path': mask_path,
        'area_pixels': area,
        'timestamp': datetime.now(timezone.utc).isoformat(),
        'annotation_time_seconds': 0
    }

    with open(log_path, 'a', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=LESION_FIELDS)
        if not file_exists:
            writer.writeheader()
        writer.writerow(row)

    return mask_path


def load_lesion_mask(reader_id, image_id, lesion_type):
    """Load a lesion mask."""
    from PIL import Image
    import numpy as np

    mask_path = os.path.join(MASK_DIR, reader_id, f'{image_id}_{lesion_type}.png')
    if os.path.exists(mask_path):
        img = Image.open(mask_path)
        return np.array(img) > 0
    return None


def save_consensus(image_id, grades, adjudicator='', reason=''):
    """Save consensus annotation."""
    consensus = compute_consensus(grades)

    path = os.path.join(CONSENSUS_DIR, 'grading_consensus.csv')
    file_exists = os.path.exists(path)

    row = {
        'image_id': image_id,
        'dr_grade_r1': grades.get('R1', ''),
        'dr_grade_r2': grades.get('R2', ''),
        'dr_grade_r3': grades.get('R3', ''),
        'dr_grade_consensus': consensus['grade'],
        'agreement_level': consensus['agreement'],
        'disagreement_flag': str(consensus['disagreed']).lower(),
        'adjudicator': adjudicator,
        'adjudication_reason': reason,
        'timestamp': datetime.now(timezone.utc).isoformat()
    }

    with open(path, 'a', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=CONSENSUS_FIELDS)
        if not file_exists:
            writer.writeheader()
        writer.writerow(row)

    return consensus


def compute_consensus(grades):
    """Compute consensus from 3 reader grades."""
    values = list(grades.values())
    counts = {}
    for v in values:
        counts[v] = counts.get(v, 0) + 1

    if len(counts) == 1:
        return {'grade': values[0], 'agreement': 'full', 'disagreed': False}
    elif len(counts) == 2:
        majority = max(counts, key=counts.get)
        return {'grade': majority, 'agreement': 'partial', 'disagreed': True}
    else:
        return {'grade': -1, 'agreement': 'none', 'disagreed': True}


def get_cohort_images(cohort_csv):
    """Load image IDs from a cohort CSV."""
    images = []
    with open(cohort_csv, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            images.append(row)
    return images


def get_reader_progress(reader_id):
    """Get annotation progress for a reader."""
    path = grading_csv_path(reader_id)
    if not os.path.exists(path):
        return {'completed': 0, 'total': 0, 'images': []}

    annotated = set()
    with open(path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            annotated.add(row['image_id'])

    return {
        'completed': len(annotated),
        'images': list(annotated)
    }


def audit_log(reader_id, image_id, action, details=None):
    """Write an audit trail entry."""
    os.makedirs(AUDIT_DIR, exist_ok=True)
    audit_path = os.path.join(AUDIT_DIR, f'{reader_id}_audit.csv')
    file_exists = os.path.exists(audit_path)

    row = {
        'reader_id': reader_id,
        'image_id': image_id,
        'action': action,
        'details': json.dumps(details) if details else '',
        'timestamp': datetime.now(timezone.utc).isoformat()
    }

    with open(audit_path, 'a', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=['reader_id', 'image_id', 'action', 'details', 'timestamp'])
        if not file_exists:
            writer.writeheader()
        writer.writerow(row)

    return audit_path


def get_submission_status(reader_id, image_id):
    """Get the submission status of an annotation."""
    path = grading_csv_path(reader_id)
    if not os.path.exists(path):
        return None

    with open(path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['image_id'] == image_id:
                return row.get('status', STATUS_DRAFT)
    return None


def submit_annotation(reader_id, image_id):
    """Transition annotation from DRAFT to SUBMITTED. Cannot be undone."""
    status = get_submission_status(reader_id, image_id)
    if status == STATUS_LOCKED:
        return False, 'Cannot modify locked annotation'
    if status == STATUS_SUBMITTED:
        return False, 'Already submitted'

    # Update status in CSV
    path = grading_csv_path(reader_id)
    if not os.path.exists(path):
        return False, 'No annotation found'

    rows = []
    updated = False
    with open(path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['image_id'] == image_id:
                row['status'] = STATUS_SUBMITTED
                updated = True
            rows.append(row)

    if updated:
        with open(path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=GRADING_FIELDS)
            writer.writeheader()
            writer.writerows(rows)

        audit_log(reader_id, image_id, 'submit', {'from': status or STATUS_DRAFT, 'to': STATUS_SUBMITTED})
        return True, 'Submitted'

    return False, 'Image not found'


def lock_annotation(reader_id, image_id, admin_id='admin'):
    """Transition annotation from SUBMITTED to LOCKED. Requires admin."""
    status = get_submission_status(reader_id, image_id)
    if status == STATUS_LOCKED:
        return False, 'Already locked'
    if status != STATUS_SUBMITTED:
        return False, f'Cannot lock: current status is {status}'

    path = grading_csv_path(reader_id)
    rows = []
    updated = False
    with open(path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['image_id'] == image_id:
                row['status'] = STATUS_LOCKED
                updated = True
            rows.append(row)

    if updated:
        with open(path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=GRADING_FIELDS)
            writer.writeheader()
            writer.writerows(rows)

        audit_log(reader_id, image_id, 'lock', {
            'from': STATUS_SUBMITTED, 'to': STATUS_LOCKED, 'admin': admin_id
        })
        return True, 'Locked'

    return False, 'Image not found'


def get_audit_trail(reader_id=None):
    """Get audit trail entries."""
    entries = []
    readers = [reader_id] if reader_id else READER_IDS

    for rid in readers:
        audit_path = os.path.join(AUDIT_DIR, f'{rid}_audit.csv')
        if os.path.exists(audit_path):
            with open(audit_path, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    entries.append(row)

    return sorted(entries, key=lambda x: x.get('timestamp', ''))


def init_directories():
    """Create annotation directory structure."""
    for d in [ANNOTATION_DIR, GRADING_DIR, LESION_DIR, MASK_DIR, CONSENSUS_DIR, AUDIT_DIR]:
        os.makedirs(d, exist_ok=True)
    for reader in READER_IDS:
        os.makedirs(os.path.join(GRADING_DIR, reader), exist_ok=True)
        os.makedirs(os.path.join(MASK_DIR, reader), exist_ok=True)
