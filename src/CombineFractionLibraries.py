#!/usr/bin/env python3
"""Combine fraction-specific EasyPQP TSVs without collapsing fragment rows."""

import argparse
import csv
import shutil


def parse_fraction(value):
    """Split a fraction identifier from its library path."""
    fraction_id, separator, path = value.partition(":")
    if not separator or not fraction_id or not path:
        raise argparse.ArgumentTypeError("Expected FRACTION_ID:LIBRARY_TSV")
    return fraction_id, path


def combine(fractions, output, annotate):
    """Append a fraction column while retaining every input row."""
    if not annotate:
        if len(fractions) != 1:
            raise ValueError("Unfractionated input must produce exactly one library")
        shutil.copyfile(fractions[0][1], output)
        return

    expected_header = None
    with open(output, "w", encoding="utf-8", newline="") as destination:
        writer = None
        for fraction_id, path in fractions:
            with open(path, "r", encoding="utf-8", newline="") as source:
                reader = csv.DictReader(source, delimiter="\t")
                header = reader.fieldnames
                if not header:
                    raise ValueError(f"Empty library or missing header: {path}")
                if any(not name for name in header) or len(header) != len(set(header)):
                    raise ValueError(f"Missing or duplicate library column: {path}")
                if "fraction_id" in header:
                    raise ValueError(f"Input library already has fraction_id: {path}")
                if expected_header is None:
                    expected_header = header
                    writer = csv.DictWriter(
                        destination,
                        fieldnames=[*header, "fraction_id"],
                        delimiter="\t",
                        lineterminator="\n",
                    )
                    writer.writeheader()
                elif header != expected_header:
                    raise ValueError(f"Library columns differ for fraction {fraction_id}: {path}")
                for row in reader:
                    if None in row or any(value is None for value in row.values()):
                        raise ValueError(f"Malformed library row: {path}")
                    row["fraction_id"] = fraction_id
                    writer.writerow(row)


def main():
    """Read fraction libraries and write the published cohort library."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True)
    parser.add_argument("--annotate", action="store_true")
    parser.add_argument("--fraction", action="append", type=parse_fraction, required=True)
    args = parser.parse_args()
    fraction_ids = [fraction_id for fraction_id, _ in args.fraction]
    if len(fraction_ids) != len(set(fraction_ids)):
        parser.error("Each fraction_id must occur exactly once")
    combine(args.fraction, args.output, args.annotate)


if __name__ == "__main__":
    main()
