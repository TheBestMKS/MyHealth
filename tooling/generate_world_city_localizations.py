"""Build the compact runtime city table and CLDR country translations."""

from __future__ import annotations

import csv
import json
import re
from pathlib import Path

from babel import Locale


ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / "tooling" / "geonames_cache"
CITY_SOURCE = CACHE / "cities500.txt"
COUNTRY_SOURCE = CACHE / "countryInfo.txt"
CITY_TARGET = ROOT / "assets" / "world_cities.tsv"
COUNTRY_TARGET = ROOT / "assets" / "country_names.json"
LOCALES = (
    "en",
    "ru",
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
SCRIPT_PATTERNS = {
    "ru": re.compile(r"[А-Яа-яЁё]"),
    "zh": re.compile(r"[㐀-䶿一-鿿]"),
    "ja": re.compile(r"[ぁ-ゟ゠-ヿ]"),
    "ko": re.compile(r"[가-힯]"),
    "ar": re.compile(r"[؀-ۿ]"),
    "hi": re.compile(r"[ऀ-ॿ]"),
}
RUSSIAN_LETTERS = set("АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ")
PACKED_LOCALES = tuple(SCRIPT_PATTERNS)
SEPARATOR = "\x1f"


def country_info() -> tuple[dict[str, str], dict[str, str]]:
    names: dict[str, str] = {}
    codes: dict[str, str] = {}
    for line in COUNTRY_SOURCE.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) < 5:
            continue
        code, name = fields[0], fields[4]
        names[code] = name
        codes[name] = code
    return names, codes


def localized_name(alternates: str, locale: str) -> str:
    pattern = SCRIPT_PATTERNS[locale]
    matches: list[str] = []
    for candidate in alternates.split(","):
        candidate = candidate.strip()
        if (
            1 < len(candidate) <= 80
            and pattern.search(candidate)
            and "http" not in candidate.lower()
            and SEPARATOR not in candidate
        ):
            matches.append(candidate)
    if locale == "ru":
        russian = [
            candidate
            for candidate in matches
            if all(
                not character.isalpha()
                or character.upper() in RUSSIAN_LETTERS
                for character in candidate
            )
        ]
        return russian[0] if russian else ""
    if locale == "ja" and not matches:
        cjk = [
            candidate.strip()
            for candidate in alternates.split(",")
            if SCRIPT_PATTERNS["zh"].search(candidate)
        ]
        candidates = cjk[1:] or cjk
        return min(candidates, key=len, default="")
    if matches:
        return matches[0]
    return ""


def build_cities(country_names: dict[str, str]) -> set[str]:
    used_countries: set[str] = set()
    temporary = CITY_TARGET.with_suffix(".tsv.part")
    with CITY_SOURCE.open("r", encoding="utf-8") as source, temporary.open(
        "w", encoding="utf-8", newline=""
    ) as target:
        writer = csv.writer(target, delimiter="\t", lineterminator="\n")
        writer.writerow(
            (
                "country",
                "city",
                "ascii",
                "latitude",
                "longitude",
                "population",
                "timezone",
                "localized_names",
            )
        )
        for line in source:
            fields = line.rstrip("\n").split("\t")
            if len(fields) < 18:
                continue
            name = fields[1].replace("\t", " ")
            ascii_name = fields[2].replace("\t", " ")
            alternates = fields[3]
            country = country_names.get(fields[8], fields[8])
            used_countries.add(country)
            localized = SEPARATOR.join(
                localized_name(alternates, locale) for locale in PACKED_LOCALES
            )
            writer.writerow(
                (
                    country,
                    name,
                    ascii_name,
                    fields[4],
                    fields[5],
                    fields[14] or "0",
                    fields[17],
                    localized,
                )
            )
    temporary.replace(CITY_TARGET)
    return used_countries


def build_countries(used: set[str], country_codes: dict[str, str]) -> None:
    translations: dict[str, dict[str, str]] = {}
    babel_locales = {locale: Locale.parse(locale) for locale in LOCALES}
    for country in sorted(used):
        code = country_codes.get(country)
        translations[country] = {
            locale: str(babel_locale.territories.get(code, country))
            for locale, babel_locale in babel_locales.items()
        }
    COUNTRY_TARGET.write_text(
        json.dumps(translations, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )


def main() -> int:
    if not CITY_SOURCE.is_file() or not COUNTRY_SOURCE.is_file():
        raise SystemExit("GeoNames cache is missing")
    country_names, country_codes = country_info()
    used = build_cities(country_names)
    build_countries(used, country_codes)
    print(
        f"Generated {CITY_TARGET.stat().st_size:,} bytes of cities and "
        f"{len(used)} localized countries."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
