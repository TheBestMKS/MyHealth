"""Download and export the bundled Food-101 classifier to ONNX.

The source checkpoint is Lumia101/Food101-EfficientNet-B0 (MIT), trained on
the Food-101 dataset. The script is intentionally kept outside the runtime so
the app ships only the inference graph and labels, not PyTorch.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import onnx
import torch
from huggingface_hub import hf_hub_download
from safetensors.torch import load_file
from torch import nn
from torchvision import models


REPOSITORY = "Lumia101/Food101-EfficientNet-B0"
REVISION = "main"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("assets/models"),
    )
    args = parser.parse_args()
    output_dir: Path = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    config_path = Path(
        hf_hub_download(
            repo_id=REPOSITORY,
            filename="config.json",
            revision=REVISION,
        )
    )
    weights_path = Path(
        hf_hub_download(
            repo_id=REPOSITORY,
            filename="model.safetensors",
            revision=REVISION,
        )
    )

    config = json.loads(config_path.read_text(encoding="utf-8"))
    labels = [config["id2label"][str(index)] for index in range(101)]

    model = models.efficientnet_b0(weights=None)
    model.classifier = nn.Sequential(
        nn.Dropout(p=0.2, inplace=True),
        nn.Linear(1280, 512),
        nn.SiLU(),
        nn.Dropout(0.2),
        nn.Linear(512, 101),
    )
    model.load_state_dict(load_file(weights_path))
    model.eval()

    model_path = output_dir / "food101_efficientnet_b0.onnx"
    example = torch.zeros((1, 3, 128, 128), dtype=torch.float32)
    torch.onnx.export(
        model,
        example,
        model_path,
        export_params=True,
        opset_version=17,
        do_constant_folding=True,
        input_names=["image"],
        output_names=["logits"],
        dynamic_axes={"image": {0: "batch"}, "logits": {0: "batch"}},
        dynamo=False,
    )
    onnx_model = onnx.load(model_path)
    onnx.checker.check_model(onnx_model)

    labels_path = output_dir / "food101_labels.json"
    labels_path.write_text(
        json.dumps(labels, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    metadata = {
        "model": "EfficientNet-B0 Food-101",
        "source": f"https://huggingface.co/{REPOSITORY}",
        "license": "MIT",
        "reportedTop1Accuracy": 0.7957,
        "inputShape": [1, 3, 128, 128],
        "resizeShortSide": 160,
        "cropSize": 128,
        "channelOrder": "RGB/NCHW",
        "mean": [0.485, 0.456, 0.406],
        "standardDeviation": [0.229, 0.224, 0.225],
        "classCount": len(labels),
        "sha256": sha256(model_path),
    }
    (output_dir / "food101_model_info.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(f"Exported {model_path} ({model_path.stat().st_size} bytes)")
    print(f"SHA256 {metadata['sha256']}")


if __name__ == "__main__":
    main()
