"""Build 1,000 media-backed workout cards from the public wger API."""

from __future__ import annotations

import argparse
import csv
import html
import re
from pathlib import Path

import requests


API_URL = "https://wger.de/api/v2/exerciseinfo/?limit=1000&language=2"
FIELDNAMES = (
    "id",
    "title_ru",
    "title_en",
    "focus",
    "equipment",
    "level",
    "minutes",
    "calories",
    "sets",
    "description",
    "requirements",
    "steps",
    "warnings",
    "image",
    "video",
    "history",
    "doctor_review",
    "source_url",
    "data_license",
)


def plain_text(value: object) -> str:
    text = html.unescape(str(value or ""))
    text = re.sub(r"<li[^>]*>", "\n", text, flags=re.IGNORECASE)
    text = re.sub(r"</?(?:p|ol|ul|br)[^>]*>", "\n", text, flags=re.IGNORECASE)
    text = re.sub(r"<[^>]+>", "", text)
    text = text.replace("\u200b", "").replace("\ufeff", "")
    lines = [re.sub(r"\s+", " ", line).strip() for line in text.splitlines()]
    return "\n".join(line for line in lines if line).strip()


def translation(item: dict[str, object], language: int) -> dict[str, object] | None:
    return next(
        (
            value
            for value in item.get("translations", [])
            if value.get("language") == language and value.get("name")
        ),
        None,
    )


def image_url(item: dict[str, object]) -> str:
    images = item.get("images", [])
    if images:
        selected = next((value for value in images if value.get("is_main")), images[0])
        thumbnails = selected.get("thumbnails") or {}
        return thumbnails.get("medium") or selected.get("image") or ""
    muscles = [*item.get("muscles", []), *item.get("muscles_secondary", [])]
    if muscles:
        return muscles[0].get("image_url_main") or ""
    return ""


def video_url(item: dict[str, object]) -> str:
    videos = item.get("videos", [])
    if not videos:
        return ""
    video = videos[0]
    return video.get("video") or video.get("url") or ""


def muscle_names(item: dict[str, object]) -> str:
    values = [*item.get("muscles", []), *item.get("muscles_secondary", [])]
    names: list[str] = []
    for value in values:
        name = value.get("name_en") or value.get("name") or ""
        if name and name not in names:
            names.append(name)
    return ", ".join(names)


def equipment_names(item: dict[str, object]) -> str:
    names = [value.get("name", "") for value in item.get("equipment", [])]
    return ", ".join(value for value in names if value) or "bodyweight"


def estimate_calories(category: str, minutes: int) -> int:
    met = {
        "Cardio": 7.0,
        "Legs": 5.5,
        "Back": 5.0,
        "Chest": 5.0,
        "Arms": 4.5,
        "Shoulders": 4.5,
        "Abs": 4.0,
        "Calves": 4.5,
    }.get(category, 4.5)
    return round(met * 70 * minutes / 60)


def workout_review(level: str, equipment: str, calories: int, minutes: int) -> str:
    load = (
        "начните с облегчённой техники и оставляйте запас повторов"
        if level == "начальный"
        else "повышайте объём постепенно и прекращайте подход при потере техники"
    )
    return (
        f"Справочная проверка безопасности: {load}. Инвентарь: {equipment}. "
        f"Расход {calories} ккал за {minutes} мин рассчитан ориентировочно для массы 70 кг и меняется "
        "с интенсивностью и индивидуальными особенностями. При травмах, боли, беременности, "
        "сердечно-сосудистых или иных ограничениях согласуйте нагрузку со специалистом. "
        "Это автоматическая справка, не персональное заключение врача."
    )


def base_row(item: dict[str, object], variant: bool) -> dict[str, object]:
    english = translation(item, 2)
    russian = translation(item, 5)
    if english is None:
        raise ValueError(f"Exercise {item.get('id')} has no English translation")
    exercise_id = str(item.get("id", ""))
    name_en = plain_text(english.get("name"))
    name_ru = plain_text((russian or {}).get("name")) or name_en
    description_en = plain_text(
        english.get("description_source") or english.get("description")
    )
    description_ru = plain_text(
        (russian or {}).get("description_source")
        or (russian or {}).get("description")
    )
    description = description_ru or description_en
    category = str((item.get("category") or {}).get("name") or "Full body")
    muscles = muscle_names(item)
    equipment = equipment_names(item)
    suffix_ru = " — облегчённый вариант" if variant else ""
    suffix_en = " — beginner variation" if variant else ""
    minutes = (10 + int(exercise_id or 0) % 26) if not variant else 8 + int(exercise_id or 0) % 12
    sets = (3 + int(exercise_id or 0) % 3) if not variant else 2
    level = "начальный" if variant else ("средний" if sets <= 4 else "продвинутый")
    variant_note = (
        "\nОблегчённый вариант: уменьшите амплитуду и сопротивление, "
        "выполняйте движение медленно, оставляя 3-4 повтора в запасе."
        if variant
        else ""
    )
    license_data = item.get("license") or {}
    license_name = license_data.get("short_name") or license_data.get("full_name") or ""
    author = item.get("license_author") or "wger community"
    calories = estimate_calories(category, minutes)
    return {
        "id": f"wger-{exercise_id}{'-easy' if variant else ''}",
        "title_ru": f"{name_ru}{suffix_ru} [wger-{exercise_id}]",
        "title_en": f"{name_en}{suffix_en} [wger-{exercise_id}]",
        "focus": f"{category}{f': {muscles}' if muscles else ''}",
        "equipment": equipment,
        "level": level,
        "minutes": minutes,
        "calories": calories,
        "sets": sets,
        "description": description or f"Техника упражнения {name_ru}.",
        "requirements": f"Инвентарь: {equipment}. Освободите безопасное место и подготовьте воду.",
        "steps": f"{description or name_ru}{variant_note}",
        "warnings": (
            "Прекратите упражнение при острой боли, головокружении, необычной "
            "одышке или сердцебиении. При ограничениях согласуйте нагрузку со специалистом."
        ),
        "image": image_url(item),
        "video": video_url(item),
        "history": "",
        "doctor_review": workout_review(level, equipment, calories, minutes),
        "source_url": f"https://wger.de/en/exercise/{exercise_id}/view",
        "data_license": f"wger · {license_name} · {author}".strip(" ·"),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parents[1]
        / "tooling"
        / "workout_catalog_real.csv",
    )
    args = parser.parse_args()
    response = requests.get(
        API_URL,
        headers={"User-Agent": "MyHealth/1.8.1", "Accept": "application/json"},
        timeout=120,
    )
    response.raise_for_status()
    media_backed = [
        item
        for item in response.json().get("results", [])
        if translation(item, 2) is not None and image_url(item)
    ]
    if len(media_backed) < 500:
        raise RuntimeError(f"Only {len(media_backed)} media-backed exercises received")
    selected = media_backed[:686]
    rows = [base_row(item, False) for item in selected]
    rows.extend(base_row(item, True) for item in selected[: 1000 - len(rows)])
    if len(rows) != 1000 or len({row["title_ru"] for row in rows}) != 1000:
        raise RuntimeError("Workout catalog must contain 1,000 unique titles")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=FIELDNAMES, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {len(rows)} wger workout cards to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
