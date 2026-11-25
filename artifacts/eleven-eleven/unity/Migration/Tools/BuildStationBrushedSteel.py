from pathlib import Path
import os

import numpy as np
from PIL import Image

root = Path(os.environ["ECHO_STATION_PROJECT"]) / "Assets/ElevenEleven/Opening/Stormworks/StationFinishes"
root.mkdir(exist_ok=True)
rng = np.random.default_rng(1111)
size = 512

def field(width, height):
    random = np.rint(rng.random((height, width)) * 255).astype(np.uint8)
    tile = Image.fromarray(np.tile(random, (3, 3)))
    tile = tile.resize((size * 3, size * 3), Image.Resampling.BICUBIC)
    return np.asarray(tile.crop((size, size, size * 2, size * 2)), dtype=np.float32) / 255 - .5

wide_wear = field(7, 12)
brush = field(5, 220)
oxide = field(104, 117)
pitting = np.maximum(field(256, 320) - .27, 0)
shade = 236 + 20 * brush + 21 * wide_wear - 26 * pitting - 8 * oxide
stain = np.maximum(oxide + wide_wear - .18, 0)
rgb = np.stack((shade - 21 * stain, shade - 18 * stain, shade - 17 * stain), axis=-1)
Image.fromarray(np.rint(np.clip(rgb, 0, 255)).astype(np.uint8)).save(root / "Station-BrushedSteel-Base.png")

height = .033 * brush - .055 * pitting + .024 * oxide
normal = np.stack((np.roll(height, 1, 1) - np.roll(height, -1, 1),
                   np.roll(height, -1, 0) - np.roll(height, 1, 0), np.ones_like(height)), axis=-1)
normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
Image.fromarray(np.rint((normal * .5 + .5) * 255).astype(np.uint8)).save(root / "Station-BrushedSteel-Normal.png")

metal = np.clip(132 - 75 * stain - 20 * pitting, 0, 255)
smoothness = np.clip(135 + 43 * brush - 104 * stain - 69 * pitting, 0, 255)
blank = np.zeros_like(metal)
mask = np.stack((metal, blank, blank, smoothness), axis=-1)
Image.fromarray(np.rint(mask).astype(np.uint8)).save(root / "Station-BrushedSteel-MetalSmooth.png")
