import os
import re
from PIL import Image

def crop_center(pil_img, crop_width, crop_height):
    img_width, img_height = pil_img.size
    
    target_ratio = crop_width / crop_height
    img_ratio = img_width / img_height
    
    if img_ratio > target_ratio:
        # Image is wider
        new_width = int(img_height * target_ratio)
        new_height = img_height
    else:
        # Image is taller
        new_width = img_width
        new_height = int(img_width / target_ratio)
        
    left = (img_width - new_width) // 2
    top = (img_height - new_height) // 2
    right = (img_width + new_width) // 2
    bottom = (img_height + new_height) // 2
    
    cropped = pil_img.crop((left, top, right, bottom))
    return cropped.resize((crop_width, crop_height), Image.Resampling.LANCZOS)

source_dir = r"C:\Users\rust1\.gemini\antigravity-ide\brain\6096a3c1-1e33-4fae-8a3a-3b9e30a48d45"
project_dir = r"e:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game"

# Specific mappings for custom named files
mapping = {
    "bai_luoxuan_concept": ("assets/characters/concept_bai_luoxuan.webp", "WEBP"),
    "bai_luoxuan_seductive": ("assets/characters/bai_luoxuan_seductive_v8_greeksculpt.png", "PNG"),
    "jiuwei_suyue": ("assets/characters/jiuwei_suyue_seductive.webp", "WEBP"),
    "scene_camp": ("assets/cards/events/scene_camp.png", "PNG"),
}

def process_images():
    for filename in os.listdir(source_dir):
        if not filename.endswith(".png"):
            continue
            
        target_rel_path = None
        img_format = "PNG"
        
        # Check specific mapping
        for key, (path, fmt) in mapping.items():
            if filename.startswith(key):
                target_rel_path = path
                img_format = fmt
                break
                
        # Auto-match for chapter scenes (e.g. scene_ch_qi_20)
        if not target_rel_path and filename.startswith("scene_ch_"):
            # Extract the actual name without the trailing timestamp that gemini adds
            # Format: scene_ch_qi_20_1784050766588.png -> scene_ch_qi_20.png
            match = re.match(r"(scene_ch_[a-z]+_\d+).*\.png", filename)
            if match:
                clean_name = match.group(1) + ".png"
                target_rel_path = f"assets/cards/events/{clean_name}"
                
        if target_rel_path:
            src_path = os.path.join(source_dir, filename)
            target_path = os.path.join(project_dir, target_rel_path.replace("/", "\\"))
            
            os.makedirs(os.path.dirname(target_path), exist_ok=True)
            
            try:
                img = Image.open(src_path)
                cropped_img = crop_center(img, 832, 1144)
                cropped_img.save(target_path, format=img_format)
                print(f"Processed and saved: {target_path}")
            except Exception as e:
                print(f"Error processing {filename}: {e}")

if __name__ == "__main__":
    process_images()
