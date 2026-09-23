#!/usr/bin/env python3
"""Verify release-critical assets, catalogs, localization, and UTF-8 text."""

from __future__ import annotations

import csv
import json
import os
import sys
from pathlib import Path

from generate_ui_translations import (
    TRANSLATION_OVERRIDES,
    extract_phrases,
    load_cache,
)


ROOT = Path(__file__).resolve().parents[1]
TEXT_SUFFIXES = {
    ".bat",
    ".cc",
    ".cmake",
    ".cpp",
    ".csv",
    ".dart",
    ".gradle",
    ".h",
    ".hpp",
    ".json",
    ".kt",
    ".kts",
    ".md",
    ".plist",
    ".properties",
    ".ps1",
    ".py",
    ".swift",
    ".tsv",
    ".txt",
    ".xml",
    ".yaml",
    ".yml",
}
IGNORED_PARTS = {
    ".dart_tool",
    ".git",
    ".idea",
    "build",
    "dist",
    "flutter",
    "flutter_clean",
    "geonames_cache",
    "nllb_ct2_int8",
    "translation_models",
}
LOCALES = (
    "en",
    "zh",
    "ja",
    "be",
    "kk",
    "de",
    "fr",
    "es",
    "it",
    "pt",
    "tr",
    "ko",
    "ar",
    "hi",
)


def check(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def audit_utf8(errors: list[str]) -> int:
    checked = 0
    for directory, names, filenames in os.walk(ROOT):
        names[:] = [name for name in names if name not in IGNORED_PARTS]
        for filename in filenames:
            path = Path(directory) / filename
            if path.suffix.lower() not in TEXT_SUFFIXES:
                continue
            try:
                text = path.read_text(encoding="utf-8", errors="strict")
            except UnicodeDecodeError as error:
                errors.append(f"not UTF-8: {path.relative_to(ROOT)} ({error})")
                continue
            checked += 1
            if "\ufffd" in text:
                errors.append(f"replacement character: {path.relative_to(ROOT)}")
    return checked


def csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as source:
        return list(csv.DictReader(source))


def main() -> int:
    errors: list[str] = []
    text_files = audit_utf8(errors)

    pubspec = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    settings = (ROOT / "lib/src/screens/settings_screen.dart").read_text(
        encoding="utf-8"
    )
    profile = (ROOT / "lib/src/screens/profile_helpers.dart").read_text(
        encoding="utf-8"
    )
    check("version: 1.7.0+8" in pubspec, "pubspec version is not 1.7.0+8", errors)
    check("1.7.0+8" in readme, "README release version is missing", errors)
    check("1.7.0+8" in settings, "Settings about version is stale", errors)
    check("1.7.0+8" in profile, "Profile about version is stale", errors)

    for relative in (
        "icon/logo.png",
        "icon/logo.ico",
        "windows/runner/resources/app_icon.ico",
        "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png",
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png",
    ):
        path = ROOT / relative
        check(path.is_file() and path.stat().st_size > 1000, f"missing icon: {relative}", errors)

    foods = csv_rows(ROOT / "assets/catalog/food_catalog.csv")
    workouts = csv_rows(ROOT / "assets/catalog/workout_catalog.csv")
    check(len(foods) == 10000, f"food rows: {len(foods)}, expected 10000", errors)
    check(len(workouts) == 1000, f"workout rows: {len(workouts)}, expected 1000", errors)
    check(
        len({row.get("title_ru", "") for row in foods}) == len(foods),
        "food names are not unique",
        errors,
    )
    check(
        all(row.get("image", "").startswith("https://") for row in foods),
        "some foods have no attributed image URL",
        errors,
    )
    check(
        all(row.get("doctor_review", "").strip() for row in foods),
        "some foods have no medical nutrition note",
        errors,
    )
    check(
        all(row.get("doctor_review", "").strip() for row in workouts),
        "some workouts have no safety note",
        errors,
    )

    medline = json.loads(
        (ROOT / "assets/catalog/medlineplus_topics.json").read_text(encoding="utf-8")
    )
    openfda = json.loads(
        (ROOT / "assets/catalog/openfda_substances.json").read_text(encoding="utf-8")
    )
    check(len(medline.get("topics", [])) >= 1000, "medical topics below 1000", errors)
    check(
        len(openfda.get("substances", [])) >= 3200,
        "FDA medicine index below 3200",
        errors,
    )

    phrases = extract_phrases(ROOT)
    cache = load_cache(ROOT / "tooling/ui_translation_cache.json")
    for locale in LOCALES:
        missing = [
            phrase
            for phrase in phrases
            if not cache.get(locale, {}).get(phrase, "").strip()
            and not TRANSLATION_OVERRIDES.get(locale, {}).get(phrase, "").strip()
        ]
        check(not missing, f"{locale}: {len(missing)} missing UI translations", errors)

    screens_lines = len(
        (ROOT / "lib/src/screens.dart").read_text(encoding="utf-8").splitlines()
    )
    check(screens_lines <= 200, f"screens.dart grew to {screens_lines} lines", errors)
    check(
        (ROOT / "build/windows/x64/runner/Release/my_health.exe").is_file(),
        "Windows release executable is missing",
        errors,
    )
    check(
        (ROOT / "build/app/outputs/flutter-apk/app-release.apk").is_file(),
        "Android release APK is missing",
        errors,
    )

    if errors:
        print("Release audit failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    print(
        "Release audit passed: "
        f"{text_files} UTF-8 files, {len(phrases)} UI phrases x {len(LOCALES)} locales, "
        f"{len(foods)} foods, {len(workouts)} workouts, "
        f"{len(medline['topics'])} medical topics, "
        f"{len(openfda['substances'])} FDA medicine records."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
