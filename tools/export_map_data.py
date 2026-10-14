#!/usr/bin/env python3
"""Turunkan data walkability dari scenes/map_3b.tscn (SINGLE SOURCE OF TRUTH).

Alur kerja user (Godot PC): edit map di editor -> save scenes/map_3b.tscn ->
jalankan script ini dari root repo -> commit + push -> deploy
(web + rebuild server, karena map_data_gen.gd dipakai server).

    python3 tools/export_map_data.py

Output: scripts/map_data_gen.gd (WALL_RECTS, WALK_MASK_B64, dimensi) —
JANGAN EDIT MANUAL. Logika walkability tetap di scripts/map_data.gd
(is_walkable / clamp_to_walkable / random_walkable_near).
"""
import base64
import io
import math
import os
import re
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCENE = os.path.join(ROOT, "scenes", "map_3b.tscn")
OUT = os.path.join(ROOT, "scripts", "map_data_gen.gd")
PREVIEW = os.path.expanduser("~/workspace/game/map-design/preview-3b1.png")

CELL_PX = 12.8  # resolusi grid walkability (sama seperti trace 3b1)


def parse_vec2(s: str):
    m = re.search(r"Vector2\(\s*([-0-9.]+)\s*,\s*([-0-9.]+)\s*\)", s)
    return (float(m.group(1)), float(m.group(2)))


def parse_scene(path: str):
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    # sub_resource id -> size
    sizes = {}
    for m in re.finditer(
            r'\[sub_resource type="RectangleShape2D" id="([^"]+)"\]\s*\n'
            r"size = ([^\n]+)", text):
        sizes[m.group(1)] = parse_vec2(m.group(2))
    # node Wall_* -> (position, shape id)
    walls = []
    for m in re.finditer(
            r'\[node name="(Wall_\d+)" type="CollisionShape2D" '
            r'parent="Walls"\]\s*\nposition = ([^\n]+)\s*\n'
            r'shape = SubResource\("([^"]+)"\)', text):
        name, pos_s, sid = m.group(1), m.group(2), m.group(3)
        assert sid in sizes, f"shape {sid} tidak ketemu untuk {name}"
        px, py = parse_vec2(pos_s)
        w, h = sizes[sid]
        walls.append((name, px - w / 2.0, py - h / 2.0, w, h))
    # node Floor_* -> bbox dari polygon (untuk preview)
    floors = []
    for m in re.finditer(
            r'\[node name="(Floor_\d+)" type="Polygon2D" parent="Floor"\]\s*\n'
            r"polygon = PackedVector2Array\(([^)]+)\)", text):
        nums = [float(x) for x in m.group(2).split(",")]
        xs, ys = nums[0::2], nums[1::2]
        floors.append((min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)))
    return walls, floors


def main() -> None:
    walls, floors = parse_scene(SCENE)
    assert walls, "tidak ada wall rect di scenes/map_3b.tscn"
    print(f"walls={len(walls)} floors={len(floors)}")

    maxx = max(x + w for _, x, y, w, h in walls)
    maxy = max(y + h for _, x, y, w, h in walls)
    gw = int(math.ceil(maxx / CELL_PX))
    gh = int(math.ceil(maxy / CELL_PX))
    print(f"bounds: {maxx:.1f} x {maxy:.1f} px -> grid {gw} x {gh}")

    # Rasterisasi: sel walkable bila titik tengahnya TIDAK di dalam wall rect.
    img = Image.new("L", (gw, gh), 255)
    px = img.load()
    for cy in range(gh):
        y = (cy + 0.5) * CELL_PX
        for cx in range(gw):
            x = (cx + 0.5) * CELL_PX
            for _, wx, wy, ww, wh in walls:
                if wx <= x < wx + ww and wy <= y < wy + wh:
                    px[cx, cy] = 0
                    break
    walk_n = sum(1 for v in img.getdata() if v > 127)
    print(f"walkable: {walk_n}/{gw*gh} sel "
          f"({100.0*walk_n/(gw*gh):.1f}%)")

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode("ascii")

    def fnum(v: float) -> str:
        v = round(float(v), 1)
        return str(int(v)) if v == int(v) else str(v)

    L = []
    L.append("class_name MapDataGen")
    L.append("## DATA TURUNAN — JANGAN EDIT MANUAL.")
    L.append("## Dibuat oleh tools/export_map_data.py dari scenes/map_3b.tscn")
    L.append("## (single source of truth, editable di editor Godot).")
    L.append("## Regenerasi:  python3 tools/export_map_data.py   (dari root repo)")
    L.append("")
    L.append(f"const CELL_PX := {CELL_PX}")
    L.append(f"const GRID_W := {gw}")
    L.append(f"const GRID_H := {gh}")
    L.append(f"const MAP_W := {fnum(maxx)}")
    L.append(f"const MAP_H := {fnum(maxy)}")
    L.append(f'const WALK_MASK_B64 := "{b64}"')
    L.append(f"const WALL_RECTS: Array = [  # {len(walls)} rect")
    for _, x, y, w, h in walls:
        L.append(f"\tRect2({fnum(x)}, {fnum(y)}, {fnum(w)}, {fnum(h)}),")
    L.append("]")
    L.append(f"const FLOOR_RECTS: Array = [  # {len(floors)} rect")
    for x, y, w, h in floors:
        L.append(f"\tRect2({fnum(x)}, {fnum(y)}, {fnum(w)}, {fnum(h)}),")
    L.append("]")
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(L) + "\n")
    print("ditulis:", OUT)

    # Preview untuk cek visual (tidak di-commit).
    bw, bh = gw * 2, gh * 2
    prev = Image.new("RGB", (bw, bh), (38, 38, 46))
    dr = ImageDraw.Draw(prev)
    for _, x, y, w, h in walls:
        dr.rectangle([x / CELL_PX * 2, y / CELL_PX * 2,
                      (x + w) / CELL_PX * 2, (y + h) / CELL_PX * 2],
                     fill=(97, 105, 133))
    prev.save(PREVIEW)
    print("preview:", PREVIEW)


if __name__ == "__main__":
    sys.exit(main())
