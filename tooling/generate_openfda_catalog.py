#!/usr/bin/env python3
"""Build a compact, offline drug-product index from the official openFDA NDC API."""

from __future__ import annotations

import argparse
import json
import re
import time
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path


API = "https://api.fda.gov/drug/ndc.json"


def _text(value: object) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def _request(skip: int, limit: int) -> dict:
    query = urllib.parse.urlencode(
        {"search": "finished:true", "limit": limit, "skip": skip}
    )
    request = urllib.request.Request(
        f"{API}?{query}",
        headers={"User-Agent": "MyHealth-catalog-builder/1.0"},
    )
    with urllib.request.urlopen(request, timeout=90) as response:
        return json.load(response)


def _ingredient_text(item: dict) -> str:
    ingredients = []
    for raw in item.get("active_ingredients") or []:
        if not isinstance(raw, dict):
            continue
        name = _text(raw.get("name"))
        strength = _text(raw.get("strength"))
        if name:
            ingredients.append(f"{name} {strength}".strip())
    return "; ".join(ingredients)


def _catalog_item(item: dict, index: int) -> dict | None:
    generic = _text(item.get("generic_name"))
    if not generic:
        return None
    brand = _text(item.get("brand_name"))
    dosage_form = _text(item.get("dosage_form"))
    routes = ", ".join(_text(value) for value in item.get("route") or [] if value)
    ingredients = _ingredient_text(item)
    classes = "; ".join(
        _text(value) for value in item.get("pharm_class") or [] if value
    )
    product_type = _text(item.get("product_type")) or "Human drug product"
    product_ndc = _text(item.get("product_ndc"))
    details = [
        f"Active ingredients: {ingredients}" if ingredients else "",
        f"Pharmacologic class: {classes}" if classes else "",
        f"Dosage form: {dosage_form}" if dosage_form else "",
        f"Route: {routes}" if routes else "",
        f"Brand example: {brand}" if brand and brand.lower() != generic.lower() else "",
    ]
    purpose = ". ".join(value for value in details if value)
    if not purpose:
        purpose = "Product identity from the FDA National Drug Code Directory."
    return {
        "id": f"openfda-ndc-{index:05d}",
        "title": generic,
        "titleEn": generic,
        "category": f"openFDA NDC: {product_type}"
        + (f", {dosage_form}" if dosage_form else ""),
        "purpose": purpose,
        "warnings": (
            "Справочная запись о составе и форме выпуска, а не показание к применению. "
            "Наличие NDC не означает одобрение FDA. Сверьте точный препарат, инструкцию, "
            "противопоказания и назначение с врачом или фармацевтом."
        ),
        "interactions": (
            "В этой индексной записи взаимодействия не перечислены. Проверяйте инструкцию "
            "именно к вашему препарату и весь список лекарств у врача или фармацевта."
        ),
        "frequencyNote": (
            "Приложение не рассчитывает дозу и частоту приёма. Используйте только схему "
            "из подтверждённого назначения врача или официальной инструкции."
        ),
        "sourceUrl": (
            f"https://api.fda.gov/drug/ndc.json?search=product_ndc:{urllib.parse.quote(product_ndc)}"
            if product_ndc
            else "https://open.fda.gov/apis/drug/ndc/"
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pages", type=int, default=12)
    parser.add_argument("--limit", type=int, default=1000)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("assets/catalog/openfda_substances.json"),
    )
    args = parser.parse_args()

    selected: dict[str, dict] = {}
    meta: dict = {}
    for page in range(args.pages):
        payload = _request(page * args.limit, args.limit)
        meta = payload.get("meta") or meta
        for raw in payload.get("results") or []:
            if not isinstance(raw, dict):
                continue
            generic = _text(raw.get("generic_name"))
            key = generic.casefold()
            if not key or key in selected:
                continue
            selected[key] = raw
        print(f"page {page + 1}/{args.pages}: {len(selected)} unique generic products")
        time.sleep(0.15)

    substances = []
    for index, raw in enumerate(
        sorted(selected.values(), key=lambda value: _text(value.get("generic_name")).casefold()),
        start=1,
    ):
        converted = _catalog_item(raw, index)
        if converted is not None:
            substances.append(converted)

    result = {
        "version": 1,
        "updated": date.today().isoformat(),
        "source": "FDA National Drug Code Directory through openFDA",
        "sourceUrl": "https://open.fda.gov/apis/drug/ndc/",
        "disclaimer": _text(meta.get("disclaimer")),
        "substances": substances,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"wrote {len(substances)} entries to {args.output}")


if __name__ == "__main__":
    main()
