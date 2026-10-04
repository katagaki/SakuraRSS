"""Simple vector pictograms for feed icons, drawn on a 0–100 grid.

Each is drawn at four times the icon's size and scaled down, which smooths the edges.
"""

import math

from PIL import Image, ImageDraw

SUPERSAMPLE = 4


class Canvas:
    """Maps the 0–100 drawing grid onto a square image of `size` pixels."""

    def __init__(self, size):
        self.size = size
        self.image = Image.new("RGBA", (size, size))
        self.draw = ImageDraw.Draw(self.image)

    def point(self, x, y):
        return (x * self.size / 100, y * self.size / 100)

    def box(self, left, top, right, bottom):
        return (*self.point(left, top), *self.point(right, bottom))

    def length(self, value):
        return value * self.size / 100


def dunes(canvas, foreground, accent):
    canvas.draw.ellipse(canvas.box(56, 18, 80, 42), fill=accent)
    for top, shade in ((52, 0.8), (64, 1.0)):
        points = [canvas.point(x, top + 9 * math.sin((x - 10) / 80 * math.pi * 1.4)) for x in range(10, 91, 2)]
        points += [canvas.point(90, 84), canvas.point(10, 84)]
        canvas.draw.polygon(points, fill=tuple(int(channel * shade) for channel in foreground))


def snowflake(canvas, foreground, accent):
    width = canvas.length(5)
    centre = canvas.point(50, 50)
    for arm in range(6):
        angle = math.radians(arm * 60 - 90)
        end = canvas.point(50 + 34 * math.cos(angle), 50 + 34 * math.sin(angle))
        canvas.draw.line((centre, end), fill=foreground, width=round(width))
        for along, spread in ((20, 10), (28, 7)):
            base_x, base_y = 50 + along * math.cos(angle), 50 + along * math.sin(angle)
            for side in (-1, 1):
                branch = angle + side * math.radians(45)
                tip = canvas.point(base_x + spread * math.cos(branch), base_y + spread * math.sin(branch))
                canvas.draw.line((canvas.point(base_x, base_y), tip), fill=foreground, width=round(width * 0.8))
    canvas.draw.ellipse(canvas.box(45, 45, 55, 55), fill=accent)


def yakitori(canvas, foreground, accent):
    """A skewer running corner to corner, with chicken and leek pieces in turn."""
    start, end = (20, 84), (82, 18)
    canvas.draw.line((canvas.point(*start), canvas.point(*end)), fill=(214, 182, 132), width=round(canvas.length(4)))
    leek = (178, 214, 120)
    for index, along in enumerate((0.22, 0.38, 0.54, 0.70)):
        x = start[0] + (end[0] - start[0]) * along
        y = start[1] + (end[1] - start[1]) * along
        radius = 9.5 if index % 2 == 0 else 7
        canvas.draw.ellipse(canvas.box(x - radius, y - radius, x + radius, y + radius),
                            fill=foreground if index % 2 == 0 else leek)
        if index % 2 == 0:
            canvas.draw.ellipse(canvas.box(x - radius * 0.5, y - radius * 0.65, x, y - radius * 0.2), fill=accent)


def gamepad(canvas, foreground, accent):
    canvas.draw.rounded_rectangle(canvas.box(14, 32, 86, 70), radius=canvas.length(18), fill=foreground)
    canvas.draw.rectangle(canvas.box(25, 47, 41, 54), fill=accent)
    canvas.draw.rectangle(canvas.box(29.5, 42.5, 36.5, 58.5), fill=accent)
    for x, y in ((66, 45), (74, 53), (58, 53), (66, 61)):
        canvas.draw.ellipse(canvas.box(x - 4, y - 4, x + 4, y + 4), fill=accent)


GLYPHS = {
    "dunes": dunes,
    "snowflake": snowflake,
    "yakitori": yakitori,
    "gamepad": gamepad,
}


def draw_glyph(icon, name, foreground, accent):
    canvas = Canvas(icon.width * SUPERSAMPLE)
    GLYPHS[name](canvas, foreground, accent)
    glyph = canvas.image.resize(icon.size, Image.LANCZOS)
    icon.paste(glyph, (0, 0), glyph)
