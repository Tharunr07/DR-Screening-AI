#!/usr/bin/env python3
"""
phase24_cohort_sampling.py — Phase 24A: Stratified Cohort Sampling

Selects 1,000 images for multi-reader annotation and 500 for lesion masks.
Uses stratified sampling across DR grades with enrichment for pathology.

Usage:
    python matlab/validation/phase24_cohort_sampling.py

Outputs:
    results/phase24_clinical_ground_truth/phase24_cohort.csv
    results/phase24_clinical_ground_truth/phase24_lesion_cohort.csv
    results/phase24_clinical_ground_truth/phase24_sampling_report.txt
"""

import csv
import json
import os
import random
from collections import Counter, defaultdict
from pathlib import Path

# ============================================================================
# CONFIGURATION
# ============================================================================

SEED = 42
N_TOTAL = 1000          # Total images for DR grading
N_LESION = 500          # Images for lesion annotation
N_PER_GRADE = {
    0: 200,  # G0: 200 (base rate ~20%)
    1: 200,  # G1: 200 (enriched from ~10% to 20%)
    2: 250,  # G2: 250 (largest group, most confusion)
    3: 150,  # G3: 150 (enriched from ~6% to 15%)
    4: 200,  # G4: 200 (enriched from ~8% to 20%)
}

# Lesion cohort: enriched for pathology (G1-G4 overrepresented)
N_LESION_PER_GRADE = {
    0: 50,   # G0: 50 (controls)
    1: 100,  # G1: 100 (enriched)
    2: 150,  # G2: 150 (most confusion)
    3: 100,  # G3: 100 (enriched)
    4: 100,  # G4: 100 (enriched)
}

# Split allocation within the 1,000-image cohort
SPLIT_RATIOS = {
    'development': 0.50,    # 500 images
    'validation': 0.25,     # 250 images
    'locked_test': 0.25,    # 250 images (NEVER used for tuning)
}

OUTPUT_DIR = 'results/phase24_clinical_ground_truth'
MANIFEST_PATH = 'data/processed/manifest.csv'
SPLIT_DIR = 'data/splits'


def load_manifest():
    """Load manifest and return labeled images only."""
    images = []
    with open(MANIFEST_PATH, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['dr_grade'] and row['dr_grade'] != 'NaN' and row['dr_grade'] != '':
                try:
                    grade = int(float(row['dr_grade']))
                    if grade in (0, 1, 2, 3, 4):
                        images.append({
                            'image_id': row['image_id'],
                            'dataset': row['dataset'],
                            'dr_grade': grade,
                            'has_lesion_annotation': row.get('has_lesion_annotation', '0') == '1',
                            'width': int(row.get('width', 0)),
                            'height': int(row.get('height', 0)),
                            'file_path': row.get('file_path', ''),
                        })
                except (ValueError, TypeError):
                    continue
    return images


def stratified_sample(images, n_per_grade, seed, exclude_ids=None):
    """Stratified random sampling with grade balancing."""
    if exclude_ids is None:
        exclude_ids = set()

    rng = random.Random(seed)
    selected = []

    # Group by grade
    by_grade = defaultdict(list)
    for img in images:
        if img['image_id'] not in exclude_ids:
            by_grade[img['dr_grade']].append(img)

    for grade, target_count in n_per_grade.items():
        available = by_grade.get(grade, [])
        if len(available) < target_count:
            print(f"  WARNING: G{grade} has only {len(available)} images, need {target_count}")
            selected.extend(available)
        else:
            sampled = rng.sample(available, target_count)
            selected.extend(sampled)

    return selected


def assign_splits(cohort, ratios, seed):
    """Assign development/validation/locked_test splits."""
    rng = random.Random(seed)
    shuffled = list(cohort)
    rng.shuffle(shuffled)

    n = len(shuffled)
    n_dev = int(n * ratios['development'])
    n_val = int(n * ratios['validation'])

    splits = {}
    for i, img in enumerate(shuffled):
        if i < n_dev:
            split = 'development'
        elif i < n_dev + n_val:
            split = 'validation'
        else:
            split = 'locked_test'
        splits[img['image_id']] = split

    return splits


def load_existing_split_ids():
    """Load IDs from existing val and test splits."""
    val_ids = set()
    test_ids = set()
    for split_file, id_set in [('val.csv', val_ids), ('test.csv', test_ids)]:
        path = os.path.join(SPLIT_DIR, split_file)
        if os.path.exists(path):
            with open(path, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    id_set.add(row['image_id'])
    return val_ids | test_ids  # Return combined set of all excluded IDs


def validate_no_leakage(cohort, splits, existing_val_ids, existing_test_ids):
    """Verify no overlap between cohort and existing validation/test sets."""
    cohort_ids = {img['image_id'] for img in cohort}
    val_overlap = cohort_ids & existing_val_ids
    test_overlap = cohort_ids & existing_test_ids
    return val_overlap, test_overlap


def write_cohort_csv(cohort, splits, filepath, include_lesion=False):
    """Write cohort CSV."""
    fieldnames = [
        'image_id', 'dataset', 'dr_grade', 'split',
        'assigned_readers', 'annotation_status',
        'width', 'height', 'has_lesion_annotation'
    ]
    if include_lesion:
        fieldnames.extend([
            'lesion_annotation_status',
            'lesion_MA_status', 'lesion_HE_status',
            'lesion_EX_status', 'lesion_NV_status'
        ])

    with open(filepath, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for img in cohort:
            row = {
                'image_id': img['image_id'],
                'dataset': img['dataset'],
                'dr_grade': img['dr_grade'],
                'split': splits.get(img['image_id'], 'unknown'),
                'assigned_readers': '',
                'annotation_status': 'pending',
                'width': img['width'],
                'height': img['height'],
                'has_lesion_annotation': img['has_lesion_annotation'],
            }
            if include_lesion:
                row['lesion_annotation_status'] = 'pending'
                row['lesion_MA_status'] = 'pending'
                row['lesion_HE_status'] = 'pending'
                row['lesion_EX_status'] = 'pending'
                row['lesion_NV_status'] = 'pending'
            writer.writerow(row)


def main():
    print("=" * 60)
    print("  Phase 24A: Stratified Cohort Sampling")
    print("=" * 60)
    print()

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Load manifest
    print("Loading manifest...")
    all_images = load_manifest()
    print(f"  Total labeled images: {len(all_images)}")

    # Load existing split IDs to exclude
    print("Loading existing val/test split IDs...")
    excluded_ids = load_existing_split_ids()
    print(f"  Excluding {len(excluded_ids)} images already in val/test splits")

    # Filter to images NOT in existing splits
    available_images = [img for img in all_images if img['image_id'] not in excluded_ids]
    print(f"  Available for Phase 24: {len(available_images)} images")

    # Grade distribution
    grade_counts = Counter(img['dr_grade'] for img in available_images)
    print(f"  Grade distribution (available):")
    for g in sorted(grade_counts):
        print(f"    G{g}: {grade_counts[g]} ({grade_counts[g]/len(available_images)*100:.1f}%)")
    print()

    # Select 1,000-image cohort (from available images only)
    print("Selecting 1,000-image DR grading cohort...")
    grading_cohort = stratified_sample(available_images, N_PER_GRADE, SEED)
    print(f"  Selected: {len(grading_cohort)} images")

    # Grade distribution of selected cohort
    selected_grades = Counter(img['dr_grade'] for img in grading_cohort)
    print(f"  Grade distribution:")
    for g in sorted(selected_grades):
        print(f"    G{g}: {selected_grades[g]} ({selected_grades[g]/len(grading_cohort)*100:.1f}%)")
    print()

    # Select 500-image lesion cohort (from available images, enriched for pathology)
    print("Selecting 500-image lesion annotation cohort...")
    lesion_cohort = stratified_sample(available_images, N_LESION_PER_GRADE, SEED + 1)
    print(f"  Selected: {len(lesion_cohort)} images")

    selected_lesion_grades = Counter(img['dr_grade'] for img in lesion_cohort)
    print(f"  Grade distribution:")
    for g in sorted(selected_lesion_grades):
        print(f"    G{g}: {selected_lesion_grades[g]} ({selected_lesion_grades[g]/len(lesion_cohort)*100:.1f}%)")
    print()

    # Assign splits
    print("Assigning splits (50% dev / 25% val / 25% locked_test)...")
    grading_splits = assign_splits(grading_cohort, SPLIT_RATIOS, SEED)
    split_counts = Counter(grading_splits.values())
    for s, c in sorted(split_counts.items()):
        print(f"  {s}: {c} images")
    print()

    # Validate no leakage
    print("Checking for data leakage with existing val/test sets...")
    existing_val_ids = set()
    existing_test_ids = set()
    for split_file, id_set in [('val.csv', existing_val_ids), ('test.csv', existing_test_ids)]:
        path = os.path.join(SPLIT_DIR, split_file)
        if os.path.exists(path):
            with open(path, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    id_set.add(row['image_id'])

    val_overlap, test_overlap = validate_no_leakage(
        grading_cohort, grading_splits, existing_val_ids, existing_test_ids
    )
    if val_overlap:
        print(f"  WARNING: {len(val_overlap)} images overlap with existing val set!")
        for img_id in sorted(val_overlap):
            print(f"    - {img_id}")
    else:
        print("  No overlap with existing val set")

    if test_overlap:
        print(f"  WARNING: {len(test_overlap)} images overlap with existing test set!")
        for img_id in sorted(test_overlap):
            print(f"    - {img_id}")
    else:
        print("  No overlap with existing test set")
    print()

    # Dataset composition
    print("Dataset composition of grading cohort:")
    dataset_counts = Counter(img['dataset'] for img in grading_cohort)
    for ds, c in sorted(dataset_counts.items()):
        print(f"  {ds}: {c} images ({c/len(grading_cohort)*100:.1f}%)")
    print()

    # Write outputs
    print("Writing outputs...")
    grading_path = os.path.join(OUTPUT_DIR, 'phase24_cohort.csv')
    write_cohort_csv(grading_cohort, grading_splits, grading_path)
    print(f"  {grading_path}")

    # Lesion cohort splits (use same split assignment where possible)
    lesion_splits = {}
    for img in lesion_cohort:
        if img['image_id'] in grading_splits:
            lesion_splits[img['image_id']] = grading_splits[img['image_id']]
        else:
            # Assign based on same ratios
            lesion_splits[img['image_id']] = 'development'  # default

    lesion_path = os.path.join(OUTPUT_DIR, 'phase24_lesion_cohort.csv')
    write_cohort_csv(lesion_cohort, lesion_splits, lesion_path, include_lesion=True)
    print(f"  {lesion_path}")

    # Write sampling report
    report_path = os.path.join(OUTPUT_DIR, 'phase24_sampling_report.txt')
    with open(report_path, 'w', encoding='utf-8') as f:
        f.write("Phase 24A: Sampling Report\n")
        f.write("=" * 60 + "\n\n")
        f.write(f"Date: 2026-09-04\n")
        f.write(f"Random seed: {SEED}\n")
        f.write(f"Total labeled images in manifest: {len(all_images)}\n\n")

        f.write("DR GRADING COHORT\n")
        f.write("-" * 40 + "\n")
        f.write(f"Target: {N_TOTAL} images\n")
        f.write(f"Selected: {len(grading_cohort)} images\n")
        f.write(f"Per-grade targets: {json.dumps(N_PER_GRADE)}\n\n")

        f.write("Grade distribution:\n")
        for g in sorted(selected_grades):
            f.write(f"  G{g}: {selected_grades[g]} ({selected_grades[g]/len(grading_cohort)*100:.1f}%)\n")

        f.write(f"\nSplit allocation:\n")
        for s, c in sorted(split_counts.items()):
            f.write(f"  {s}: {c} ({c/len(grading_cohort)*100:.1f}%)\n")

        f.write(f"\nDataset composition:\n")
        for ds, c in sorted(dataset_counts.items()):
            f.write(f"  {ds}: {c} ({c/len(grading_cohort)*100:.1f}%)\n")

        f.write(f"\nData leakage check:\n")
        f.write(f"  Val overlap: {len(val_overlap)} images\n")
        f.write(f"  Test overlap: {len(test_overlap)} images\n")

        f.write("\n\nLESION ANNOTATION COHORT\n")
        f.write("-" * 40 + "\n")
        f.write(f"Target: {N_LESION} images\n")
        f.write(f"Selected: {len(lesion_cohort)} images\n")
        f.write(f"Per-grade targets: {json.dumps(N_LESION_PER_GRADE)}\n\n")

        f.write("Grade distribution:\n")
        for g in sorted(selected_lesion_grades):
            f.write(f"  G{g}: {selected_lesion_grades[g]} ({selected_lesion_grades[g]/len(lesion_cohort)*100:.1f}%)\n")

        f.write("\nLesion types to annotate:\n")
        f.write("  - Microaneurysms (MA)\n")
        f.write("  - Hemorrhages (HE)\n")
        f.write("  - Hard Exudates (EX)\n")
        f.write("  - Neovascularization (NV)\n")

    print(f"  {report_path}")
    print()
    print("Phase 24A COMPLETE")


if __name__ == '__main__':
    main()
