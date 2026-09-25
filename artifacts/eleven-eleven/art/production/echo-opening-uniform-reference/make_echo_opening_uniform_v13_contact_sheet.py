from pathlib import Path
from PIL import Image, ImageDraw

REF = Path(r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\echo-opening-uniform-reference")

for label, rows, cols in (("phase", 2, 6), ("angle", 3, 8)):
    width, height = 280, 340
    canvas = Image.new("RGB", (cols * width, rows * (height + 25)), (17, 22, 34))
    draw = ImageDraw.Draw(canvas)
    for index in range(rows * cols):
        path = REF / f"v13-{label}-frame-{index:02d}.png"
        if not path.exists():
            print(f"Missing {path}")
            continue
        shot = Image.open(path).convert("RGBA")
        x = (index % cols) * width
        y = (index // cols) * (height + 25)
        canvas.paste(shot, (x, y), shot)
        text = ("walk" if index < cols else "run") + f" {index % cols:02d}"
        draw.text((x + 10, y + height + 3), text, fill="white")
    output = REF / f"v13-gait-{label}-sheet.jpg"
    canvas.save(output, quality=90)
    print("Saved", output)
