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
    m = re.search(r"Vector2\(\s*([-0-9.eE+]+)\s*,\s*([-0-9.eE+]+)\s*\)", s)
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
    # Format toleran: atribut tambahan (unique_id=...) boleh ada sebelum ']'.
    walls = []
    for m in re.finditer(
            r'\[node name="(Wall_[^"]+)" type="CollisionShape2D" '
            r'parent="Walls"[^\]]*\]\s*\nposition = ([^\n]+)\s*\n'
            r'shape = SubResource\("([^"]+)"\)', text):
        name, pos_s, sid = m.group(1), m.group(2), m.group(3)
        assert sid in sizes, f"shape {sid} tidak ketemu untuk {name}"
        px, py = parse_vec2(pos_s)
        w, h = sizes[sid]
        walls.append((name, px - w / 2.0, py - h / 2.0, w, h))
    # node Floor_* -> bbox dari polygon (untuk preview)
    floors = []
    for m in re.finditer(
            r'\[node name="(Floor_[^"]+)" type="Polygon2D" parent="Floor"'
            r"[^\]]*\].*?\npolygon = PackedVector2Array\(([^)]+)\)",
            text, re.S):
        nums = [float(x) for x in m.group(2).split(",")]
        xs, ys = nums[0::2], nums[1::2]
        floors.append((min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)))
    # Background ber-texture (map visual user): rect texture = batas map.
    # Void di luar texture BUKAN walkable (hindari scatter nyasar ke luar map).
    bg = parse_background(text)
    return walls, floors, bg


def parse_background(text: str):
    m = re.search(r'\[node name="Background" type="Polygon2D"[^\]]*\]\n', text)
    if not m:
        return None
    lines = []
    for line in text[m.end():].split("\n"):
        if line.startswith("["):
            break
        lines.append(line)
    body = "\n".join(lines)
    if "texture =" not in body:
        return None  # background flat: tidak ada batas texture
    pos = parse_vec2(re.search(r"position = ([^\n]+)", body).group(1)) \
        if "position =" in body else (0.0, 0.0)
    scl = parse_vec2(re.search(r"scale = ([^\n]+)", body).group(1)) \
        if "scale =" in body else (1.0, 1.0)
    pm = re.search(r"polygon = PackedVector2Array\(([^)]+)\)", body)
    if not pm:
        return None
    nums = [float(x) for x in pm.group(1).split(",")]
    xs, ys = nums[0::2], nums[1::2]
    return (pos[0] + min(xs) * scl[0], pos[1] + min(ys) * scl[1],
            pos[0] + max(xs) * scl[0], pos[1] + max(ys) * scl[1])


def parse_spawn_pos():
    """Baca Map3B.SPAWN_POS dari scripts/map_3b.gd (seed flood fill)."""
    p = os.path.join(ROOT, "scripts", "map_3b.gd")
    try:
        with open(p, encoding="utf-8") as fh:
            m = re.search(r"const SPAWN_POS := Vector2\(([^,]+), ([^\)]+)\)",
                          fh.read())
        if m:
            return (float(m.group(1)), float(m.group(2)))
    except OSError:
        pass
    return (0.0, 0.0)


def main() -> None:
    walls, floors, bg = parse_scene(SCENE)
    assert walls, "tidak ada wall rect di scenes/map_3b.tscn"
    print(f"walls={len(walls)} floors={len(floors)}")

    if bg is not None and abs(bg[0]) < CELL_PX and abs(bg[1]) < CELL_PX:
        # Map visual = texture user: grid di-clip ke texture (origin tetap 0,0
        # agar mapping map_data.gd tidak berubah). Void di luar = tidak walkable.
        maxx, maxy = bg[2], bg[3]
        print(f"clip grid ke texture: {maxx:.1f} x {maxy:.1f} px")
    else:
        maxx = max(x + w for _, x, y, w, h in walls)
        maxy = max(y + h for _, x, y, w, h in walls)
        if bg is not None:
            print("peringatan: texture tidak mulai di (0,0), pakai bounds walls")
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

    # Kantong terisolasi (tidak terjangkau dari spawn) -> jadikan tembok.
    # Menjamin mask walkable = area yang benar-benar bisa dicapai player
    # (mis. margin kertas kosong di tepi texture). Test flood fill 100%
    # by construction; scatter tidak akan mendarat di kantong mati.
    px = img.load()
    spawn = parse_spawn_pos()
    scx = min(gw - 1, max(0, int(spawn[0] / CELL_PX)))
    scy = min(gh - 1, max(0, int(spawn[1] / CELL_PX)))
    if px[scx, scy] <= 127:
        # seed ketiban tembok: cari sel walkable terdekat
        found = None
        for r in range(1, max(gw, gh)):
            for dy in range(-r, r + 1):
                for dx in (-r, r):
                    x, y = scx + dx, scy + dy
                    if 0 <= x < gw and 0 <= y < gh and px[x, y] > 127:
                        found = (x, y)
                        break
                if found:
                    break
            if found:
                break
        if found:
            scx, scy = found
            print(f"peringatan: SPAWN_POS di dalam tembok, seed geser ke {(scx, scy)}")
        else:
            print("peringatan: tidak ada sel walkable, lewati filter isolasi")
            scx = scy = -1
    if scx >= 0:
        seen = bytearray(gw * gh)
        stack = [scy * gw + scx]
        while stack:
            i = stack.pop()
            if seen[i] or px[i % gw, i // gw] <= 127:
                continue
            seen[i] = 1
            x, y = i % gw, i // gw
            if x > 0:
                stack.append(i - 1)
            if x < gw - 1:
                stack.append(i + 1)
            if y > 0:
                stack.append(i - gw)
            if y < gh - 1:
                stack.append(i + gw)
        cut = 0
        for i in range(gw * gh):
            if not seen[i] and px[i % gw, i // gw] > 127:
                px[i % gw, i // gw] = 0
                cut += 1
        print(f"kantong terisolasi dijadikan tembok: {cut} sel")

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
