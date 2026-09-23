"""Fill transparent safety and nutrition notes in bundled CSV catalogs.

This is deterministic and does not download or invent media. Existing editorial
content is preserved; only blank preparation and doctor_review cells are filled.
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

from import_open_food_facts import nutrition_review, preparation_note
from import_wger_workouts import workout_review


def integer(value: str) -> int:
    try:
        return int(round(float(value or 0)))
    except ValueError:
        return 0


def decimal(value: str) -> float:
    try:
        return float((value or "0").replace(",", "."))
    except ValueError:
        return 0.0


def rewrite(path: Path, transform) -> int:
    with path.open(encoding="utf-8", newline="") as source:
        reader = csv.DictReader(source)
        fieldnames = reader.fieldnames or []
        rows = [transform(dict(row)) for row in reader]
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    temporary.replace(path)
    return len(rows)


def enrich_food(row: dict[str, str]) -> dict[str, str]:
    kind = row.get("kind", "product")
    if not row.get("preparation", "").strip():
        row["preparation"] = preparation_note(kind)
    if not row.get("doctor_review", "").strip():
        row["doctor_review"] = nutrition_review(
            kind=kind,
            health=integer(row.get("health_level", "")),
            calories=integer(row.get("calories", "")),
            protein=integer(row.get("protein", "")),
            sugar=integer(row.get("sugar", "")),
            fiber=integer(row.get("fiber", "")),
            salt=decimal(row.get("salt", "")),
            alcohol=decimal(row.get("alcohol", "")),
        )
    return row


def enrich_workout(row: dict[str, str]) -> dict[str, str]:
    if not row.get("doctor_review", "").strip():
        row["doctor_review"] = workout_review(
            row.get("level", ""),
            row.get("equipment", ""),
            integer(row.get("calories", "")),
            integer(row.get("minutes", "")),
        )
    return row


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--root", type=Path, default=Path(__file__).resolve().parents[1]
    )
    args = parser.parse_args()
    catalog = args.root / "assets" / "catalog"
    foods = rewrite(catalog / "food_catalog.csv", enrich_food)
    workouts = rewrite(catalog / "workout_catalog.csv", enrich_workout)
    print(f"Enriched {foods} food cards and {workouts} workout cards")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
