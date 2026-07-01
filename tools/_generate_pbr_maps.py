"""
P0-3: Generate Normal Map + Material Map for Lit Pixel Shader
- Normal Map: Sobel gradient → height → normal (RGB)
- Material Map: R=roughness, G=metallic, B=AO, A=emission
Output goes to assets/characters/ as {name}_normal.png and {name}_material.png
"""
from PIL import Image, ImageFilter
import glob, os, math

SRC_DIR = "assets/characters"
TARGET_W, TARGET_H = 512, 768

def sobel_normal_map(img):
    """Generate normal map from grayscale using Sobel operator."""
    gray = img.convert("L")
    w, h = gray.size
    pixels = list(gray.getdata())
    
    normal = Image.new("RGB", (w, h))
    normal_pixels = []
    
    for y in range(h):
        for x in range(w):
            # Sobel 3x3
            tl = pixels[(y-1)*w + (x-1)] if y>0 and x>0 else pixels[y*w+x]
            t  = pixels[(y-1)*w + x]     if y>0 else pixels[y*w+x]
            tr = pixels[(y-1)*w + (x+1)] if y>0 and x<w-1 else pixels[y*w+x]
            l  = pixels[y*w + (x-1)]     if x>0 else pixels[y*w+x]
            r  = pixels[y*w + (x+1)]     if x<w-1 else pixels[y*w+x]
            bl = pixels[(y+1)*w + (x-1)] if y<h-1 and x>0 else pixels[y*w+x]
            b  = pixels[(y+1)*w + x]     if y<h-1 else pixels[y*w+x]
            br = pixels[(y+1)*w + (x+1)] if y<h-1 and x<w-1 else pixels[y*w+x]
            
            # Sobel gradient
            gx = (-tl - 2*l - bl + tr + 2*r + br) / 8.0
            gy = (-tl - 2*t - tr + bl + 2*b + br) / 8.0
            
            # Strength: edge intensity drives normal steepness
            strength = min(math.sqrt(gx*gx + gy*gy) / 64.0, 1.0) * 0.6
            
            # Normal: tangent-space, pointing mostly forward (0,0,1)
            nx = -gx / 255.0 * strength
            ny = -gy / 255.0 * strength
            nz = math.sqrt(max(1.0 - nx*nx - ny*ny, 0.0))
            
            # Pack to RGB
            r = int((nx + 1.0) * 127.5)
            g = int((ny + 1.0) * 127.5)
            b = int(nz * 255)
            
            normal_pixels.append((r, g, b))
    
    normal.putdata(normal_pixels)
    return normal

def material_map(img):
    """Generate material map from color image.
    R channel: roughness (inverse of local contrast)
    G channel: metallic (based on saturation + brightness)
    B channel: ambient occlusion (based on local darkness)
    A channel: emission mask (bright saturated areas)
    """
    w, h = img.size
    pixels = list(img.convert("RGBA").getdata())
    gray = list(img.convert("L").getdata())
    
    mat = Image.new("RGBA", (w, h))
    mat_pixels = []
    
    for y in range(h):
        for x in range(w):
            idx = y * w + x
            r_px, g_px, b_px, a_px = pixels[idx]
            lum = gray[idx]
            
            if a_px == 0:  # Transparent → default material
                mat_pixels.append((0, 0, 0, 0))
                continue
            
            # R: Roughness (0=glossy, 255=rough)
            # Pixel art tends to be uniform → higher roughness overall
            # Add localized variation based on gradient
            local_contrast = _local_contrast(gray, w, h, x, y, idx)
            roughness = int(min(255, 180 - local_contrast * 0.5))
            
            # G: Metallic (0=dielectric, 255=metallic)
            # Metallic areas: low saturation, medium-high luminance (silver/gold/steel)
            max_rgb = max(r_px, g_px, b_px)
            min_rgb = min(r_px, g_px, b_px)
            saturation = max_rgb - min_rgb
            if saturation < 30 and lum > 80:
                metallic = min(int(lum * 0.7), 200)
            else:
                metallic = 0
            
            # B: Ambient Occlusion
            # Darker areas → more occluded (higher AO → 255 means fully lit)
            ao = int(lum * 0.8 + 40)
            
            # A: Emission mask
            # Bright + saturated = emissive (magic effects, glowing eyes)
            if saturation > 100 and lum > 180:
                emission = min(int(saturation * 0.6), 255)
            else:
                emission = 0
            
            mat_pixels.append((roughness, metallic, ao, emission))
    
    mat.putdata(mat_pixels)
    return mat

def _local_contrast(gray, w, h, x, y, idx):
    """Compute local contrast using 5x5 neighborhood."""
    vals = []
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            nx, ny = x+dx, y+dy
            if 0 <= nx < w and 0 <= ny < h:
                vals.append(gray[ny*w + nx])
    if not vals:
        return 0
    return max(vals) - min(vals)

# Process all character WebP files
files = sorted(glob.glob(f"{SRC_DIR}/*.webp"))
print(f"Generating normal + material maps for {len(files)} characters\n")

for fp in files:
    fname = os.path.basename(fp).replace(".webp", "")
    img = Image.open(fp).convert("RGBA")
    
    # Generate normal map
    normal = sobel_normal_map(img)
    normal_path = f"{SRC_DIR}/{fname}_normal.png"
    normal.save(normal_path, "PNG")
    
    # Generate material map
    mat = material_map(img)
    mat_path = f"{SRC_DIR}/{fname}_material.png"
    mat.save(mat_path, "PNG")
    
    n_kb = os.path.getsize(normal_path) / 1024
    m_kb = os.path.getsize(mat_path) / 1024
    print(f"  {fname}: normal={n_kb:.0f}KB  material={m_kb:.0f}KB")

# Total summary
total_kb = sum(os.path.getsize(f) / 1024 for f in glob.glob(f"{SRC_DIR}/*_normal.png") + glob.glob(f"{SRC_DIR}/*_material.png"))
print(f"\nTOTAL: {total_kb:.0f} KB total for all normal+material maps")
print("Done.")
