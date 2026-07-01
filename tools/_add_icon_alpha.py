"""
P0-2: Add alpha channel to icons
Uses corner-sampled flood-fill for accurate background removal.
Handles both dark backgrounds (lum~15-30) and medium ones (lum~50-70 for pill).
"""
from PIL import Image
import glob, os, math
from collections import deque

ICON_DIR = "assets/icons"
COLOR_TOLERANCE = 35  # Euclidean RGB distance tolerance for background

def color_dist(c1, c2):
    return math.sqrt(sum((a-b)**2 for a, b in zip(c1[:3], c2[:3])))

def is_background(pixel_rgb, bg_sample, lum_tolerance=80):
    """Check if pixel is background using color distance + luminance combo."""
    r, g, b = pixel_rgb
    lum = 0.299*r + 0.587*g + 0.114*b
    dist = color_dist(pixel_rgb[:3], bg_sample[:3])
    
    # Strategy: low luminance + close to bg sample = transparent
    if dist <= COLOR_TOLERANCE:
        return True
    # Medium luminance but low saturation (grayish) = likely background
    saturation = max(r,g,b) - min(r,g,b)
    if lum < lum_tolerance and saturation < 40:
        return True
    return False

def flood_fill_alpha(img):
    """Flood fill from 4 corners to identify background pixels."""
    w, h = img.size
    pixels = list(img.getdata())
    # Visited mask: 0 = unchecked, 1 = confirmed bg, 2 = confirmed fg
    mask = bytearray(w * h)
    
    corners = [(0,0), (w-1,0), (0,h-1), (w-1,h-1)]
    queue = deque()
    
    # Collect corner bg colors for sampling
    corner_colors = []
    for cx, cy in corners:
        idx = cy * w + cx
        r,g,b,a = pixels[idx]
        corner_colors.append((r,g,b))
        queue.append((cx, cy))
        mask[idx] = 1
    
    # Average corner color as bg reference
    avg_r = int(sum(c[0] for c in corner_colors) / len(corner_colors))
    avg_g = int(sum(c[1] for c in corner_colors) / len(corner_colors))
    avg_b = int(sum(c[2] for c in corner_colors) / len(corner_colors))
    bg_sample = (avg_r, avg_g, avg_b)
    
    # BFS flood fill
    while queue:
        x, y = queue.popleft()
        for dx, dy in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(1,-1),(-1,1),(1,1)]:
            nx, ny = x + dx, y + dy
            if nx < 0 or nx >= w or ny < 0 or ny >= h:
                continue
            nidx = ny * w + nx
            if mask[nidx] != 0:
                continue
            r,g,b,a = pixels[nidx]
            if is_background((r,g,b), bg_sample):
                mask[nidx] = 1
                queue.append((nx, ny))
    
    # Build new RGBA pixels
    new_pixels = []
    for i, (r,g,b,a) in enumerate(pixels):
        if mask[i] == 1:
            new_pixels.append((r, g, b, 0))
        else:
            new_pixels.append((r, g, b, a))
    
    img.putdata(new_pixels)
    return img

files = sorted(glob.glob(f"{ICON_DIR}/*.png"))
print(f"Processing {len(files)} icons\n")

for fp in files:
    fname = os.path.basename(fp)
    img = Image.open(fp).convert("RGBA")
    w, h = img.size
    
    img = flood_fill_alpha(img)
    img.save(fp, "PNG")
    
    orig_kb = os.path.getsize(fp) / 1024
    print(f"  {fname}: {w}x{h} -> alpha added ({orig_kb:.0f}KB)")

print("\nDone. All icons now have transparent backgrounds (RGBA).")
