"""Build the bundled food catalog from the Open Food Facts CSV export.

The export is scanned remotely by DuckDB and only the most-scanned products
with a name, image, and calorie value are materialized in the project CSV.
"""

from __future__ import annotations

import argparse
import csv
import math
import re
from pathlib import Path

import duckdb


EXPORT_URL = "https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz"
FIELDNAMES = (
    "id",
    "title_ru",
    "title_en",
    "category",
    "kind",
    "calories",
    "protein",
    "fat",
    "carbs",
    "sugar",
    "carb_type",
    "fiber",
    "alcohol",
    "salt",
    "health_level",
    "composition",
    "ingredients",
    "preparation",
    "minutes",
    "cost",
    "image",
    "video",
    "history",
    "doctor_review",
    "source_url",
    "data_license",
)


def clean(value: object, limit: int = 1200) -> str:
    if value is None:
        return ""
    text = re.sub(r"\s+", " ", str(value)).strip()
    return text[:limit]


def number(value: object, maximum: float) -> float:
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        return 0.0
    if not math.isfinite(parsed) or parsed < 0:
        return 0.0
    return min(parsed, maximum)


def rounded(value: object, maximum: float) -> int:
    return round(number(value, maximum))


def decimal(value: object, maximum: float) -> str:
    parsed = number(value, maximum)
    if parsed == 0:
        return "0"
    return f"{parsed:.2f}".rstrip("0").rstrip(".")


def health_level(grade: object) -> int:
    return {"a": 9, "b": 8, "c": 6, "d": 4, "e": 2}.get(
        clean(grade).lower(),
        5,
    )


def kind_for(categories: str, title: str) -> str:
    text = f"{categories} {title}".lower()
    if any(token in text for token in ("beverage", "drink", "water", "juice", "soda")):
        return "drink"
    if any(token in text for token in ("chocolate", "candy", "sweet", "confection")):
        return "sweet"
    if any(token in text for token in ("meal", "dish", "pizza", "soup", "salad")):
        return "meal"
    return "product"


def carb_type(carbs: int, sugar: int) -> str:
    if carbs <= 0:
        return ""
    ratio = sugar / carbs
    if ratio >= 0.5:
        return "простые"
    if ratio <= 0.25:
        return "сложные"
    return "смешанные"


def product_title(name: object, brand: object, quantity: object, code: str) -> str:
    title = clean(name, 180)
    brand_text = clean(brand, 80)
    quantity_text = clean(quantity, 40)
    if brand_text and brand_text.casefold() not in title.casefold():
        title = f"{title} — {brand_text}"
    if quantity_text and quantity_text.casefold() not in title.casefold():
        title = f"{title}, {quantity_text}"
    return f"{title} [{code}]"


def query_products(limit: int) -> list[tuple[object, ...]]:
    connection = duckdb.connect()
    connection.execute("SET threads TO 4")
    query = """
        SELECT
          code,
          product_name,
          brands,
          quantity,
          categories_en,
          ingredients_text,
          nutriscore_grade,
          image_small_url,
          url,
          try_cast("energy-kcal_100g" AS DOUBLE) AS calories,
          try_cast(fat_100g AS DOUBLE) AS fat,
          try_cast(carbohydrates_100g AS DOUBLE) AS carbs,
          try_cast(sugars_100g AS DOUBLE) AS sugar,
          try_cast(fiber_100g AS DOUBLE) AS fiber,
          try_cast(proteins_100g AS DOUBLE) AS protein,
          try_cast(salt_100g AS DOUBLE) AS salt,
          try_cast(alcohol_100g AS DOUBLE) AS alcohol,
          try_cast(unique_scans_n AS BIGINT) AS scans
        FROM read_csv_auto(
          ?,
          delim='\t',
          header=true,
          all_varchar=true,
          ignore_errors=true,
          compression='gzip'
        )
        WHERE trim(coalesce(product_name, '')) <> ''
          AND length(product_name) BETWEEN 2 AND 180
          AND image_small_url LIKE 'https://%'
          AND image_small_url NOT LIKE '%/invalid/%'
          AND try_cast("energy-kcal_100g" AS DOUBLE) BETWEEN 1 AND 1000
          AND try_cast(unique_scans_n AS BIGINT) IS NOT NULL
        ORDER BY scans DESC, code
        LIMIT ?
    """
    return connection.execute(query, [EXPORT_URL, limit]).fetchall()


def build_rows(products: list[tuple[object, ...]]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for index, product in enumerate(products, start=1):
        (
            code,
            name,
            brands,
            quantity,
            categories,
            ingredients,
            grade,
            image,
            source_url,
            calories_value,
            fat_value,
            carbs_value,
            sugar_value,
            fiber_value,
            protein_value,
            salt_value,
            alcohol_value,
            _scans,
        ) = product
        code_text = clean(code, 40)
        title = product_title(name, brands, quantity, code_text)
        category_text = clean(categories, 300)
        ingredients_text = clean(ingredients)
        carbs = rounded(carbs_value, 100)
        sugar = rounded(sugar_value, 100)
        alcohol = number(alcohol_value, 100)
        rows.append(
            {
                "id": f"off-{code_text or index}",
                "title_ru": title,
                "title_en": title,
                "category": category_text.split(",")[0] if category_text else "food",
                "kind": kind_for(category_text, title),
                "calories": rounded(calories_value, 1000),
                "protein": rounded(protein_value, 100),
                "fat": rounded(fat_value, 100),
                "carbs": carbs,
                "sugar": sugar,
                "carb_type": carb_type(carbs, sugar),
                "fiber": rounded(fiber_value, 100),
                "alcohol": decimal(alcohol, 100) if alcohol > 0 else "",
                "salt": decimal(salt_value, 100),
                "health_level": health_level(grade),
                "composition": ingredients_text or category_text,
                "ingredients": ingredients_text,
                "preparation": "",
                "minutes": 0,
                "cost": 0,
                "image": clean(image, 500),
                "video": "",
                "history": "",
                "doctor_review": "",
                "source_url": clean(source_url, 500),
                "data_license": "Open Food Facts — ODbL 1.0",
            }
        )
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=10000)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parents[1]
        / "tooling"
        / "food_catalog_real.csv",
    )
    args = parser.parse_args()
    print(f"Scanning Open Food Facts export for top {args.limit} products...", flush=True)
    candidates = build_rows(query_products(args.limit + 200))
    rows = [
        row
        for row in candidates
        if "\ufffd" not in "".join(str(value) for value in row.values())
    ][: args.limit]
    if len(rows) != args.limit:
        raise RuntimeError(f"Expected {args.limit} products, received {len(rows)}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=FIELDNAMES, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {len(rows)} real products to {args.output}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
