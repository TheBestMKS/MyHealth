"""Create dedicated Russian fields for the large food and workout CSV catalogs."""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
from pathlib import Path

import ctranslate2
from transformers import AutoTokenizer


TARGET = "rus_Cyrl"
LANGUAGE_HINTS = {
    "jpn_Jpan": re.compile(r"[぀-ヿ]"),
    "kor_Hang": re.compile(r"[가-힯]"),
    "arb_Arab": re.compile(r"[؀-ۿ]"),
    "zho_Hans": re.compile(r"[㐀-䶿一-鿿]"),
    "fra_Latn": re.compile(r"[àâçéèêëîïôùûüÿœ]|\b(?:avec|sans|de|du|aux|fromage|lait|pain)\b", re.I),
    "ita_Latn": re.compile(r"[àèéìòù]|\b(?:con|senza|lento|avanti|seduto|petto|spalla)\b", re.I),
    "deu_Latn": re.compile(r"[äöüß]|\b(?:mit|ohne|und|übung|kniebeuge)\b", re.I),
    "spa_Latn": re.compile(r"[áéíóúñ¿¡]|\b(?:con|sin|ejercicio|sentado|leche)\b", re.I),
    "por_Latn": re.compile(r"[ãõç]|\b(?:com|sem|exercício|leite)\b", re.I),
}
KIND_RU = {
    "meal": "блюдо",
    "product": "продукт",
    "drink": "напиток",
    "sweet": "сладость",
}


def load_rows(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open("r", encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        return list(reader.fieldnames or []), list(reader)


def save_rows(path: Path, fields: list[str], rows: list[dict[str, str]]) -> None:
    temporary = path.with_suffix(path.suffix + ".part")
    with temporary.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    field: (row.get(field, "") or "")
                    .replace("\r\n", "\n")
                    .replace("\r", "\n")
                    .replace("\n", r"\n")
                    for field in fields
                }
            )
    temporary.replace(path)


def source_language(text: str) -> str:
    for language, pattern in LANGUAGE_HINTS.items():
        if pattern.search(text):
            return language
    return "eng_Latn"


def needs_translation(text: str) -> bool:
    cyrillic = len(re.findall(r"[А-Яа-яЁё]", text))
    letters = sum(character.isalpha() for character in text)
    return letters >= 2 and cyrillic < max(2, letters // 2)


def split_fragments(text: str, limit: int = 420) -> list[str]:
    if len(text) <= limit:
        return [text]
    result: list[str] = []
    for paragraph in re.split(r"\n+", text):
        paragraph = paragraph.strip()
        if not paragraph:
            continue
        sentences = re.split(r"(?<=[.!?;:])\s+", paragraph)
        current = ""
        for sentence in sentences:
            if len(sentence) > limit:
                if current:
                    result.append(current)
                    current = ""
                result.extend(
                    sentence[offset : offset + limit]
                    for offset in range(0, len(sentence), limit)
                )
            elif not current:
                current = sentence
            elif len(current) + len(sentence) + 1 <= limit:
                current += " " + sentence
            else:
                result.append(current)
                current = sentence
        if current:
            result.append(current)
    return result or [text[:limit]]


class CatalogTranslator:
    def __init__(self, model_dir: Path, cache_path: Path) -> None:
        self.model_dir = model_dir
        self.cache_path = cache_path
        self.cache: dict[str, str] = (
            json.loads(cache_path.read_text(encoding="utf-8"))
            if cache_path.exists()
            else {}
        )
        self.translator = ctranslate2.Translator(
            str(model_dir),
            device="cpu",
            compute_type="int8",
            inter_threads=1,
            intra_threads=max(1, (os.cpu_count() or 4) - 1),
        )
        self.tokenizers: dict[str, object] = {}

    def tokenizer(self, language: str):
        if language not in self.tokenizers:
            self.tokenizers[language] = AutoTokenizer.from_pretrained(
                self.model_dir,
                src_lang=language,
                use_fast=False,
            )
        return self.tokenizers[language]

    def translate_values(self, values: list[str]) -> None:
        pending_by_language: dict[str, list[str]] = {}
        for value in values:
            if not needs_translation(value):
                continue
            for fragment in split_fragments(value):
                language = source_language(fragment)
                key = f"{language}\u241f{fragment}"
                if key not in self.cache:
                    pending_by_language.setdefault(language, []).append(fragment)
        for language, pending in pending_by_language.items():
            unique = list(dict.fromkeys(pending))
            tokenizer = self.tokenizer(language)
            batch_size = 24
            for offset in range(0, len(unique), batch_size):
                batch = unique[offset : offset + batch_size]
                sources = [
                    tokenizer.convert_ids_to_tokens(tokenizer.encode(text))
                    for text in batch
                ]
                results = self.translator.translate_batch(
                    sources,
                    target_prefix=[[TARGET] for _ in batch],
                    beam_size=1,
                    max_batch_size=batch_size,
                )
                for source, result in zip(batch, results):
                    tokens = result.hypotheses[0][1:]
                    translated = tokenizer.decode(
                        tokenizer.convert_tokens_to_ids(tokens),
                        skip_special_tokens=True,
                    ).strip()
                    self.cache[f"{language}\u241f{source}"] = translated or source
                self.cache_path.write_text(
                    json.dumps(self.cache, ensure_ascii=False),
                    encoding="utf-8",
                )
                print(
                    f"{language}: {min(offset + len(batch), len(unique))}/{len(unique)}",
                    flush=True,
                )

    def translate(self, value: str) -> str:
        value = (value or "").replace(r"\n", "\n").strip()
        if not needs_translation(value):
            return value
        translated: list[str] = []
        for fragment in split_fragments(value):
            language = source_language(fragment)
            translated.append(self.cache.get(f"{language}\u241f{fragment}", fragment))
        return "\n".join(translated)


def localize_workouts(root: Path, translator: CatalogTranslator) -> None:
    path = root / "assets" / "catalog" / "workout_catalog.csv"
    fields, rows = load_rows(path)
    new_fields = [
        "focus_ru",
        "equipment_ru",
        "description_ru",
        "requirements_ru",
        "steps_ru",
        "warnings_ru",
        "history_ru",
    ]
    for field in new_fields:
        if field not in fields:
            fields.append(field)
    values: list[str] = []
    for row in rows:
        values.extend(
            [
                row.get("title_en", ""),
                row.get("focus", ""),
                row.get("equipment", ""),
                row.get("description", ""),
                row.get("steps", ""),
                row.get("history", ""),
            ]
        )
    translator.translate_values(values)
    for index, row in enumerate(rows, 1):
        original_title = row.get("title_en", "")
        row["title_ru"] = translator.translate(original_title)
        row["focus_ru"] = translator.translate(row.get("focus", ""))
        row["equipment_ru"] = translator.translate(row.get("equipment", ""))
        row["description_ru"] = translator.translate(row.get("description", ""))
        requirements = (row.get("requirements", "") or "").replace(r"\n", "\n")
        equipment = row.get("equipment", "")
        row["requirements_ru"] = requirements.replace(
            equipment,
            row["equipment_ru"],
        )
        row["steps_ru"] = translator.translate(row.get("steps", ""))
        row["warnings_ru"] = row.get("warnings", "")
        row["history_ru"] = translator.translate(row.get("history", ""))
        if index % 100 == 0:
            print(f"workouts: {index}/{len(rows)}", flush=True)
    save_rows(path, fields, rows)


def localize_foods(
    root: Path,
    translator: CatalogTranslator,
    all_details: bool,
) -> None:
    path = root / "assets" / "catalog" / "food_catalog.csv"
    fields, rows = load_rows(path)
    new_fields = [
        "category_ru",
        "kind_ru",
        "composition_ru",
        "ingredients_ru",
        "preparation_ru",
        "history_ru",
    ]
    for field in new_fields:
        if field not in fields:
            fields.append(field)
    values: list[str] = []
    for row in rows:
        values.extend([row.get("title_en", ""), row.get("category", "")])
        if all_details or row.get("kind") == "meal":
            values.extend(
                [
                    row.get("composition", ""),
                    row.get("ingredients", ""),
                    row.get("preparation", ""),
                    row.get("history", ""),
                ]
            )
    translator.translate_values(values)
    used_titles: set[str] = set()
    for index, row in enumerate(rows, 1):
        title = translator.translate(row.get("title_en", ""))
        if title in used_titles:
            title = f"{title} [{row.get('id', index)}]"
        used_titles.add(title)
        row["title_ru"] = title
        row["category_ru"] = translator.translate(row.get("category", ""))
        row["kind_ru"] = KIND_RU.get(row.get("kind", ""), row.get("kind", ""))
        if all_details or row.get("kind") == "meal":
            row["composition_ru"] = translator.translate(
                row.get("composition", "")
            )
            row["ingredients_ru"] = translator.translate(
                row.get("ingredients", "")
            )
            row["preparation_ru"] = translator.translate(
                row.get("preparation", "")
            )
            row["history_ru"] = translator.translate(row.get("history", ""))
        if index % 500 == 0:
            print(f"foods: {index}/{len(rows)}", flush=True)
    save_rows(path, fields, rows)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--all-food-details", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    model_dir = root / "tooling" / "nllb_ct2_int8"
    if not (model_dir / "model.bin").exists():
        raise SystemExit("NLLB model is missing; run generate_nllb_translations.py first")
    translator = CatalogTranslator(
        model_dir,
        root / "tooling" / "catalog_ru_translation_cache.json",
    )
    localize_workouts(root, translator)
    localize_foods(root, translator, args.all_food_details)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
