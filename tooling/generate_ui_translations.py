"""Generate offline UI translations for static Russian Dart strings.

The script uses Argos Translate models and persists every translated phrase in a
JSON cache. It is safe to interrupt and resume. Belarusian and Kazakh can be
filled by the companion PowerShell network fallback when no Argos model exists.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.request
from pathlib import Path

try:
    from argostranslate import package, translate
except ImportError:  # Extraction and NLLB generation do not require Argos.
    package = None
    translate = None


TARGETS = ("en", "zh", "ja", "de", "fr", "es", "it", "pt", "tr", "ko", "ar", "hi")
TRANSLATION_OVERRIDES = {
    "en": {
        "Факты из приложения:": "Facts from the app:",
        "Не удалось защитить исходный анализ:": "Could not secure the source lab report:",
        "Диагностика": "Diagnostics",
        "Журнал ошибок": "Error log",
        "Журнал ошибок пуст.": "The error log is empty.",
        "Журнал ошибок скопирован.": "Error log copied.",
        "Копировать журнал": "Copy log",
        "Очистить журнал": "Clear log",
        "Очистить журнал ошибок?": "Clear error log?",
        "Обновить журнал": "Refresh log",
    },
    "zh": {
        "Факты из приложения:": "应用中的事实：",
        "Не удалось защитить исходный анализ:": "无法保护原始化验报告：",
        "Диагностика": "诊断",
        "Журнал ошибок": "错误日志",
        "Журнал ошибок пуст.": "错误日志为空。",
        "Журнал ошибок скопирован.": "错误日志已复制。",
        "Копировать журнал": "复制日志",
        "Очистить журнал": "清空日志",
        "Очистить журнал ошибок?": "清空错误日志？",
        "Обновить журнал": "刷新日志",
    },
    "ja": {
        "Факты из приложения:": "アプリ内の事実：",
        "Не удалось защитить исходный анализ:": "元の検査報告を保護できませんでした：",
        "Диагностика": "診断",
        "Журнал ошибок": "エラーログ",
        "Журнал ошибок пуст.": "エラーログは空です。",
        "Журнал ошибок скопирован.": "エラーログをコピーしました。",
        "Копировать журнал": "ログをコピー",
        "Очистить журнал": "ログを消去",
        "Очистить журнал ошибок?": "エラーログを消去しますか？",
        "Обновить журнал": "ログを更新",
    },
    "be": {
        "Факты из приложения:": "Факты з праграмы:",
        "Не удалось защитить исходный анализ:": "Не ўдалося абараніць зыходны аналіз:",
        "Диагностика": "Дыягностыка",
        "Журнал ошибок": "Журнал памылак",
        "Журнал ошибок пуст.": "Журнал памылак пусты.",
        "Журнал ошибок скопирован.": "Журнал памылак скапіяваны.",
        "Копировать журнал": "Капіраваць журнал",
        "Очистить журнал": "Ачысціць журнал",
        "Очистить журнал ошибок?": "Ачысціць журнал памылак?",
        "Обновить журнал": "Абнавіць журнал",
    },
    "kk": {
        "Факты из приложения:": "Қолданбадағы фактілер:",
        "Не удалось защитить исходный анализ:": "Бастапқы талдауды қорғау мүмкін болмады:",
        "Версия: 1.8.2+11": "Нұсқа: 1.8.2+11",
        "Диагностика": "Диагностика",
        "Журнал ошибок": "Қателер журналы",
        "Журнал ошибок пуст.": "Қателер журналы бос.",
        "Журнал ошибок скопирован.": "Қателер журналы көшірілді.",
        "Копировать журнал": "Журналды көшіру",
        "Очистить журнал": "Журналды тазалау",
        "Очистить журнал ошибок?": "Қателер журналын тазалау керек пе?",
        "Обновить журнал": "Журналды жаңарту",
    },
    "de": {
        "Факты из приложения:": "Fakten aus der App:",
        "Не удалось защитить исходный анализ:": "Der ursprüngliche Laborbericht konnte nicht geschützt werden:",
        "Диагностика": "Diagnose",
        "Журнал ошибок": "Fehlerprotokoll",
        "Журнал ошибок пуст.": "Das Fehlerprotokoll ist leer.",
        "Журнал ошибок скопирован.": "Fehlerprotokoll kopiert.",
        "Копировать журнал": "Protokoll kopieren",
        "Очистить журнал": "Protokoll leeren",
        "Очистить журнал ошибок?": "Fehlerprotokoll leeren?",
        "Обновить журнал": "Protokoll aktualisieren",
    },
    "fr": {
        "Факты из приложения:": "Données de l’application :",
        "Не удалось защитить исходный анализ:": "Impossible de sécuriser le compte rendu d’analyse source :",
        "Диагностика": "Diagnostic",
        "Журнал ошибок": "Journal des erreurs",
        "Журнал ошибок пуст.": "Le journal des erreurs est vide.",
        "Журнал ошибок скопирован.": "Journal des erreurs copié.",
        "Копировать журнал": "Copier le journal",
        "Очистить журнал": "Effacer le journal",
        "Очистить журнал ошибок?": "Effacer le journal des erreurs ?",
        "Обновить журнал": "Actualiser le journal",
    },
    "es": {
        "Факты из приложения:": "Datos de la aplicación:",
        "Не удалось защитить исходный анализ:": "No se pudo proteger el informe de laboratorio original:",
        "Диагностика": "Diagnóstico",
        "Журнал ошибок": "Registro de errores",
        "Журнал ошибок пуст.": "El registro de errores está vacío.",
        "Журнал ошибок скопирован.": "Registro de errores copiado.",
        "Копировать журнал": "Copiar registro",
        "Очистить журнал": "Borrar registro",
        "Очистить журнал ошибок?": "¿Borrar el registro de errores?",
        "Обновить журнал": "Actualizar registro",
    },
    "it": {
        "Факты из приложения:": "Dati dell'app:",
        "Не удалось защитить исходный анализ:": "Impossibile proteggere il referto di laboratorio originale:",
        "Диагностика": "Diagnostica",
        "Журнал ошибок": "Registro degli errori",
        "Журнал ошибок пуст.": "Il registro degli errori è vuoto.",
        "Журнал ошибок скопирован.": "Registro degli errori copiato.",
        "Копировать журнал": "Copia registro",
        "Очистить журнал": "Cancella registro",
        "Очистить журнал ошибок?": "Cancellare il registro degli errori?",
        "Обновить журнал": "Aggiorna registro",
    },
    "pt": {
        "Факты из приложения:": "Dados do aplicativo:",
        "Не удалось защитить исходный анализ:": "Não foi possível proteger o relatório laboratorial original:",
        "Диагностика": "Diagnóstico",
        "Журнал ошибок": "Registo de erros",
        "Журнал ошибок пуст.": "O registo de erros está vazio.",
        "Журнал ошибок скопирован.": "Registo de erros copiado.",
        "Копировать журнал": "Copiar registo",
        "Очистить журнал": "Limpar registo",
        "Очистить журнал ошибок?": "Limpar o registo de erros?",
        "Обновить журнал": "Atualizar registo",
    },
    "tr": {
        "Факты из приложения:": "Uygulamadaki gerçekler:",
        "Не удалось защитить исходный анализ:": "Kaynak laboratuvar raporu korunamadı:",
        "Диагностика": "Tanılama",
        "Журнал ошибок": "Hata günlüğü",
        "Журнал ошибок пуст.": "Hata günlüğü boş.",
        "Журнал ошибок скопирован.": "Hata günlüğü kopyalandı.",
        "Копировать журнал": "Günlüğü kopyala",
        "Очистить журнал": "Günlüğü temizle",
        "Очистить журнал ошибок?": "Hata günlüğü temizlensin mi?",
        "Обновить журнал": "Günlüğü yenile",
    },
    "ko": {
        "Факты из приложения:": "앱의 사실:",
        "Не удалось защитить исходный анализ:": "원본 검사 보고서를 보호할 수 없습니다:",
        "Диагностика": "진단",
        "Журнал ошибок": "오류 로그",
        "Журнал ошибок пуст.": "오류 로그가 비어 있습니다.",
        "Журнал ошибок скопирован.": "오류 로그를 복사했습니다.",
        "Копировать журнал": "로그 복사",
        "Очистить журнал": "로그 지우기",
        "Очистить журнал ошибок?": "오류 로그를 지우시겠습니까?",
        "Обновить журнал": "로그 새로 고침",
    },
    "ar": {
        "Факты из приложения:": "حقائق من التطبيق:",
        "Не удалось защитить исходный анализ:": "تعذّر تأمين تقرير التحليل الأصلي:",
        "Диагностика": "التشخيص",
        "Журнал ошибок": "سجل الأخطاء",
        "Журнал ошибок пуст.": "سجل الأخطاء فارغ.",
        "Журнал ошибок скопирован.": "تم نسخ سجل الأخطاء.",
        "Копировать журнал": "نسخ السجل",
        "Очистить журнал": "مسح السجل",
        "Очистить журнал ошибок?": "هل تريد مسح سجل الأخطاء؟",
        "Обновить журнал": "تحديث السجل",
    },
    "hi": {
        "Факты из приложения:": "ऐप से तथ्य:",
        "Не удалось защитить исходный анализ:": "मूल लैब रिपोर्ट सुरक्षित नहीं की जा सकी:",
        "Диагностика": "निदान",
        "Журнал ошибок": "त्रुटि लॉग",
        "Журнал ошибок пуст.": "त्रुटि लॉग खाली है।",
        "Журнал ошибок скопирован.": "त्रुटि लॉग कॉपी किया गया।",
        "Копировать журнал": "लॉग कॉपी करें",
        "Очистить журнал": "लॉग साफ़ करें",
        "Очистить журнал ошибок?": "त्रुटि लॉग साफ़ करें?",
        "Обновить журнал": "लॉग रीफ़्रेश करें",
    },
}
CYRILLIC = re.compile(r"[\u0400-\u04ff]")
DART_LITERAL = re.compile(
    r"(?<![^\s(\[{:=>,;])(?P<prefix>r)?(?P<quote>['\"])(?P<body>(?:\\.|(?!\2).)*)(?P=quote)",
    re.DOTALL,
)


def project_sources(root: Path) -> list[Path]:
    files = sorted((root / "lib" / "src" / "screens").glob("*.dart"))
    files.extend(
        root / "lib" / "src" / name
        for name in (
            "app.dart",
            "geo_workout.dart",
            "repository.dart",
            "runtime_service.dart",
            "vault_unlock_screen.dart",
            "widgets.dart",
            "localization.dart",
            "assistant_engine.dart",
            "assistant_conversation_service.dart",
            "document_vault_service.dart",
            "food_recognition_service.dart",
            "media_import_service.dart",
            "notification_service.dart",
            "weather_service.dart",
            "health_platform_service.dart",
            "ble_service.dart",
            "offline_map_service.dart",
            "activity_context_service.dart",
            "assistant_tools.dart",
            "health_plan_engine.dart",
            "local_llm_service.dart",
            "medical_knowledge.dart",
            "model.dart",
            "prescription_parser.dart",
            "speech_input_service.dart",
        )
    )
    return files


def decode_dart_literal(body: str, raw: bool) -> str:
    if raw:
        return body
    replacements = {
        r"\n": "\n",
        r"\r": "\r",
        r"\t": "\t",
        r"\'": "'",
        r'\"': '"',
        r"\\": "\\",
    }
    return re.sub(
        r"\\[nrt'\"\\]",
        lambda match: replacements.get(match.group(0), match.group(0)),
        body,
    )


def interpolation_fragments(body: str) -> list[str]:
    fragments: list[str] = []
    start = 0
    index = 0
    while index < len(body):
        if body[index] != "$":
            index += 1
            continue
        fragments.append(body[start:index])
        if index + 1 < len(body) and body[index + 1] == "{":
            index += 2
            depth = 1
            quote: str | None = None
            escaped = False
            while index < len(body) and depth:
                char = body[index]
                if quote is not None:
                    if escaped:
                        escaped = False
                    elif char == "\\":
                        escaped = True
                    elif char == quote:
                        quote = None
                elif char in ("'", '"'):
                    quote = char
                elif char == "{":
                    depth += 1
                elif char == "}":
                    depth -= 1
                index += 1
        else:
            index += 1
            while index < len(body) and (body[index].isalnum() or body[index] == "_"):
                index += 1
        start = index
    fragments.append(body[start:])
    return fragments


def extract_phrases(root: Path) -> list[str]:
    phrases: set[str] = set()
    for path in project_sources(root):
        source = path.read_text(encoding="utf-8")
        for match in DART_LITERAL.finditer(source):
            body = match.group("body")
            candidates = interpolation_fragments(body) if "$" in body else [body]
            for candidate in candidates:
                value = decode_dart_literal(
                    candidate,
                    match.group("prefix") == "r",
                ).strip()
                if value and len(value) <= 500 and CYRILLIC.search(value):
                    phrases.add(value)
    return sorted(phrases, key=lambda value: (value.casefold(), value))


def load_cache(path: Path) -> dict[str, dict[str, str]]:
    if not path.exists():
        return {}
    raw = json.loads(path.read_text(encoding="utf-8"))
    return {
        str(locale): {str(source): str(value) for source, value in values.items()}
        for locale, values in raw.items()
    }


def save_cache(path: Path, cache: dict[str, dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(cache, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def available_packages() -> list[package.AvailablePackage]:
    if package is None:
        raise RuntimeError("Install argostranslate to translate with Argos")
    package.update_package_index()
    return package.get_available_packages()


def ensure_model(
    packages: list[package.AvailablePackage],
    source: str,
    target: str,
    downloads: Path,
) -> None:
    installed = translate.get_installed_languages()
    source_language = next((item for item in installed if item.code == source), None)
    target_language = next((item for item in installed if item.code == target), None)
    if source_language is not None and target_language is not None:
        if source_language.get_translation(target_language) is not None:
            return

    candidates = [
        item
        for item in packages
        if item.from_code == source and item.to_code == target
    ]
    if not candidates:
        raise RuntimeError(f"No Argos model for {source}->{target}")
    selected = candidates[-1]
    downloads.mkdir(parents=True, exist_ok=True)
    archive = downloads / Path(selected.links[0]).name
    if not archive.exists() or archive.stat().st_size < 1024:
        print(f"Downloading {source}->{target}: {selected.links[0]}", flush=True)
        request = urllib.request.Request(
            selected.links[0],
            headers={"User-Agent": "ArgosTranslate"},
        )
        with urllib.request.urlopen(request, timeout=180) as response:
            archive.write_bytes(response.read())
    print(f"Installing {source}->{target} from {archive.name}", flush=True)
    package.install_from_path(archive)


def translator(source: str, target: str):
    if translate is None:
        raise RuntimeError("Install argostranslate to translate with Argos")
    installed = translate.get_installed_languages()
    source_language = next(item for item in installed if item.code == source)
    target_language = next(item for item in installed if item.code == target)
    result = source_language.get_translation(target_language)
    if result is None:
        raise RuntimeError(f"Installed Argos model unavailable for {source}->{target}")
    return result


def translate_missing(
    phrases: list[str],
    targets: tuple[str, ...],
    cache: dict[str, dict[str, str]],
    cache_path: Path,
    downloads: Path,
) -> None:
    packages = available_packages()
    ensure_model(packages, "ru", "en", downloads)
    ru_en = translator("ru", "en")
    english = cache.setdefault("en", {})

    missing_english = [phrase for phrase in phrases if not english.get(phrase, "").strip()]
    for index, phrase in enumerate(missing_english, start=1):
        english[phrase] = ru_en.translate(phrase).strip() or phrase
        if index % 10 == 0 or index == len(missing_english):
            save_cache(cache_path, cache)
            print(f"en: {index}/{len(missing_english)} new phrases", flush=True)

    for target in targets:
        if target == "en":
            continue
        ensure_model(packages, "en", target, downloads)
        en_target = translator("en", target)
        locale_cache = cache.setdefault(target, {})
        missing = [phrase for phrase in phrases if not locale_cache.get(phrase, "").strip()]
        for index, phrase in enumerate(missing, start=1):
            source = english[phrase]
            locale_cache[phrase] = en_target.translate(source).strip() or source
            if index % 10 == 0 or index == len(missing):
                save_cache(cache_path, cache)
                print(f"{target}: {index}/{len(missing)} new phrases", flush=True)


def dart_string(value: str) -> str:
    # JSON strings are valid Dart strings after escaping interpolation markers.
    return json.dumps(value, ensure_ascii=False).replace("$", r"\u0024")


def write_dart(
    path: Path,
    phrases: list[str],
    cache: dict[str, dict[str, str]],
    locales: tuple[str, ...],
) -> None:
    lines = [
        "// Generated by tooling/generate_ui_translations.py.",
        "// Regenerate after changing user-facing Russian strings.",
        "const generatedUiTranslations = <String, Map<String, String>>{",
    ]
    for locale in locales:
        translations = cache.get(locale, {})
        overrides = TRANSLATION_OVERRIDES.get(locale, {})
        missing = [
            phrase
            for phrase in phrases
            if not translations.get(phrase, "").strip()
            and not overrides.get(phrase, "").strip()
        ]
        if missing:
            print(f"Skipping incomplete locale {locale}: {len(missing)} missing", flush=True)
            continue
        lines.append(f"  {dart_string(locale)}: {{")
        for phrase in phrases:
            value = overrides.get(phrase) or translations[phrase]
            lines.append(
                f"    {dart_string(phrase)}: {dart_string(value)},"
            )
        lines.append("  },")
    lines.append("};")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {path} ({len(phrases)} source phrases)", flush=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--locales", nargs="*", choices=TARGETS, default=list(TARGETS))
    parser.add_argument("--extract-only", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = args.root.resolve()
    phrases = extract_phrases(root)
    cache_path = root / "tooling" / "ui_translation_cache.json"
    output_path = root / "lib" / "src" / "generated_ui_translations.dart"
    downloads = root / "tooling" / "translation_models"
    cache = load_cache(cache_path)
    locales = tuple(args.locales)
    print(f"Found {len(phrases)} static Russian UI phrases", flush=True)
    if not args.extract_only:
        translate_missing(phrases, locales, cache, cache_path, downloads)
    write_dart(output_path, phrases, cache, locales)
    return 0


if __name__ == "__main__":
    sys.exit(main())
