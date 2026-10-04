"""Images and feed icons for the sample library, all drawn rather than fetched."""

import colorsys
import hashlib
import io
import random
import unicodedata
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from glyphs import draw_glyph

FONTS_DIR = Path("/System/Library/Fonts")
ICON_SIZE = 512


def rng_for(name):
    return random.Random(int(hashlib.sha256(name.encode()).hexdigest()[:16], 16))


def mesh_gradient(name, width, height, hue):
    """A soft mesh of colours around `hue`, the same every time for the same name.

    Colour points are scattered over the canvas and blended by distance at a low
    resolution, then scaled up, which keeps the blends free of banding.
    """
    rng = rng_for(name)
    points = []
    for _ in range(rng.randint(5, 7)):
        shifted = (hue + rng.uniform(-50, 50) + (160 if rng.random() < 0.2 else 0)) % 360
        red, green, blue = colorsys.hsv_to_rgb(shifted / 360, rng.uniform(0.45, 0.85), rng.uniform(0.75, 1.0))
        points.append((rng.uniform(-0.1, 1.1), rng.uniform(-0.1, 1.1), (red, green, blue)))
    small_width = 96
    small_height = max(8, round(small_width * height / width))
    aspect = height / width
    spread = rng.uniform(0.05, 0.09)
    small = Image.new("RGB", (small_width, small_height))
    for y in range(small_height):
        for x in range(small_width):
            u, v = x / (small_width - 1), y / (small_height - 1)
            totals = [0.0, 0.0, 0.0]
            weight_sum = 0.0
            for point_x, point_y, colour in points:
                distance = (u - point_x) ** 2 + ((v - point_y) * aspect) ** 2
                weight = 2.718281828 ** (-distance / spread)
                weight_sum += weight
                for channel in range(3):
                    totals[channel] += colour[channel] * weight
            small.putpixel((x, y), tuple(int(255 * total / weight_sum) for total in totals))
    smooth = small.resize((width, height), Image.BICUBIC)
    return smooth.filter(ImageFilter.GaussianBlur(radius=max(width, height) / 60))


def jpeg_bytes(image):
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG", quality=88)
    return buffer.getvalue()


def png_bytes(image):
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def hex_colour(value):
    value = value.lstrip("#")
    return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4))


def system_font(name):
    """Font files with Japanese names are stored decomposed, so they are matched normalised."""
    for path in FONTS_DIR.iterdir():
        if unicodedata.normalize("NFC", path.name) == name:
            return str(path)
    raise FileNotFoundError(name)


def font(kind, size):
    path, variation = {
        "serif": ("NewYork.ttf", "Semibold"),
        "sans": ("SFNS.ttf", "Bold"),
        "rounded": ("SFNSRounded.ttf", "Bold"),
        "mono": ("SFNSMono.ttf", "Bold"),
        "kanji": ("ヒラギノ角ゴシック W8.ttc", None),
    }[kind]
    loaded = ImageFont.truetype(system_font(path), size)
    if variation:
        try:
            loaded.set_variation_by_name(variation)
        except (OSError, ValueError):
            pass
    return loaded


def initials(title):
    words = [word for word in title.replace("r/", "").replace("&", " ").split()
             if word.lower() not in ("the", "dept.") and word[0].isalnum()]
    return "".join(word[0] for word in words[:2]).upper()


def draw_centered_text(icon, text, kind, colour, fill_ratio=0.62):
    """The largest size of `text` that fits within `fill_ratio` of the icon, centred on its ink."""
    draw = ImageDraw.Draw(icon)
    size = ICON_SIZE
    while size > 20:
        loaded = font(kind, size)
        left, top, right, bottom = draw.textbbox((0, 0), text, font=loaded)
        if max(right - left, bottom - top) <= ICON_SIZE * fill_ratio:
            break
        size -= 8
    draw.text(((ICON_SIZE - (right - left)) / 2 - left, (ICON_SIZE - (bottom - top)) / 2 - top),
              text, font=loaded, fill=colour)


def draw_rings(icon, colour):
    draw = ImageDraw.Draw(icon)
    centre = ICON_SIZE / 2
    for index, radius in enumerate((200, 150, 100)):
        alpha = (90, 150, 220)[index]
        ring = Image.new("RGBA", icon.size)
        ImageDraw.Draw(ring).ellipse(
            (centre - radius, centre - radius, centre + radius, centre + radius),
            outline=colour + (alpha,), width=22,
        )
        icon.paste(ring, (0, 0), ring)
    draw.ellipse((centre - 46, centre - 46, centre + 46, centre + 46), fill=colour)


def feed_icon(feed):
    """A feed's icon, in the style its `icon` entry names; a mesh with serif initials by default.

    styles: mesh, solid, glyph, rings, stripes
    """
    spec = feed.get("icon", {})
    style = spec.get("style", "mesh")
    text = spec.get("text", initials(feed["title"]["en"]))
    foreground = hex_colour(spec.get("foreground", "#FFFFFF"))
    if "background" in spec:
        icon = Image.new("RGB", (ICON_SIZE, ICON_SIZE), hex_colour(spec["background"]))
    else:
        icon = mesh_gradient(feed["key"] + "-icon", ICON_SIZE, ICON_SIZE, feed["hue"])

    if style == "stripes":
        bands = [hex_colour(colour) for colour in spec["bands"]]
        band_height = ICON_SIZE / len(bands)
        draw = ImageDraw.Draw(icon)
        for index, colour in enumerate(bands):
            draw.rectangle((0, index * band_height, ICON_SIZE, (index + 1) * band_height), fill=colour)
        draw_centered_text(icon, text, spec.get("font", "sans"), foreground, 0.5)
    elif style == "glyph":
        draw_glyph(icon, spec["glyph"], foreground, hex_colour(spec.get("accent", "#FFFFFF")))
    elif style == "rings":
        draw_rings(icon, foreground)
    else:
        draw_centered_text(icon, text, spec.get("font", "serif"), foreground, spec.get("fill", 0.62))
    return png_bytes(icon)
