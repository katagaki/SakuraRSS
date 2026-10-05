#!/usr/bin/env python3
"""Fills a video player that the simulator left black with a poster frame.

    poster.py <capture.png> <poster image>

Simulators load YouTube videos but never draw their frames, so the player in the
reader column stays black. The black box is found in the right-hand column and the
poster is drawn into it, with a play button, as a paused video would look.
"""

import sys

from PIL import Image, ImageDraw


def black_box(capture):
    """The bounding box of the solid black player in the right part of the capture."""
    width, height = capture.size
    left_limit, top_limit, bottom_limit = int(width * 0.3), int(height * 0.06), int(height * 0.75)
    pixels = capture.load()

    def is_black(x, y):
        red, green, blue = pixels[x, y][:3]
        return max(red, green, blue) < 6

    span = width - left_limit
    rows = [y for y in range(top_limit, bottom_limit, 2)
            if sum(is_black(x, y) for x in range(left_limit, width, 4)) > span / 4 * 0.3]
    if not rows:
        return None
    top = rows[0]
    bottom = top
    for row in rows:
        if row - bottom > 6:
            break
        bottom = row
    middle = (top + bottom) // 2
    columns = [x for x in range(left_limit, width) if is_black(x, middle)]
    left, right = columns[0], columns[-1]
    # The player can start left of the scanned area or run below it, as on the Mac,
    # so it's grown out to the edges of the black.
    while left > 0 and is_black(left - 1, middle):
        left -= 1
    centre = (left + right) // 2
    while bottom + 1 < height and is_black(centre, bottom + 1):
        bottom += 1
    box = (left, top, right + 1, bottom + 1)
    # Only a video-shaped box is the player; anything else means nothing was opened.
    aspect = (box[2] - box[0]) / max(box[3] - box[1], 1)
    return box if 1.4 < aspect < 2.1 else None


def draw_poster(capture, poster, box):
    left, top, right, bottom = box
    box_width, box_height = right - left, bottom - top
    scale = max(box_width / poster.width, box_height / poster.height)
    filled = poster.resize((round(poster.width * scale), round(poster.height * scale)), Image.LANCZOS)
    offset_x = (filled.width - box_width) // 2
    offset_y = (filled.height - box_height) // 2
    capture.paste(filled.crop((offset_x, offset_y, offset_x + box_width, offset_y + box_height)), (left, top))

    radius = min(box_width, box_height) * 0.11
    centre_x, centre_y = left + box_width / 2, top + box_height / 2
    button = Image.new("RGBA", capture.size)
    draw = ImageDraw.Draw(button)
    draw.ellipse((centre_x - radius, centre_y - radius, centre_x + radius, centre_y + radius), fill=(30, 30, 30, 150))
    triangle = radius * 0.42
    draw.polygon([
        (centre_x - triangle * 0.6, centre_y - triangle),
        (centre_x - triangle * 0.6, centre_y + triangle),
        (centre_x + triangle, centre_y),
    ], fill=(255, 255, 255, 235))
    return Image.alpha_composite(capture.convert("RGBA"), button).convert("RGB")


def main():
    capture_path, poster_path = sys.argv[1], sys.argv[2]
    capture = Image.open(capture_path).convert("RGB")
    box = black_box(capture)
    if box is None:
        print(f"no black player found in {capture_path}; left as captured", file=sys.stderr)
        return
    draw_poster(capture, Image.open(poster_path).convert("RGB"), box).save(capture_path)


if __name__ == "__main__":
    main()
