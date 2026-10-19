#!/usr/bin/env python3
"""Copy an idXML with a selected PSM score as its primary score."""

import argparse
import math

import pyopenms as oms


def as_text(value):
    """Decode OpenMS string values consistently across pyOpenMS versions."""
    return value.decode() if isinstance(value, bytes) else str(value)


def probability(value, score_type, reference):
    """Require a finite probability for PEP and q-value scores."""
    try:
        score = float(value)
    except (TypeError, ValueError) as error:
        raise ValueError(f"Non-numeric {score_type} for spectrum {reference}: {value}") from error
    if not math.isfinite(score) or not 0 <= score <= 1:
        raise ValueError(
            f"{score_type} for spectrum {reference} must be between 0 and 1: {score}"
        )
    return score


def main():
    """Select and validate a score for every PSM hit before conversion."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--source-score", required=True)
    parser.add_argument("--target-score", choices=("PEP", "q-value"), required=True)
    args = parser.parse_args()

    proteins:list[oms.ProteinIdentification] = []
    peptides:list[oms.PeptideIdentification] = []
    oms.IdXMLFile().load(args.input, proteins, peptides)

    count = 0
    for identification in peptides:
        original_type = as_text(identification.getScoreType())
        higher_score_better = identification.isHigherScoreBetter()
        reference = (as_text(identification.getMetaValue("spectrum_reference"))
                     if identification.metaValueExists("spectrum_reference") else "unknown")
        if higher_score_better and original_type in ("PEP", "q-value"):
            raise ValueError(
                f"Input {original_type} for spectrum {reference} cannot have higher_score_better=true"
            )
        if higher_score_better:
            raise ValueError(
                f"Selected {args.target_score} for spectrum {reference} cannot retain "
                "higher_score_better=true from the input identification"
            )
        hits = []
        for hit in identification.getHits():
            if original_type in ("PEP", "q-value"):
                probability(hit.getScore(), original_type, reference)
            if original_type == args.source_score:
                raw_score = hit.getScore()
            elif hit.metaValueExists(args.source_score):
                raw_score = hit.getMetaValue(args.source_score)
            else:
                raise ValueError(
                    f"Missing score '{args.source_score}' for spectrum {reference}"
                )
            score = probability(raw_score, args.target_score, reference)
            if original_type != args.target_score or hit.getScore() != score:
                hit.setMetaValue("easypqp_original_score", hit.getScore())
            hit.setScore(score)
            hits.append(hit)
            count += 1
        identification.setHits(hits)
        identification.setScoreType(args.target_score)
        identification.setHigherScoreBetter(higher_score_better)

    if count == 0:
        raise ValueError(f"No PSM hits found in {args.input}")
    oms.IdXMLFile().store(args.output, proteins, peptides)
    print(f"Prepared {count} PSM hits with {args.target_score} scores from {args.source_score}")


if __name__ == "__main__":
    main()
