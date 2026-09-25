from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

BASE = Path(r"C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\rokoko-walk-run-source\source-previews")
groups = [("05", "run treadmill"), ("08", "happy walk"), ("11", "cool walk"), ("02", "walk forward")]
canvas = Image.new("RGB", (9 * 200, len(groups) * 288), (20, 24, 34))
draw = ImageDraw.Draw(canvas)
for row, (prefix, label) in enumerate(groups):
    images = sorted(BASE.glob(f"{prefix}_*.png"))
    draw.text((5, row * 288 + 4), label, fill="white")
    for col, path in enumerate(images):
        shot = Image.open(path).convert("RGBA").resize((195, 260))
        canvas.paste(shot, (col * 200, row * 288 + 20), shot)
        draw.text((col * 200 + 5, row * 288 + 265), path.stem[3:], fill="white")
output = BASE / "rokoko-source-motion-sheet.jpg"
canvas.save(output, quality=88)
print(output)
