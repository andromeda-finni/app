"""Export the approved source art as mobile-sized WebP assets (requires Pillow)."""
import json
from pathlib import Path

from PIL import Image


def main():
    project = Path(__file__).resolve().parents[1]
    source = project / 'art' / 'minigames' / 'catch_food'
    target = project / 'assets' / 'minigames' / 'catch_food'
    manifest = json.loads((source / 'manifest.json').read_text(encoding='utf-8'))
    target.mkdir(parents=True, exist_ok=True)
    total = 0
    for asset in manifest['assets']:
        with Image.open(source / asset['file']) as image:
            image = image.convert('RGBA' if asset['transparent'] else 'RGB')
            maximum = 768 if asset['group'] in ('cat', 'chutes') else 256
            if asset['group'] == 'scene':
                maximum = 1672 if asset['name'] == 'pantry_background' else 768
            image.thumbnail((maximum, maximum), Image.Resampling.LANCZOS)
            destination = target / (asset['name'] + '.webp')
            image.save(destination, format='WEBP', quality=90, method=6)
            total += destination.stat().st_size
    print(f"Exported {len(manifest['assets'])} assets, {total / 1024 / 1024:.2f} MiB")


if __name__ == '__main__':
    main()
