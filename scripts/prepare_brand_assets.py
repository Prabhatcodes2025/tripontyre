from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / "public"


def remove_canvas(source: str, target: str) -> None:
    image = Image.open(PUBLIC / source).convert("RGBA")
    background = Image.new("RGBA", image.size, image.getpixel((0, 0)))
    difference = ImageChops.difference(image, background).convert("L")
    alpha = difference.point(lambda value: 0 if value < 4 else min(255, value * 10))
    image.putalpha(alpha)
    bounds = alpha.getbbox()
    if bounds:
        image = image.crop(bounds)
    image.save(PUBLIC / target, optimize=True)


remove_canvas("tripon-mark.png", "tripon-mark-transparent.png")
remove_canvas("my-tripon-wordmark.png", "my-tripon-wordmark-transparent.png")
