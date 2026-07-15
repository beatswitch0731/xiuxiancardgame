import os
import shutil

src_dir = r'E:\4e\游1\2026-06-27-05-40-58'
target_base = os.path.join(src_dir, 'xiuxian-card-game', 'docs')
gdd_dir = os.path.join(target_base, 'gdd')
rep_dir = os.path.join(target_base, 'reports')

os.makedirs(gdd_dir, exist_ok=True)
os.makedirs(rep_dir, exist_ok=True)

files = [f for f in os.listdir(src_dir) if f.endswith('.md')]
for f in files:
    dest = rep_dir if '报告' in f or '审计' in f else gdd_dir
    src_path = os.path.join(src_dir, f)
    dest_path = os.path.join(dest, f)
    if os.path.exists(src_path):
        shutil.move(src_path, dest_path)
        print(f"Moved {f} to {dest}")
