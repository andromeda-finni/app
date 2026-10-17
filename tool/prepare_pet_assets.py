from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


FUR_FOLDERS = {
    "серый": "striped",
    "рыжий": "red",
    "белый": "white",
}

COLLAR_FOLDERS = {
    "красный": "red",
    "зеленый": "green",
    "синий": "blue",
}

STAGE_FOLDERS = {
    "котенок": "kitten",
    "средний": "middle",
    "взрослый": "adult",
}

MOOD_FILES = {
    "базовый.png": "base",
    "радость.png": "happy",
    "грусть.png": "sad",
    "спит.png": "sleep",
    "обжорство.png": "fully",
}

TARGET_SIZE = (768, 1152)


def convert_assets(source_root: Path, output_root: Path, quality: int) -> None:
    expected = len(FUR_FOLDERS) * len(COLLAR_FOLDERS) * len(STAGE_FOLDERS) * len(MOOD_FILES)
    converted = 0

    for fur_source, fur_target in FUR_FOLDERS.items():
        for collar_source, collar_target in COLLAR_FOLDERS.items():
            for stage_source, stage_target in STAGE_FOLDERS.items():
                source_dir = source_root / fur_source / collar_source / stage_source
                if not source_dir.is_dir():
                    raise FileNotFoundError(source_dir)

                target_dir = output_root / stage_target / collar_target
                target_dir.mkdir(parents=True, exist_ok=True)

                for mood_source, mood_target in MOOD_FILES.items():
                    source_path = source_dir / mood_source
                    if not source_path.is_file():
                        raise FileNotFoundError(source_path)

                    target_path = target_dir / f"{mood_target}_{fur_target}.webp"
                    with Image.open(source_path) as image:
                        image = image.convert("RGBA")
                        # Source canvases have different invisible margins.
                        # Trim only transparent pixels so feet share a baseline.
                        bounds = image.getchannel("A").point(lambda value: 255 if value > 8 else 0).getbbox()
                        if bounds is None:
                            raise ValueError(f"Empty artwork: {source_path}")
                        image = image.crop(bounds)
                        image.thumbnail(TARGET_SIZE, Image.Resampling.LANCZOS)
                        image.save(
                            target_path,
                            format="WEBP",
                            quality=quality,
                            method=4,
                            exact=True,
                        )
                    converted += 1

    if converted != expected:
        raise RuntimeError(f"Converted {converted} files, expected {expected}")

    total_bytes = sum(path.stat().st_size for path in output_root.rglob("*.webp"))
    print(f"Converted {converted} files ({total_bytes / 1024 / 1024:.2f} MiB)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    parser.add_argument("output_root", type=Path)
    parser.add_argument("--quality", type=int, default=84)
    args = parser.parse_args()
    convert_assets(args.source_root, args.output_root, args.quality)


if __name__ == "__main__":
    main()
