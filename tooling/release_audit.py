#!/usr/bin/env python3
"""Verify release-critical assets, catalogs, localization, and UTF-8 text."""

from __future__ import annotations

import csv
import hashlib
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


def has_cyrillic(value: str) -> bool:
    return any("\u0400" <= character <= "\u04ff" for character in value)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


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
    main_entry = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
    error_log = (ROOT / "lib/src/error_log_service.dart").read_text(
        encoding="utf-8"
    )
    error_log_dialog = (ROOT / "lib/src/screens/error_log_dialog.dart").read_text(
        encoding="utf-8"
    )
    offline_maps = (ROOT / "lib/src/offline_map_service.dart").read_text(
        encoding="utf-8"
    )
    notification_keep = (
        ROOT / "android/app/src/main/res/raw/keep.xml"
    ).read_text(encoding="utf-8")
    check("version: 1.8.2+11" in pubspec, "pubspec version is not 1.8.2+11", errors)
    check("1.8.2+11" in readme, "README release version is missing", errors)
    check("1.8.2+11" in settings, "Settings about version is stale", errors)
    check("1.8.2+11" in profile, "Profile about version is stale", errors)
    check(
        "FlutterError.onError" in main_entry
        and "PlatformDispatcher.instance.onError" in main_entry
        and "runZonedGuarded" in main_entry,
        "global Flutter/Dart error capture is incomplete",
        errors,
    )
    check(
        "@drawable/ic_notification" in notification_keep,
        "Android notification icon is not protected from resource shrinking",
        errors,
    )
    check(
        "myhealth-errors.log" in error_log
        and "myhealth-errors.previous.log" in error_log
        and "maxFileBytes" in error_log,
        "rotating local error log is incomplete",
        errors,
    )
    check(
        "showErrorLogDialog" in settings
        and "Clipboard.setData" in error_log_dialog
        and "error_log_copy_button" in error_log_dialog,
        "in-app error log viewer or copy action is missing",
        errors,
    )
    check(
        "tile.openstreetmap.org" not in offline_maps,
        "offline map downloader still bulk-downloads standard OSM tiles",
        errors,
    )
    check(
        "PmTilesArchive" in offline_maps and "source.coop" in offline_maps,
        "offline PMTiles vector downloader is missing",
        errors,
    )
    check(
        (ROOT / "assets/maps/myhealth_offline_style.json").is_file(),
        "offline vector map style is missing",
        errors,
    )
    check(
        (ROOT / "assets/country_names.json").stat().st_size > 10000,
        "localized country database is missing",
        errors,
    )
    check(
        "localized_names" in (ROOT / "assets/world_cities.tsv").open(
            encoding="utf-8"
        ).readline(),
        "localized city name column is missing",
        errors,
    )

    model_manifest = json.loads(
        (ROOT / "assets/models/bundled_model_manifest.json").read_text(
            encoding="utf-8"
        )
    )
    expected_models = {
        item["name"]: (int(item["size"]), item["sha256"].lower())
        for item in model_manifest.get("files", [])
    }
    check(len(expected_models) == 2, "bundled model manifest is incomplete", errors)
    for name, (expected_size, expected_sha256) in expected_models.items():
        model_path = ROOT / "assets/models" / name
        check(model_path.is_file(), f"missing bundled model: {name}", errors)
        if model_path.is_file():
            check(
                model_path.stat().st_size == expected_size,
                f"bundled model size mismatch: {name}",
                errors,
            )
            check(
                sha256_file(model_path) == expected_sha256,
                f"bundled model checksum mismatch: {name}",
                errors,
            )
        check(len(expected_sha256) == 64, f"invalid model checksum: {name}", errors)

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
        sum(has_cyrillic(row.get("title_ru", "")) for row in foods) >= 8000,
        "Russian food title coverage is below 80%",
        errors,
    )
    check(
        all(
            not row.get(source_field, "").strip()
            or row.get(target_field, "").strip()
            for row in foods
            for source_field, target_field in (
                ("composition", "composition_ru"),
                ("ingredients", "ingredients_ru"),
                ("preparation", "preparation_ru"),
                ("history", "history_ru"),
            )
        ),
        "some food details have no Russian counterpart",
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
    check(
        len({row.get("title_ru", "") for row in workouts}) == len(workouts),
        "workout names are not unique",
        errors,
    )
    check(
        sum(has_cyrillic(row.get("title_ru", "")) for row in workouts) >= 900,
        "Russian workout title coverage is below 90%",
        errors,
    )
    check(
        all(
            row.get(field, "").strip()
            for row in workouts
            for field in (
                "focus_ru",
                "equipment_ru",
                "description_ru",
                "requirements_ru",
                "steps_ru",
                "warnings_ru",
            )
        ),
        "some workouts have incomplete Russian instructions",
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
