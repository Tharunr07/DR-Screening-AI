"""
agreement_engine.py — Phase 24 Inter-Reader Agreement Calculator

Computes Fleiss kappa, Cohen kappa, pairwise agreement, per-class metrics,
and Dice/IoU for lesion masks.
"""

import csv
import os
import numpy as np
from collections import Counter, defaultdict
from itertools import combinations
from pathlib import Path

from annotation_schema import (
    load_grading_annotations, load_lesion_mask, READER_IDS,
    LESION_TYPES, ANNOTATION_DIR, CONSENSUS_DIR, GRADING_DIR
)


def compute_cohens_kappa(annotations_r1, annotations_r2):
    """Compute Cohen's kappa between two readers."""
    # Match on image_id
    r1_dict = {a['image_id']: a['dr_grade'] for a in annotations_r1}
    r2_dict = {a['image_id']: a['dr_grade'] for a in annotations_r2}

    common = set(r1_dict.keys()) & set(r2_dict.keys())
    if len(common) == 0:
        return {'kappa': 0, 'n': 0, 'agreement': 0}

    labels = sorted(set(list(r1_dict.values()) + list(r2_dict.values())))
    n = len(common)

    # Build confusion matrix
    cm = np.zeros((len(labels), len(labels)), dtype=int)
    label_to_idx = {l: i for i, l in enumerate(labels)}

    for img_id in common:
        i = label_to_idx[r1_dict[img_id]]
        j = label_to_idx[r2_dict[img_id]]
        cm[i, j] += 1

    # Compute kappa
    p_o = np.trace(cm) / n  # Observed agreement
    p_e = 0
    for i in range(len(labels)):
        row_sum = np.sum(cm[i, :])
        col_sum = np.sum(cm[:, i])
        p_e += (row_sum / n) * (col_sum / n)

    if p_e == 1:
        kappa = 1.0
    else:
        kappa = (p_o - p_e) / (1 - p_e)

    return {
        'kappa': round(kappa, 4),
        'n': n,
        'agreement': round(p_o, 4),
        'labels': labels,
        'confusion_matrix': cm.tolist()
    }


def compute_fleiss_kappa(all_annotations):
    """Compute Fleiss' kappa for multiple readers.

    all_annotations: dict of reader_id -> list of annotations
    """
    # Build per-image, per-reader grade matrix
    readers = list(all_annotations.keys())
    r_dicts = {r: {a['image_id']: a['dr_grade'] for a in all_annotations[r]} for r in readers}

    # Find common images
    common = set.intersection(*[set(d.keys()) for d in r_dicts.values()])
    if len(common) == 0:
        return {'kappa': 0, 'n': 0}

    # Get all labels
    all_grades = set()
    for d in r_dicts.values():
        all_grades.update(d.values())
    labels = sorted(all_grades)
    label_to_idx = {l: i for i, l in enumerate(labels)}

    n = len(common)
    k = len(readers)
    n_categories = len(labels)

    # Build category assignment matrix
    # N_ij = number of raters who assigned item i to category j
    N = np.zeros((n, n_categories), dtype=int)

    for i, img_id in enumerate(sorted(common)):
        for r in readers:
            grade = r_dicts[r][img_id]
            N[i, label_to_idx[grade]] += 1

    # Compute Fleiss' kappa
    # P_i = (1 / (k*(k-1))) * (sum_j(N_ij^2) - k)
    P_i = (1.0 / (k * (k - 1))) * (np.sum(N**2, axis=1) - k)
    P_bar = np.mean(P_i)

    # p_j = fraction of all assignments to category j
    p_j = np.sum(N, axis=0) / (n * k)

    # P_e_bar = sum_j(p_j^2)
    P_e_bar = np.sum(p_j**2)

    if P_e_bar == 1:
        kappa = 1.0
    else:
        kappa = (P_bar - P_e_bar) / (1 - P_e_bar)

    return {
        'kappa': round(kappa, 4),
        'n': n,
        'n_readers': k,
        'per_image_agreement': P_i.tolist(),
        'mean_agreement': round(P_bar, 4),
        'categories': labels
    }


def compute_per_grade_agreement(all_annotations):
    """Compute agreement metrics for each DR grade."""
    readers = list(all_annotations.keys())
    r_dicts = {r: {a['image_id']: a['dr_grade'] for a in all_annotations[r]} for r in readers}
    common = set.intersection(*[set(d.keys()) for d in r_dicts.values()])

    grades = sorted(set(r_dicts[r][img] for r in readers for img in common))
    results = {}

    for grade in grades:
        # For each image where at least one reader assigned this grade
        n_images = 0
        n_all_agree = 0
        n_majority_agree = 0

        for img_id in common:
            assigned = [r_dicts[r][img_id] for r in readers]
            if grade in assigned:
                n_images += 1
                if all(a == grade for a in assigned):
                    n_all_agree += 1
                elif sum(a == grade for a in assigned) >= 2:
                    n_majority_agree += 1

        results[grade] = {
            'n_images_with_grade': n_images,
            'full_agreement': n_all_agree,
            'majority_agreement': n_majority_agree,
            'full_agreement_rate': round(n_all_agree / max(n_images, 1), 4),
            'majority_agreement_rate': round(n_majority_agree / max(n_images, 1), 4)
        }

    return results


def compute_reader_pairwise(all_annotations):
    """Compute pairwise agreement between all reader pairs."""
    readers = list(all_annotations.keys())
    pairs = list(combinations(readers, 2))

    results = {}
    for r1, r2 in pairs:
        ann_r1 = all_annotations[r1]
        ann_r2 = all_annotations[r2]
        result = compute_cohens_kappa(ann_r1, ann_r2)
        results[f'{r1}_vs_{r2}'] = result

    return results


def compute_reader_confusion(all_annotations):
    """Compute reader-vs-reader confusion patterns."""
    readers = list(all_annotations.keys())
    r_dicts = {r: {a['image_id']: a['dr_grade'] for a in all_annotations[r]} for r in readers}
    common = set.intersection(*[set(d.keys()) for d in r_dicts.values()])

    # For each reader pair, compute grade-wise confusion
    confusion = {}
    for r1, r2 in combinations(readers, 2):
        cm = defaultdict(int)
        for img_id in common:
            g1 = r_dicts[r1][img_id]
            g2 = r_dicts[r2][img_id]
            cm[(g1, g2)] += 1
        confusion[f'{r1}_vs_{r2}'] = dict(cm)

    return confusion


def compute_dice_score(mask1, mask2):
    """Compute Dice coefficient between two binary masks."""
    if mask1 is None or mask2 is None:
        return None

    intersection = np.sum(mask1 & mask2)
    total = np.sum(mask1) + np.sum(mask2)

    if total == 0:
        return 1.0  # Both empty = perfect agreement

    return 2 * intersection / total


def compute_iou_score(mask1, mask2):
    """Compute IoU (Jaccard index) between two binary masks."""
    if mask1 is None or mask2 is None:
        return None

    intersection = np.sum(mask1 & mask2)
    union = np.sum(mask1 | mask2)

    if union == 0:
        return 1.0  # Both empty = perfect agreement

    return intersection / union


def compute_lesion_agreement(reader_id, image_id, lesion_type):
    """Compute lesion mask agreement for a specific image."""
    masks = {}
    for rid in READER_IDS:
        masks[rid] = load_lesion_mask(rid, image_id, lesion_type)

    dice_scores = {}
    iou_scores = {}
    for r1, r2 in combinations(READER_IDS, 2):
        d = compute_dice_score(masks[r1], masks[r2])
        i = compute_iou_score(masks[r1], masks[r2])
        dice_scores[f'{r1}_vs_{r2}'] = d
        iou_scores[f'{r1}_vs_{r2}'] = i

    # Average across pairs
    valid_dice = [v for v in dice_scores.values() if v is not None]
    avg_dice = round(np.mean(valid_dice), 4) if valid_dice else None

    return {
        'image_id': image_id,
        'lesion_type': lesion_type,
        'dice_scores': dice_scores,
        'iou_scores': iou_scores,
        'mean_dice': avg_dice
    }


def compute_lesion_agreement_summary():
    """Compute summary of lesion mask agreement across all images."""
    # Load lesion annotations
    lesion_data = []
    for rid in READER_IDS:
        csv_path = os.path.join(ANNOTATION_DIR, 'lesions', rid, f'{rid}_lesions.csv')
        if os.path.exists(csv_path):
            with open(csv_path, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    lesion_data.append(row)

    # Group by image_id and lesion_type
    by_image = defaultdict(lambda: defaultdict(list))
    for row in lesion_data:
        by_image[row['image_id']][row['lesion_type']].append(row['reader_id'])

    # Compute agreement for each image/lesion combination
    all_dice = defaultdict(list)
    for image_id, lesions in by_image.items():
        for lesion_type, readers in lesions.items():
            if len(readers) >= 2:  # Need at least 2 readers
                result = compute_lesion_agreement(None, image_id, lesion_type)
                if result['mean_dice'] is not None:
                    all_dice[lesion_type].append(result['mean_dice'])

    # Summary per lesion type
    summary = {}
    for lt in LESION_TYPES:
        scores = all_dice.get(lt, [])
        if scores:
            summary[lt] = {
                'n_images': len(scores),
                'mean_dice': round(np.mean(scores), 4),
                'std_dice': round(np.std(scores), 4),
                'min_dice': round(min(scores), 4),
                'max_dice': round(max(scores), 4),
                'p25_dice': round(np.percentile(scores, 25), 4),
                'p75_dice': round(np.percentile(scores, 75), 4)
            }
        else:
            summary[lt] = {'n_images': 0, 'mean_dice': None}

    return summary


def compute_full_agreement_report():
    """Compute the complete agreement report."""
    # Load all annotations
    all_annotations = {}
    for rid in READER_IDS:
        ann = load_grading_annotations(rid)
        if ann:
            all_annotations[rid] = ann

    if len(all_annotations) < 2:
        return {
            'error': f'Need at least 2 readers with annotations. Found: {list(all_annotations.keys())}',
            'n_readers': len(all_annotations)
        }

    # DR Grade agreement
    fleiss = compute_fleiss_kappa(all_annotations)
    pairwise = compute_reader_pairwise(all_annotations)
    per_grade = compute_per_grade_agreement(all_annotations)
    confusion = compute_reader_confusion(all_annotations)

    # Lesion agreement
    lesion_summary = compute_lesion_agreement_summary()

    # Overall statistics
    n_readers = len(all_annotations)
    n_images = len(set.intersection(*[set(a['image_id'] for a in ann) for ann in all_annotations.values()])) if all_annotations else 0

    # Disagreement cases
    disagreement_cases = []
    if all_annotations:
        r_dicts = {r: {a['image_id']: a['dr_grade'] for a in all_annotations[r]} for r in all_annotations}
        common = set.intersection(*[set(d.keys()) for d in r_dicts.values()])
        for img_id in common:
            grades = {r: r_dicts[r][img_id] for r in all_annotations}
            unique = set(grades.values())
            if len(unique) > 1:
                disagreement_cases.append({
                    'image_id': img_id,
                    'grades': grades,
                    'type': 'full' if len(unique) == 3 else 'partial'
                })

    return {
        'n_readers': n_readers,
        'n_images': n_images,
        'fleiss_kappa': fleiss,
        'pairwise_kappa': pairwise,
        'per_grade_agreement': per_grade,
        'reader_confusion': confusion,
        'lesion_agreement': lesion_summary,
        'disagreement_cases': disagreement_cases,
        'n_disagreements': len(disagreement_cases),
        'disagreement_rate': round(len(disagreement_cases) / max(n_images, 1), 4)
    }


if __name__ == '__main__':
    print("Computing agreement report...")
    report = compute_full_agreement_report()
    if 'error' in report:
        print(f"Error: {report['error']}")
    else:
        print(f"Readers: {report['n_readers']}")
        print(f"Images: {report['n_images']}")
        print(f"Fleiss kappa: {report['fleiss_kappa']['kappa']}")
        print(f"Disagreements: {report['n_disagreements']}/{report['n_images']}")
        print(f"Disagreement rate: {report['disagreement_rate']*100:.1f}%")
