"""Prepare and validate Ghmera's Google Play listing images."""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "store_assets" / "google_play"
PHONE_OUTPUT = OUTPUT / "phone"
ICON_SOURCE = ROOT / "assets" / "branding" / "ghmera_app_icon.png"


def center_crop(image: Image.Image, width: int, height: int) -> Image.Image:
    target_ratio = width / height
    source_ratio = image.width / image.height
    if source_ratio > target_ratio:
        crop_width = round(image.height * target_ratio)
        left = (image.width - crop_width) // 2
        box = (left, 0, left + crop_width, image.height)
    else:
        crop_height = round(image.width / target_ratio)
        top = (image.height - crop_height) // 2
        box = (0, top, image.width, top + crop_height)
    return image.crop(box)


def prepare(feature_source: Path) -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)

    with Image.open(ICON_SOURCE) as icon:
        icon.convert("RGBA").resize((512, 512), Image.Resampling.LANCZOS).save(
            OUTPUT / "app_icon.png",
            optimize=True,
        )

    with Image.open(feature_source) as feature:
        prepared = center_crop(feature.convert("RGB"), 1024, 500).resize(
            (1024, 500),
            Image.Resampling.LANCZOS,
        )
        prepared.save(OUTPUT / "feature_graphic.png", optimize=True)

    expected = {
        OUTPUT / "app_icon.png": (512, 512),
        OUTPUT / "feature_graphic.png": (1024, 500),
    }
    expected.update(
        {
            path: (1242, 2208)
            for path in sorted(PHONE_OUTPUT.glob("*.png"))
        }
    )

    for path, dimensions in expected.items():
        with Image.open(path) as image:
            if image.size != dimensions:
                raise ValueError(
                    f"{path.name}: expected {dimensions}, found {image.size}"
                )
        megabytes = path.stat().st_size / (1024 * 1024)
        print(f"{path.relative_to(ROOT)}: {dimensions[0]}x{dimensions[1]}, {megabytes:.2f} MB")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: prepare_google_play_assets.py FEATURE_GRAPHIC_SOURCE")
    prepare(Path(sys.argv[1]).resolve())
