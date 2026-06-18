"""Generates a white guitar-pick glyph PNG for the home-screen widget.

Run from project root:  python3 tool/generate_widget_icon.py
"""
from PIL import Image, ImageDraw

S = 256  # supersampled canvas
OUT = "android/app/src/main/res/drawable/ic_widget_pick.png"


def rounded_triangle(draw, p1, p2, p3, r, fill):
    pts = [p1, p2, p3]
    # corner discs
    for (x, y) in pts:
        draw.ellipse([x - r, y - r, x + r, y + r], fill=fill)
    # inner triangle + edge strips (thick round-capped lines)
    draw.polygon(pts, fill=fill)
    for a in range(3):
        x0, y0 = pts[a]
        x1, y1 = pts[(a + 1) % 3]
        draw.line([(x0, y0), (x1, y1)], fill=fill, width=int(r * 2))


img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

white = (255, 255, 255, 255)
# pick pointing down: two rounded top corners, sharper-ish bottom point
top_l = (S * 0.30, S * 0.32)
top_r = (S * 0.70, S * 0.32)
bottom = (S * 0.50, S * 0.78)
rounded_triangle(d, top_l, top_r, bottom, r=int(S * 0.13), fill=white)

img.resize((128, 128), Image.LANCZOS).save(OUT)
print("Wrote", OUT)
