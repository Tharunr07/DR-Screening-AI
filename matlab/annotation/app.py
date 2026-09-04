"""
app.py — Phase 24 Annotation Tool Backend

Flask application serving fundus images and collecting annotations
from 3 independent readers.
"""

import csv
import json
import os
import time
from pathlib import Path

from flask import Flask, render_template, request, jsonify, send_file, session
from PIL import Image
import numpy as np

from annotation_schema import (
    init_directories, save_grading_annotation, load_grading_annotations,
    save_lesion_mask, load_lesion_mask, get_cohort_images, get_reader_progress,
    DR_GRADES, LESION_TYPES, READER_IDS, ANNOTATION_DIR
)

app = Flask(__name__)
app.secret_key = os.urandom(24).hex()

# Configuration
COHORT_CSV = 'results/phase24_clinical_ground_truth/phase24_cohort.csv'
LESION_COHORT_CSV = 'results/phase24_clinical_ground_truth/phase24_lesion_cohort.csv'
IMAGE_BASE_DIR = 'data/raw'

# Initialize
init_directories()


def load_cohort():
    """Load the grading cohort."""
    return get_cohort_images(COHORT_CSV)


def load_lesion_cohort():
    """Load the lesion annotation cohort."""
    return get_cohort_images(LESION_COHORT_CSV)


def find_image_path(image_id, dataset):
    """Find the actual image file path."""
    if dataset == 'APTOS2019':
        # Check train and test directories
        for subdir in ['train_images', 'test_images']:
            path = os.path.join(IMAGE_BASE_DIR, 'APTOS2019', subdir, f'{image_id}.png')
            if os.path.exists(path):
                return path
    elif dataset == 'IDRiD':
        for subdir in [
            os.path.join('IDRiD', 'A. Segmentation', '1. Original Images', 'a. Training Set'),
            os.path.join('IDRiD', 'A. Segmentation', '1. Original Images', 'b. Testing Set'),
            os.path.join('IDRiD', 'B. Disease Grading', '1. Original Images', 'a. Training Set'),
            os.path.join('IDRiD', 'B. Disease Grading', '1. Original Images', 'b. Testing Set'),
        ]:
            path = os.path.join(IMAGE_BASE_DIR, subdir, f'{image_id}.jpg')
            if os.path.exists(path):
                return path
            # Try IDRiD naming convention
            path = os.path.join(IMAGE_BASE_DIR, subdir, f'{image_id}.JPG')
            if os.path.exists(path):
                return path
    return None


@app.route('/')
def index():
    """Reader selection page."""
    return render_template('index.html', readers=READER_IDS, dr_grades=DR_GRADES)


@app.route('/reader/<reader_id>')
def reader_dashboard(reader_id):
    """Reader dashboard showing progress."""
    if reader_id not in READER_IDS:
        return "Invalid reader ID", 404

    cohort = load_cohort()
    progress = get_reader_progress(reader_id)
    annotated_ids = set(progress['images'])

    remaining = [img for img in cohort if img['image_id'] not in annotated_ids]

    return render_template('dashboard.html',
                           reader_id=reader_id,
                           total=len(cohort),
                           completed=progress['completed'],
                           remaining=len(remaining),
                           images=remaining[:20])  # Show first 20


@app.route('/annotate/<reader_id>')
@app.route('/annotate/<reader_id>/<image_id>')
def annotate(reader_id, image_id=None):
    """Main annotation page."""
    if reader_id not in READER_IDS:
        return "Invalid reader ID", 404

    cohort = load_cohort()

    if image_id is None:
        # Get first unannotated image
        progress = get_reader_progress(reader_id)
        annotated_ids = set(progress['images'])
        remaining = [img for img in cohort if img['image_id'] not in annotated_ids]
        if not remaining:
            return render_template('complete.html', reader_id=reader_id)
        image_data = remaining[0]
    else:
        image_data = next((img for img in cohort if img['image_id'] == image_id), None)
        if not image_data:
            return "Image not found", 404

    img_path = find_image_path(image_data['image_id'], image_data['dataset'])
    if not img_path:
        return f"Image file not found for {image_data['image_id']}", 404

    # Get next image for navigation
    progress = get_reader_progress(reader_id)
    annotated_ids = set(progress['images'])
    remaining = [img for img in cohort if img['image_id'] not in annotated_ids]
    next_image_id = remaining[0]['image_id'] if remaining else None

    # Check if this is a lesion cohort image
    lesion_cohort_ids = set()
    if os.path.exists(LESION_COHORT_CSV):
        with open(LESION_COHORT_CSV, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                lesion_cohort_ids.add(row['image_id'])

    is_lesion_image = image_data['image_id'] in lesion_cohort_ids

    return render_template('annotate.html',
                           reader_id=reader_id,
                           image=image_data,
                           image_path=img_path,
                           next_image_id=next_image_id,
                           dr_grades=DR_GRADES,
                           is_lesion_image=is_lesion_image,
                           lesion_types=LESION_TYPES)


@app.route('/api/image/<path:filepath>')
def serve_image(filepath):
    """Serve a fundus image."""
    full_path = os.path.abspath(filepath)
    if not os.path.exists(full_path):
        return "Image not found", 404
    return send_file(full_path)


@app.route('/api/annotate/grading', methods=['POST'])
def api_save_grading():
    """Save a grading annotation."""
    data = request.json
    reader_id = data.get('reader_id')
    image_id = data.get('image_id')
    dr_grade = int(data.get('dr_grade'))
    referable = dr_grade >= 2
    confidence = int(data.get('reader_confidence', 3))
    quality = int(data.get('image_quality', 3))
    notes = data.get('notes', '')
    annotation_time = data.get('annotation_time', 0)

    path = save_grading_annotation(
        reader_id, image_id, dr_grade, referable,
        confidence, quality, notes, annotation_time
    )

    return jsonify({'status': 'ok', 'path': path})


@app.route('/api/annotate/lesion', methods=['POST'])
def api_save_lesion():
    """Save a lesion mask."""
    reader_id = request.form.get('reader_id')
    image_id = request.form.get('image_id')
    lesion_type = request.form.get('lesion_type')

    mask_data = request.files.get('mask')
    if mask_data:
        img = Image.open(mask_data)
        mask_array = np.array(img) > 127  # Threshold to binary
    else:
        # Receive as JSON array
        mask_json = request.form.get('mask_json')
        if mask_json:
            mask_array = np.array(json.loads(mask_json), dtype=bool)
        else:
            return jsonify({'status': 'error', 'message': 'No mask data'}), 400

    path = save_lesion_mask(reader_id, image_id, lesion_type, mask_array.astype(np.uint8))

    return jsonify({'status': 'ok', 'path': path})


@app.route('/api/annotations/<reader_id>')
def api_get_annotations(reader_id):
    """Get all annotations for a reader."""
    annotations = load_grading_annotations(reader_id)
    return jsonify(annotations)


@app.route('/api/progress/<reader_id>')
def api_progress(reader_id):
    """Get reader progress."""
    progress = get_reader_progress(reader_id)
    cohort = load_cohort()
    progress['total'] = len(cohort)
    return jsonify(progress)


@app.route('/admin')
def admin():
    """Admin dashboard showing all readers' progress."""
    progress = {}
    for rid in READER_IDS:
        p = get_reader_progress(rid)
        p['total'] = len(load_cohort())
        progress[rid] = p

    return render_template('admin.html', progress=progress, readers=READER_IDS)


@app.route('/admin/agreement')
def admin_agreement():
    """Compute and display inter-reader agreement."""
    from agreement_engine import compute_full_agreement_report
    report = compute_full_agreement_report()
    return render_template('agreement.html', report=report)


if __name__ == '__main__':
    print("=" * 60)
    print("  Phase 24 Annotation Tool")
    print("=" * 60)
    print(f"  Cohort: {COHORT_CSV}")
    print(f"  Lesion cohort: {LESION_COHORT_CSV}")
    print(f"  Annotations: {ANNOTATION_DIR}")
    print()
    print("  Open http://localhost:5000 in your browser")
    print("=" * 60)
    app.run(debug=True, host='0.0.0.0', port=5000)
