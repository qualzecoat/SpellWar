#!/usr/bin/env python3
"""ONE-OFF migration (Fase 3b1, 2026-10-15): bangun scenes/map_3b.tscn dari
data trace lama (scripts/map_data_gen.gd).

Setelah scene jadi, SINGLE SOURCE OF TRUTH = scenes/map_3b.tscn (editable di
editor Godot). Data turunan diregenerasi via tools/export_map_data.py.

Jalankan sekali dari root repo:  python3 tools/build_map_scene.py
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEN = os.path.join(ROOT, "scripts", "map_data_gen.gd")
OUT = os.path.join(ROOT, "scenes", "map_3b.tscn")

FLOOR_COLOR = (0.13, 0.13, 0.18)
WALL_COLOR = (0.38, 0.41, 0.52)


def fnum(v: float) -> str:
    v = round(float(v), 1)
    if v == int(v):
        return str(int(v))
    return str(v)


def parse_rects(text: str, name: str):
    m = re.search(name + r"\s*:\s*Array\s*=\s*\[(.*?)\]", text, re.S)
    assert m, f"const {name} tidak ketemu"
    rects = []
    for mm in re.finditer(
            r"Rect2\(([-0-9.]+),\s*([-0-9.]+),\s*([-0-9.]+),\s*([-0-9.]+)\)",
            m.group(1)):
        rects.append(tuple(float(x) for x in mm.groups()))
    return rects


def main() -> None:
    with open(GEN, encoding="utf-8") as fh:
        text = fh.read()
    walls = parse_rects(text, "WALL_RECTS")
    floors = parse_rects(text, "FLOOR_RECTS")
    print(f"walls={len(walls)} floors={len(floors)}")

    # Hitung bounds dari wall rects (harus sama dengan MAP_W/H lama).
    maxx = max(x + w for x, y, w, h in walls)
    maxy = max(y + h for x, y, w, h in walls)
    print(f"bounds dari walls: {fnum(maxx)} x {fnum(maxy)}")

    L = []
    # NOTE: TIDAK ADA baris komentar '#' di file ini — parser Godot 4.7
    # me-skip properti tepat setelah baris komentar (lihat PROJECT.md).
    L.append("[gd_scene load_steps=%d format=3]" % (1 + len(walls) + 1))
    L.append("")
    L.append('[ext_resource type="Script" path="res://scripts/map_3b.gd" '
             'id="1_map3b"]')
    for i, (x, y, w, h) in enumerate(walls, 1):
        L.append("")
        L.append('[sub_resource type="RectangleShape2D" '
                 f'id="RectangleShape2D_wall_{i:03d}"]')
        L.append(f"size = Vector2({fnum(w)}, {fnum(h)})")
    L.append("")
    L.append('[node name="Map3B" type="Node2D"]')
    L.append('script = ExtResource("1_map3b")')
    L.append("")
    L.append('[node name="Background" type="Polygon2D" parent="."]')
    L.append("polygon = PackedVector2Array("
             f"{fnum(0)}, {fnum(0)}, {fnum(maxx)}, {fnum(0)}, "
             f"{fnum(maxx)}, {fnum(maxy)}, {fnum(0)}, {fnum(maxy)})")
    L.append("color = Color(%s, %s, %s, 1)" % tuple(fnum(c) for c in WALL_COLOR))
    L.append("")
    L.append('[node name="Floor" type="Node2D" parent="."]')
    for i, (x, y, w, h) in enumerate(floors, 1):
        L.append("")
        L.append(f'[node name="Floor_{i:03d}" type="Polygon2D" parent="Floor"]')
        L.append("polygon = PackedVector2Array("
                 f"{fnum(x)}, {fnum(y)}, {fnum(x + w)}, {fnum(y)}, "
                 f"{fnum(x + w)}, {fnum(y + h)}, {fnum(x)}, {fnum(y + h)})")
        L.append("color = Color(%s, %s, %s, 1)"
                 % tuple(fnum(c) for c in FLOOR_COLOR))
    L.append("")
    L.append('[node name="Walls" type="StaticBody2D" parent="."]')
    for i, (x, y, w, h) in enumerate(walls, 1):
        cx, cy = x + w / 2.0, y + h / 2.0
        L.append("")
        L.append(f'[node name="Wall_{i:03d}" type="CollisionShape2D" '
                 'parent="Walls"]')
        L.append(f"position = Vector2({fnum(cx)}, {fnum(cy)})")
        L.append(f'shape = SubResource("RectangleShape2D_wall_{i:03d}")')

    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(L) + "\n")
    print("ditulis:", OUT)


if __name__ == "__main__":
    sys.exit(main())
