#!/usr/bin/env python3
"""Turns a scene capture into the snapshot the tab switcher shows for a tab.

    snapshot.py <capture.png> <snapshot.jpg>

The app saves a JPEG of each tab's page when you leave it, and shows it on the tab's card.
A capture taken earlier in the run stands in for one, with the status bar painted over
in the colour just below it, since a page snapshot has none of its own.
"""

import sys

from PIL import Image

STATUS_BAR_FRACTION = 0.06


def main():
    capture = Image.open(sys.argv[1]).convert("RGB")
    width, height = capture.size
    status_bar = round(height * STATUS_BAR_FRACTION)
    pixels = capture.load()
    for x in range(width):
        colour = pixels[x, status_bar + 2]
        for y in range(status_bar):
            pixels[x, y] = colour
    capture.save(sys.argv[2], format="JPEG", quality=80)


if __name__ == "__main__":
    main()
