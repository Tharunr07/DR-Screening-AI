#!/usr/bin/env python3
"""
phase24a_qa_test.py — Phase 24A.1 Annotation Tool QA Audit

Tests reader isolation, data integrity, annotation CRUD, agreement engine,
and audit trail. Uses synthetic fixtures (no real patient data).

Usage:
    python matlab/annotation/phase24a_qa_test.py
"""

import csv
import json
import os
import shutil
import sys
import tempfile
import time
from pathlib import Path

import numpy as np
from PIL import Image

# Add annotation module to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__)))

from annotation_schema import (
    init_directories, save_grading_annotation, load_grading_annotations,
    save_lesion_mask, load_lesion_mask, get_reader_progress,
    compute_consensus, ANNOTATION_DIR, GRADING_DIR, MASK_DIR, LESION_DIR,
    READER_IDS, DR_GRADES, LESION_TYPES,
    STATUS_DRAFT, STATUS_SUBMITTED, STATUS_LOCKED,
    submit_annotation, lock_annotation, get_audit_trail, get_submission_status
)
from agreement_engine import (
    compute_cohens_kappa, compute_fleiss_kappa, compute_per_grade_agreement,
    compute_reader_pairwise, compute_dice_score, compute_iou_score,
    compute_full_agreement_report
)

# ============================================================================
# TEST CONFIGURATION
# ============================================================================

TEST_DIR = 'results/phase24a_qa_test'
SYNTHETIC_IMAGES_DIR = os.path.join(TEST_DIR, 'synthetic_images')
SYNTHETIC_COHORT_CSV = os.path.join(TEST_DIR, 'test_cohort.csv')
N_SYNTHETIC_IMAGES = 30  # Small set for fast testing

# Track test results
TEST_RESULTS = []
TESTS_PASSED = 0
TESTS_FAILED = 0


def log_test(name, passed, detail=''):
    global TESTS_PASSED, TESTS_FAILED
    status = 'PASS' if passed else 'FAIL'
    if passed:
        TESTS_PASSED += 1
    else:
        TESTS_FAILED += 1
    TEST_RESULTS.append({'name': name, 'status': status, 'detail': detail})
    print(f'  [{status}] {name}' + (f' — {detail}' if detail else ''))


# ============================================================================
# FIXTURE GENERATION
# ============================================================================

def create_synthetic_images():
    """Create synthetic fundus-like images for testing."""
    os.makedirs(SYNTHETIC_IMAGES_DIR, exist_ok=True)

    rng = np.random.RandomState(42)
    image_ids = []

    for i in range(N_SYNTHETIC_IMAGES):
        img_id = f'SYNTH_{i:04d}'
        image_ids.append(img_id)

        # Create a synthetic retinal-like image (dark background, bright disc)
        img = np.zeros((512, 512, 3), dtype=np.uint8)
        img[:, :, 0] = 30  # Dark red channel
        img[:, :, 1] = 10
        img[:, :, 2] = 10

        # Add optic disc (bright circle)
        y, x = np.ogrid[-256:256, -256:256]
        disc_mask = x**2 + y**2 < 40**2
        img[disc_mask, 0] = 200
        img[disc_mask, 1] = 180
        img[disc_mask, 2] = 140

        # Add some noise
        noise = rng.randint(0, 20, img.shape, dtype=np.uint8)
        img = np.clip(img.astype(np.int16) + noise, 0, 255).astype(np.uint8)

        # Save
        path = os.path.join(SYNTHETIC_IMAGES_DIR, f'{img_id}.png')
        Image.fromarray(img).save(path)

    return image_ids


def create_synthetic_cohort(image_ids):
    """Create a test cohort CSV."""
    os.makedirs(os.path.dirname(SYNTHETIC_COHORT_CSV), exist_ok=True)

    rng = np.random.RandomState(42)
    grades = [0, 1, 2, 3, 4]

    with open(SYNTHETIC_COHORT_CSV, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=[
            'image_id', 'dataset', 'dr_grade', 'split', 'width', 'height'
        ])
        writer.writeheader()
        for img_id in image_ids:
            writer.writerow({
                'image_id': img_id,
                'dataset': 'SYNTHETIC',
                'dr_grade': rng.choice(grades),
                'split': 'development',
                'width': 512,
                'height': 512
            })

    return SYNTHETIC_COHORT_CSV


def create_known_agreement_data():
    """Create annotation data with known agreement patterns for testing."""
    # Scenario 1: Perfect agreement
    perfect = {'SYNTH_0000': 0, 'SYNTH_0001': 1, 'SYNTH_0002': 2,
               'SYNTH_0003': 3, 'SYNTH_0004': 4}

    # Scenario 2: Partial agreement (2/3 agree)
    partial = {'SYNTH_0005': 2, 'SYNTH_0006': 2, 'SYNTH_0007': 3,
               'SYNTH_0008': 1, 'SYNTH_0009': 1}

    # Scenario 3: Full disagreement
    disagreement = {'SYNTH_0010': 0, 'SYNTH_0011': 1, 'SYNTH_0012': 2}

    return perfect, partial, disagreement


def create_synthetic_lesion_masks(image_ids):
    """Create synthetic lesion masks for testing Dice/IoU."""
    masks = {}
    rng = np.random.RandomState(42)

    for img_id in image_ids[:10]:  # First 10 images
        masks[img_id] = {}
        for lt in LESION_TYPES:
            # Create a binary mask with some random blobs
            mask = np.zeros((512, 512), dtype=bool)
            n_blobs = rng.randint(1, 5)
            for _ in range(n_blobs):
                cy, cx = rng.randint(50, 462, 2)
                r = rng.randint(5, 25)
                y, x = np.ogrid[-cy:512-cy, -cx:512-cx]
                blob = x**2 + y**2 < r**2
                mask |= blob
            masks[img_id][lt] = mask

    return masks


# ============================================================================
# TEST FUNCTIONS
# ============================================================================

def test_reader_isolation():
    """Verify readers cannot access each other's data."""
    print('\n--- Test: Reader Isolation ---')

    # Save annotation for R1
    save_grading_annotation('R1', 'TEST_ISO_001', 2, True, 4, 5, 'R1 annotation')

    # Load R1 annotations
    r1_ann = load_grading_annotations('R1')
    r1_images = [a['image_id'] for a in r1_ann]

    # Load R2 annotations (should be empty or not contain R1's data)
    r2_ann = load_grading_annotations('R2')
    r2_images = [a['image_id'] for a in r2_ann]

    # R1's annotation should not appear in R2's data
    log_test('R1 annotation saved',
             any(a['image_id'] == 'TEST_ISO_001' for a in r1_ann))

    log_test('R2 does not contain R1 annotation',
             'TEST_ISO_001' not in r2_images)

    # Test per-reader progress isolation
    r1_progress = get_reader_progress('R1')
    r2_progress = get_reader_progress('R2')

    log_test('R1 progress tracks R1 only',
             'TEST_ISO_001' in r1_progress['images'])

    log_test('R2 progress does not include R1 images',
             'TEST_ISO_001' not in r2_progress['images'])

    # Clean up
    cleanup_test_data()


def test_annotation_crud():
    """Test annotation create/read/update operations."""
    print('\n--- Test: Annotation CRUD ---')

    # Create
    path = save_grading_annotation('R1', 'TEST_CRUD_001', 3, True, 5, 4, 'test note', 30)
    log_test('Grading annotation created', os.path.exists(path))

    # Read
    ann = load_grading_annotations('R1')
    target = [a for a in ann if a['image_id'] == 'TEST_CRUD_001']
    log_test('Grading annotation readable', len(target) == 1)

    if target:
        a = target[0]
        log_test('DR grade stored correctly', a['dr_grade'] == 3)
        log_test('Referable stored correctly', a['referable'] == 'true')
        log_test('Confidence stored correctly', a['reader_confidence'] == 5)
        log_test('Quality stored correctly', a['image_quality'] == 4)
        log_test('Notes stored correctly', a['notes'] == 'test note')
        log_test('Timestamp present', 'timestamp' in a and len(a['timestamp']) > 0)

    # Save second annotation (append, not overwrite)
    save_grading_annotation('R1', 'TEST_CRUD_002', 1, False, 3, 5, '', 15)
    ann = load_grading_annotations('R1')
    crud_images = [a['image_id'] for a in ann if a['image_id'].startswith('TEST_CRUD')]
    log_test('Multiple annotations coexist', len(crud_images) == 2)

    cleanup_test_data()


def test_lesion_mask_operations():
    """Test lesion mask save/load operations."""
    print('\n--- Test: Lesion Mask Operations ---')

    # Create synthetic mask
    mask_data = np.zeros((512, 512), dtype=np.uint8)
    mask_data[100:200, 100:200] = 255  # White square = lesion

    # Save
    path = save_lesion_mask('R1', 'TEST_MASK_001', 'MA', mask_data)
    log_test('Lesion mask saved', os.path.exists(path))

    # Load
    loaded = load_lesion_mask('R1', 'TEST_MASK_001', 'MA')
    log_test('Lesion mask loaded', loaded is not None)

    if loaded is not None:
        log_test('Mask shape correct', loaded.shape == (512, 512))
        log_test('Mask values correct (binary)', set(np.unique(loaded)) == {False, True})
        log_test('Mask content matches', np.array_equal(loaded, mask_data > 0))

    # Test each lesion type
    for lt in LESION_TYPES:
        mask = np.random.randint(0, 2, (100, 100), dtype=bool)
        path = save_lesion_mask('R1', f'TEST_MASK_{lt}', lt, mask.astype(np.uint8))
        loaded = load_lesion_mask('R1', f'TEST_MASK_{lt}', lt)
        log_test(f'{lt} mask save/load', loaded is not None and np.array_equal(loaded, mask))

    # Test that different lesion types don't overlap
    ma_mask = load_lesion_mask('R1', 'TEST_MASK_MA', 'MA')
    he_mask = load_lesion_mask('R1', 'TEST_MASK_HE', 'HE')
    if ma_mask is not None and he_mask is not None:
        log_test('Different lesion types are independent',
                 not np.array_equal(ma_mask, he_mask))

    cleanup_test_data()


def test_save_resume():
    """Test that progress is tracked and resume works."""
    print('\n--- Test: Save/Resume ---')

    # Simulate annotating 5 images
    for i in range(5):
        save_grading_annotation('R1', f'RESUME_{i:04d}', i % 5, i >= 2, 3, 4)

    progress = get_reader_progress('R1')
    log_test('Progress tracks completed count', progress['completed'] == 5)
    log_test('Progress lists annotated images',
             all(f'RESUME_{i:04d}' in progress['images'] for i in range(5)))

    # Verify load returns all annotations
    ann = load_grading_annotations('R1')
    resume_anns = [a for a in ann if a['image_id'].startswith('RESUME')]
    log_test('All annotations loadable', len(resume_anns) == 5)

    cleanup_test_data()


def test_original_images_not_modified():
    """Verify original images are never modified by annotation tool."""
    print('\n--- Test: Original Image Integrity ---')

    # Create a test image
    test_img_path = os.path.join(SYNTHETIC_IMAGES_DIR, 'SYNTH_0000.png')
    if os.path.exists(test_img_path):
        # Record original hash
        import hashlib
        with open(test_img_path, 'rb') as f:
            original_hash = hashlib.sha256(f.read()).hexdigest()

        # Save a lesion mask (should not modify original)
        mask = np.zeros((512, 512), dtype=np.uint8)
        mask[100:200, 100:200] = 255
        save_lesion_mask('R1', 'SYNTH_0000', 'MA', mask)

        # Check original is unchanged
        with open(test_img_path, 'rb') as f:
            current_hash = hashlib.sha256(f.read()).hexdigest()

        log_test('Original image not modified', original_hash == current_hash)
    else:
        log_test('Original image not modified', False, 'Test image not found')


def test_agreement_engine_known_answers():
    """Test agreement engine against known-answer synthetic data."""
    print('\n--- Test: Agreement Engine (Known Answers) ---')

    perfect, partial, disagreement = create_known_agreement_data()

    # Test 1: Perfect agreement → kappa = 1.0
    all_annotations = {
        'R1': [{'image_id': k, 'dr_grade': v} for k, v in perfect.items()],
        'R2': [{'image_id': k, 'dr_grade': v} for k, v in perfect.items()],
        'R3': [{'image_id': k, 'dr_grade': v} for k, v in perfect.items()],
    }

    fleiss = compute_fleiss_kappa(all_annotations)
    log_test('Perfect agreement: Fleiss kappa = 1.0',
             abs(fleiss['kappa'] - 1.0) < 0.001,
             f"kappa={fleiss['kappa']}")

    # Test 2: Partial agreement → kappa between 0 and 1
    r1_ann = [{'image_id': k, 'dr_grade': v} for k, v in partial.items()]
    r2_ann = [{'image_id': k, 'dr_grade': v} for k, v in partial.items()]
    r3_ann = [{'image_id': k, 'dr_grade': v} for k, v in partial.items()]
    # Make R3 disagree on some
    r3_ann[0]['dr_grade'] = 3  # Was 0
    r3_ann[2]['dr_grade'] = 2  # Was 2 (same)
    r3_ann[4]['dr_grade'] = 4  # Was 4 (same)

    partial_annotations = {'R1': r1_ann, 'R2': r2_ann, 'R3': r3_ann}
    fleiss_partial = compute_fleiss_kappa(partial_annotations)
    log_test('Partial agreement: 0 < kappa < 1',
             0 < fleiss_partial['kappa'] < 1,
             f"kappa={fleiss_partial['kappa']}")

    # Test 3: Cohen's kappa between two identical readers = 1.0
    cohen_perfect = compute_cohens_kappa(all_annotations['R1'], all_annotations['R2'])
    log_test('Cohen kappa (identical) = 1.0',
             abs(cohen_perfect['kappa'] - 1.0) < 0.001,
             f"kappa={cohen_perfect['kappa']}")

    # Test 4: Cohen's kappa between completely different readers < 1.0
    r1_diff = [{'image_id': f'DIFF_{i}', 'dr_grade': i % 5} for i in range(10)]
    r2_diff = [{'image_id': f'DIFF_{i}', 'dr_grade': (i + 2) % 5} for i in range(10)]
    cohen_diff = compute_cohens_kappa(r1_diff, r2_diff)
    log_test('Cohen kappa (different) < 1.0',
             cohen_diff['kappa'] < 1.0,
             f"kappa={cohen_diff['kappa']}")

    # Test 5: Per-grade agreement
    per_grade = compute_per_grade_agreement(all_annotations)
    for grade in range(5):
        if grade in per_grade:
            log_test(f'G{grade} full agreement rate = 1.0 (perfect data)',
                     abs(per_grade[grade]['full_agreement_rate'] - 1.0) < 0.001,
                     f"rate={per_grade[grade]['full_agreement_rate']}")

    # Test 6: Consensus computation
    # Full agreement
    c1 = compute_consensus({0: 2, 1: 2, 2: 2})
    log_test('Consensus: full agreement detected',
             c1['agreement'] == 'full' and c1['grade'] == 2)

    # Partial agreement
    c2 = compute_consensus({0: 2, 1: 2, 2: 3})
    log_test('Consensus: partial agreement detected',
             c2['agreement'] == 'partial' and c2['grade'] == 2)

    # Full disagreement
    c3 = compute_consensus({0: 0, 1: 1, 2: 2})
    log_test('Consensus: full disagreement detected',
             c3['agreement'] == 'none' and c3['disagreed'] is True)


def test_dice_iou_known_answers():
    """Test Dice and IoU on known masks."""
    print('\n--- Test: Dice/IoU Known Answers ---')

    # Identical masks → Dice = 1.0, IoU = 1.0
    mask_a = np.zeros((100, 100), dtype=bool)
    mask_a[20:40, 20:40] = True

    mask_b = mask_a.copy()

    dice = compute_dice_score(mask_a, mask_b)
    iou = compute_iou_score(mask_a, mask_b)
    log_test('Identical masks: Dice = 1.0', abs(dice - 1.0) < 0.001)
    log_test('Identical masks: IoU = 1.0', abs(iou - 1.0) < 0.001)

    # Completely different masks → Dice ≈ 0
    mask_c = np.zeros((100, 100), dtype=bool)
    mask_c[60:80, 60:80] = True

    dice2 = compute_dice_score(mask_a, mask_c)
    iou2 = compute_iou_score(mask_a, mask_c)
    log_test('Non-overlapping masks: Dice = 0', abs(dice2) < 0.001)
    log_test('Non-overlapping masks: IoU = 0', abs(iou2) < 0.001)

    # Partial overlap
    mask_d = np.zeros((100, 100), dtype=bool)
    mask_d[30:50, 30:50] = True  # Overlaps with mask_a in [30:40, 30:40]

    dice3 = compute_dice_score(mask_a, mask_d)
    iou3 = compute_iou_score(mask_a, mask_d)
    log_test('Partial overlap: 0 < Dice < 1', 0 < dice3 < 1, f"dice={dice3}")
    log_test('Partial overlap: 0 < IoU < 1', 0 < iou3 < 1, f"iou={iou3}")

    # Both empty → Dice = 1.0
    empty_a = np.zeros((100, 100), dtype=bool)
    empty_b = np.zeros((100, 100), dtype=bool)
    dice_empty = compute_dice_score(empty_a, empty_b)
    log_test('Both empty: Dice = 1.0', abs(dice_empty - 1.0) < 0.001)

    # One empty → Dice = 0
    dice_one_empty = compute_dice_score(mask_a, empty_a)
    log_test('One empty: Dice = 0', abs(dice_one_empty) < 0.001)


def test_timestamp_integrity():
    """Verify timestamps are recorded correctly."""
    print('\n--- Test: Timestamp Integrity ---')

    before = time.time()
    save_grading_annotation('R1', 'TEST_TIME_001', 0, False, 3, 4)
    after = time.time()

    ann = load_grading_annotations('R1')
    target = [a for a in ann if a['image_id'] == 'TEST_TIME_001']

    if target:
        ts = target[0]['timestamp']
        log_test('Timestamp present', len(ts) > 0)
        log_test('Timestamp format valid', 'T' in ts and ('Z' in ts or '+' in ts))
    else:
        log_test('Timestamp present', False)

    cleanup_test_data()


def test_annotation_cannot_be_silently_overwritten():
    """Verify that saving an annotation appends, not replaces."""
    print('\n--- Test: No Silent Overwrite ---')

    save_grading_annotation('R1', 'TEST_OVERWRITE_001', 0, False, 2, 3, 'original')
    ann1 = load_grading_annotations('R1')
    count1 = len([a for a in ann1 if a['image_id'] == 'TEST_OVERWRITE_001'])

    # Save again for same image (should create second entry, not replace)
    save_grading_annotation('R1', 'TEST_OVERWRITE_001', 4, True, 5, 5, 'updated')
    ann2 = load_grading_annotations('R1')
    count2 = len([a for a in ann2 if a['image_id'] == 'TEST_OVERWRITE_001'])

    log_test('Second annotation appends (not replaces)', count2 == count1 + 1,
             f"before={count1}, after={count2}")

    cleanup_test_data()


def test_csv_data_reconstruction():
    """Verify exported CSV data can be correctly reconstructed."""
    print('\n--- Test: CSV Data Reconstruction ---')

    # Create known data
    test_data = [
        ('RECON_001', 0, False, 1, 2, 'note A'),
        ('RECON_002', 1, False, 3, 4, 'note B'),
        ('RECON_003', 2, True, 5, 5, 'note C'),
        ('RECON_004', 3, True, 4, 3, ''),
        ('RECON_005', 4, True, 2, 1, 'note E'),
    ]

    for img_id, grade, ref, conf, qual, notes in test_data:
        save_grading_annotation('R1', img_id, grade, ref, conf, qual, notes)

    # Load and verify all data
    ann = load_grading_annotations('R1')
    recons = {a['image_id']: a for a in ann if a['image_id'].startswith('RECON')}

    all_correct = True
    for img_id, grade, ref, conf, qual, notes in test_data:
        if img_id in recons:
            a = recons[img_id]
            if (a['dr_grade'] != grade or
                a['reader_confidence'] != conf or
                a['image_quality'] != qual or
                a['notes'] != notes):
                all_correct = False
                break
        else:
            all_correct = False
            break

    log_test('All CSV data reconstructed correctly', all_correct)

    # Verify no data corruption
    log_test('Correct number of records',
             len(recons) == len(test_data),
             f"expected={len(test_data)}, got={len(recons)}")

    cleanup_test_data()


def test_submission_states():
    """Test DRAFT -> SUBMITTED -> LOCKED state transitions."""
    print('\n--- Test: Submission States ---')

    # Create annotation (should be DRAFT by default)
    save_grading_annotation('R1', 'TEST_STATE_001', 2, True, 4, 5)
    status = get_submission_status('R1', 'TEST_STATE_001')
    log_test('New annotation starts as DRAFT', status == STATUS_DRAFT, f"status={status}")

    # Submit
    ok, msg = submit_annotation('R1', 'TEST_STATE_001')
    log_test('Submit succeeds', ok, msg)
    status = get_submission_status('R1', 'TEST_STATE_001')
    log_test('Status after submit is SUBMITTED', status == STATUS_SUBMITTED, f"status={status}")

    # Cannot submit again
    ok2, msg2 = submit_annotation('R1', 'TEST_STATE_001')
    log_test('Double submit rejected', not ok2, msg2)

    # Lock
    ok3, msg3 = lock_annotation('R1', 'TEST_STATE_001')
    log_test('Lock succeeds', ok3, msg3)
    status2 = get_submission_status('R1', 'TEST_STATE_001')
    log_test('Status after lock is LOCKED', status2 == STATUS_LOCKED, f"status={status2}")

    # Cannot lock again
    ok4, msg4 = lock_annotation('R1', 'TEST_STATE_001')
    log_test('Double lock rejected', not ok4, msg4)

    # Cannot submit a locked annotation
    save_grading_annotation('R1', 'TEST_STATE_002', 3, True, 3, 4)
    lock_annotation('R1', 'TEST_STATE_002')  # Skip through to locked
    # Actually, need to submit first, then lock
    submit_annotation('R1', 'TEST_STATE_002')
    lock_annotation('R1', 'TEST_STATE_002')
    ok5, msg5 = submit_annotation('R1', 'TEST_STATE_002')
    log_test('Cannot submit a locked annotation', not ok5, msg5)

    cleanup_test_data()


def test_audit_trail():
    """Verify audit trail records all actions."""
    print('\n--- Test: Audit Trail ---')

    # Create annotation
    save_grading_annotation('R1', 'TEST_AUDIT_001', 1, False, 3, 4, 'audit test')
    submit_annotation('R1', 'TEST_AUDIT_001')
    lock_annotation('R1', 'TEST_AUDIT_001')

    # Get audit trail
    trail = get_audit_trail('R1')
    audit_actions = [e['action'] for e in trail if e['image_id'] == 'TEST_AUDIT_001']

    log_test('Audit trail has create entry', 'create' in audit_actions)
    log_test('Audit trail has submit entry', 'submit' in audit_actions)
    log_test('Audit trail has lock entry', 'lock' in audit_actions)
    log_test('Audit trail has correct order',
             audit_actions.index('create') < audit_actions.index('submit') <
             audit_actions.index('lock'))

    # Check timestamps exist
    timestamps = [e['timestamp'] for e in trail if e['image_id'] == 'TEST_AUDIT_001']
    log_test('All audit entries have timestamps',
             all(len(t) > 0 for t in timestamps))

    cleanup_test_data()


# ============================================================================
# CLEANUP
# ============================================================================

def cleanup_test_data():
    """Remove test annotations (not synthetic images)."""
    for reader_id in READER_IDS:
        grading_path = os.path.join(GRADING_DIR, reader_id)
        if os.path.exists(grading_path):
            shutil.rmtree(grading_path)
        lesion_path = os.path.join(LESION_DIR, reader_id)
        if os.path.exists(lesion_path):
            shutil.rmtree(lesion_path)
        mask_path = os.path.join(MASK_DIR, reader_id)
        if os.path.exists(mask_path):
            shutil.rmtree(mask_path)
    # Reinitialize directories after cleanup
    init_directories()


# ============================================================================
# MAIN
# ============================================================================

def main():
    global TESTS_PASSED, TESTS_FAILED

    print('=' * 60)
    print('  Phase 24A.1 — Annotation Tool QA Audit')
    print('=' * 60)

    # Create test fixtures
    print('\nCreating synthetic fixtures...')
    os.makedirs(TEST_DIR, exist_ok=True)
    image_ids = create_synthetic_images()
    print(f'  Created {len(image_ids)} synthetic images in {SYNTHETIC_IMAGES_DIR}')

    cohort_path = create_synthetic_cohort(image_ids)
    print(f'  Created test cohort: {cohort_path}')

    # Initialize annotation directories
    init_directories()

    # Run tests
    test_reader_isolation()
    test_annotation_crud()
    test_lesion_mask_operations()
    test_save_resume()
    test_original_images_not_modified()
    test_agreement_engine_known_answers()
    test_dice_iou_known_answers()
    test_timestamp_integrity()
    test_annotation_cannot_be_silently_overwritten()
    test_csv_data_reconstruction()
    test_submission_states()
    test_audit_trail()

    # Summary
    print('\n' + '=' * 60)
    print(f'  RESULTS: {TESTS_PASSED} passed, {TESTS_FAILED} failed, '
          f'{TESTS_PASSED + TESTS_FAILED} total')
    print('=' * 60)

    if TESTS_FAILED > 0:
        print('\nFAILED TESTS:')
        for t in TEST_RESULTS:
            if t['status'] == 'FAIL':
                print(f"  {t['name']}: {t['detail']}")

    # Write results
    results_path = os.path.join(TEST_DIR, 'qa_test_results.json')
    with open(results_path, 'w', encoding='utf-8') as f:
        json.dump({
            'timestamp': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
            'tests_passed': TESTS_PASSED,
            'tests_failed': TESTS_FAILED,
            'tests_total': TESTS_PASSED + TESTS_FAILED,
            'results': TEST_RESULTS
        }, f, indent=2)
    print(f'\nResults written to: {results_path}')

    return 0 if TESTS_FAILED == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
