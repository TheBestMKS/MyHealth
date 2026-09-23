"""Fill Belarusian and Kazakh UI translations with an offline NLLB model."""

from __future__ import annotations

import argparse
import os
from pathlib import Path

import ctranslate2
from huggingface_hub import snapshot_download
from transformers import AutoTokenizer

from generate_ui_translations import extract_phrases, load_cache, save_cache, write_dart


MODEL_ID = "JustFrederik/nllb-200-distilled-600M-ct2-int8"
TARGETS = {
    "en": "eng_Latn",
    "zh": "zho_Hans",
    "ja": "jpn_Jpan",
    "be": "bel_Cyrl",
    "kk": "kaz_Cyrl",
    "de": "deu_Latn",
    "fr": "fra_Latn",
    "es": "spa_Latn",
    "it": "ita_Latn",
    "pt": "por_Latn",
    "tr": "tur_Latn",
    "ko": "kor_Hang",
    "ar": "arb_Arab",
    "hi": "hin_Deva",
}
MODEL_FILES = (
    "config.json",
    "model.bin",
    "sentencepiece.bpe.model",
    "shared_vocabulary.txt",
    "special_tokens_map.json",
    "tokenizer.json",
    "tokenizer_config.json",
)


def translate_locale(
    phrases: list[str],
    locale: str,
    target_code: str,
    model_dir: Path,
    cache: dict[str, dict[str, str]],
    cache_path: Path,
) -> None:
    tokenizer = AutoTokenizer.from_pretrained(
        model_dir,
        src_lang="rus_Cyrl",
        use_fast=False,
    )
    translator = ctranslate2.Translator(
        str(model_dir),
        device="cpu",
        compute_type="int8",
        inter_threads=1,
        intra_threads=max(1, (os.cpu_count() or 4) - 1),
    )
    locale_cache = cache.setdefault(locale, {})
    missing = [phrase for phrase in phrases if not locale_cache.get(phrase, "").strip()]
    batch_size = 24
    for offset in range(0, len(missing), batch_size):
        batch = missing[offset : offset + batch_size]
        sources = [
            tokenizer.convert_ids_to_tokens(tokenizer.encode(text)) for text in batch
        ]
        results = translator.translate_batch(
            sources,
            target_prefix=[[target_code] for _ in batch],
            beam_size=1,
            max_batch_size=batch_size,
        )
        for source, result in zip(batch, results):
            target_tokens = result.hypotheses[0][1:]
            translated = tokenizer.decode(
                tokenizer.convert_tokens_to_ids(target_tokens),
                skip_special_tokens=True,
            ).strip()
            locale_cache[source] = translated or source
        save_cache(cache_path, cache)
        print(
            f"{locale}: {min(offset + len(batch), len(missing))}/{len(missing)} new phrases",
            flush=True,
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--locales", nargs="*", choices=TARGETS, default=list(TARGETS))
    args = parser.parse_args()
    root = args.root.resolve()
    model_dir = root / "tooling" / "nllb_ct2_int8"
    snapshot_download(
        MODEL_ID,
        local_dir=model_dir,
        allow_patterns=list(MODEL_FILES),
    )
    phrases = extract_phrases(root)
    cache_path = root / "tooling" / "ui_translation_cache.json"
    cache = load_cache(cache_path)
    print(f"Found {len(phrases)} static and template UI phrases", flush=True)
    for locale in args.locales:
        translate_locale(
            phrases,
            locale,
            TARGETS[locale],
            model_dir,
            cache,
            cache_path,
        )
    all_locales = (
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
    write_dart(
        root / "lib" / "src" / "generated_ui_translations.dart",
        phrases,
        cache,
        all_locales,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
