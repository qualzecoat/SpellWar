#!/usr/bin/env python3
"""Trace petunjuk-area-map.png -> data map untuk Fase 3b1.

Sumber: ~/workspace/game/map-design/petunjuk-area-map.png (3477x3065).
Legenda: merah = tembok absolut, putih = lantai walkable,
kotak legenda kiri-atas DIABAIKAN (bukan bagian map).

Output (di-commit ke repo):
  assets/map_walk.png      - mask walkability (putih=walkable) resolusi grid
  scripts/map_data_gen.gd  - data hasil generate (JANGAN edit manual!)
Output (tidak di-commit, untuk review user):
  ~/workspace/game/map-design/preview-3b1.png

Cara pakai:  python3 tools/trace_map.py   (dari root repo)
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import label, binary_fill_holes, distance_transform_edt

Image.MAX_IMAGE_PIXELS = None

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.expanduser("~/workspace/game/map-design/petunjuk-area-map.png")

# 1 kotak grid desain ~= 50 px (diukur dari kotak mesin hijau, median ~50px).
DESIGN_GRID_PX = 50.0
# 1 grid game = 64 px (player CharacterBody2D radius 22px < 64px).
GAME_GRID_PX = 64.0
SCALE = GAME_GRID_PX / DESIGN_GRID_PX          # 1.28
# Resolusi sel trace: 10 px desain -> 12.8 px game.
CELL_DESIGN = 10.0
CELL_GAME = CELL_DESIGN * SCALE


def main() -> None:
    im = np.array(Image.open(SRC).convert("RGB")).astype(np.uint8)
    r, g, b = im[:, :, 0].astype(int), im[:, :, 1].astype(int), im[:, :, 2].astype(int)
    H, W = r.shape
    print(f"sumber: {W}x{H}", flush=True)

    # 1. Walkable = putih-ish (threshold 150 menjaga konektivitas koridor).
    #    Langsung downsample ke grid sel via majority vote (vektorisasi, cepat).
    white = (r > 150) & (g > 150) & (b > 150)
    gh = math.ceil(H / CELL_DESIGN)
    gw = math.ceil(W / CELL_DESIGN)
    pad_h = int(gh * CELL_DESIGN - H)
    pad_w = int(gw * CELL_DESIGN - W)
    wp = np.pad(white, ((0, pad_h), (0, pad_w)))
    ch = int(CELL_DESIGN)
    grid = wp.reshape(gh, ch, gw, ch).mean(axis=(1, 3)) > 0.5
    print(f"grid: {gw}x{gh} sel, putih: {grid.sum()} ({100.0 * grid.sum() / grid.size:.1f}%)",
          flush=True)

    # 2. Komponen terbesar = map. Kotak legenda kiri-atas otomatis ter-exclude
    #    (komponen terpisah yang kecil).
    lab, n = label(grid)
    sizes = np.bincount(lab.ravel())
    sizes[0] = 0
    order = np.argsort(sizes)[::-1]
    biggest = int(order[0])
    print(f"komponen: {n}, terbesar: {sizes[biggest]} sel "
          f"({100.0 * sizes[biggest] / grid.sum():.1f}% dari putih)", flush=True)
    if n > 1:
        ys, xs = np.where(lab == int(order[1]))
        print(f"komponen kedua: {sizes[int(order[1])]} sel, bbox sel "
              f"x[{xs.min()},{xs.max()}] y[{ys.min()},{ys.max()}] "
              f"(harus kotak legenda kiri-atas)", flush=True)
        assert xs.max() < 110 and ys.max() < 70 and xs.min() < 20 and ys.min() < 20, \
            "komponen kedua bukan legenda — ada area walkable terpisah!"
    walk = (lab == biggest)
    # 3. Isi lubang interior KECIL saja (cat mesin/angka di atas lantai, <20 sel).
    #    Blok merah besar adalah tembok interior — JANGAN diisi.
    inv_lab, inv_n = label(~walk)
    inv_sizes = np.bincount(inv_lab.ravel())
    inv_sizes[0] = 0
    filled = walk.copy()
    n_filled = 0
    for i in range(1, inv_n + 1):
        sz = int(inv_sizes[i])
        if sz >= 20:
            continue
        ys, xs = np.where(inv_lab == i)
        if ys.min() == 0 or ys.max() == gh - 1 or xs.min() == 0 or xs.max() == gw - 1:
            continue  # menyentuh tepi = eksterior
        filled[inv_lab == i] = True
        n_filled += 1
    print(f"lubang interior kecil diisi: {n_filled} lubang", flush=True)

    # 4. Konektivitas: filled harus 1 komponen utuh (tidak ada ruangan terisolasi).
    lab2, n2 = label(filled)
    s2 = np.bincount(lab2.ravel())
    s2[0] = 0
    biggest2 = int(np.argmax(s2))
    reach = 100.0 * s2[biggest2] / filled.sum()
    print(f"konektivitas flood fill: {reach:.2f}% reachable ({n2} komponen)")
    assert abs(reach - 100.0) < 1e-9, "ADA RUANGAN TERISOLASI!"
    walk_g = (lab2 == biggest2)

    # 5. Cek badan player (disk r=22px) bisa mencapai semua area walkable.
    pr = 22.0 / CELL_GAME  # radius player dalam sel
    yy, xx = np.mgrid[-3:4, -3:4]
    disk = (xx ** 2 + yy ** 2) <= pr * pr
    from scipy.ndimage import binary_erosion
    eroded = binary_erosion(walk_g, structure=disk)
    lab3, n3 = label(eroded)
    s3 = np.bincount(lab3.ravel())
    s3[0] = 0
    reach3 = 100.0 * s3.max() / eroded.sum() if eroded.sum() else 0
    print(f"reachability badan player (disk r=22px): {reach3:.2f}%", flush=True)
    assert reach3 > 99.9, "area tak terjangkau badan player!"

    # 6. Bounds: bbox walkable + margin, snap ke sel.
    ys, xs = np.where(walk_g)
    m = 8  # margin sel (~102px game)
    x0 = max(0, xs.min() - m)
    x1 = min(gw, xs.max() + m + 1)
    y0 = max(0, ys.min() - m)
    y1 = min(gh, ys.max() + m + 1)
    bw, bh = x1 - x0, y1 - y0
    print(f"bounds sel: x[{x0},{x1}] y[{y0},{y1}] -> {bw}x{bh} sel")
    sub = walk_g[y0:y1, x0:x1]

    # 7. Greedy rectangle merge untuk dinding & lantai.
    wall_rects = greedy_merge(~sub)   # dalam koordinat sel lokal
    floor_rects = greedy_merge(sub)
    print(f"wall rects: {len(wall_rects)}, floor rects: {len(floor_rects)}")

    # 8. Konversi ke game px. Origin = pojok kiri-atas bounds.
    def to_game(rects):
        out = []
        for (rx, ry, rw, rh) in rects:
            out.append((
                round((rx) * CELL_GAME, 1),
                round((ry) * CELL_GAME, 1),
                round(rw * CELL_GAME, 1),
                round(rh * CELL_GAME, 1),
            ))
        return out

    wall_g = to_game(wall_rects)
    floor_g = to_game(floor_rects)
    map_w = round(bw * CELL_GAME, 1)
    map_h = round(bh * CELL_GAME, 1)
    print(f"ukuran map game: {map_w} x {map_h} px "
          f"({map_w / GAME_GRID_PX:.1f} x {map_h / GAME_GRID_PX:.1f} grid)")

    # 9. TEMP_SPAWN (3b1): sel walkable dengan jarak terjauh dari dinding.
    dt = distance_transform_edt(sub)
    ci, cj = np.unravel_index(int(np.argmax(dt)), dt.shape)
    ts_x = round((cj + 0.5) * CELL_GAME, 1)
    ts_y = round((ci + 0.5) * CELL_GAME, 1)
    print(f"TEMP_SPAWN (sementara 3b1): ({ts_x}, {ts_y}), "
          f"jarak ke dinding: {dt[ci, cj] * CELL_GAME:.0f}px")
    # Slot MP sementara: 8 titik di lingkaran r=96px sekitar spawn, verified walkable.
    slots = []
    for k in range(8):
        ang = k * math.pi / 4
        px, py = ts_x + 96 * math.cos(ang), ts_y + 96 * math.sin(ang)
        ccx = int(px / CELL_GAME)
        ccy = int(py / CELL_GAME)
        if not (0 <= ccy < bh and 0 <= ccx < bw and sub[ccy, ccx]):
            # fallback: titik spawn itu sendiri (dijamin walkable)
            px, py = ts_x, ts_y
        slots.append((round(px, 1), round(py, 1)))
    # Dummy solo sementara: 3 titik walkable di dekat spawn.
    dummies = []
    for dx, dy in [(160, 0), (-160, 80), (0, -160)]:
        px, py = ts_x + dx, ts_y + dy
        ccx = int(px / CELL_GAME)
        ccy = int(py / CELL_GAME)
        if not (0 <= ccy < bh and 0 <= ccx < bw and sub[ccy, ccx]):
            px, py = ts_x, ts_y
        dummies.append((round(px, 1), round(py, 1)))

    # 10. Tulis assets/map_walk.png (mask grid).
    walk_img = Image.fromarray((sub * 255).astype(np.uint8), mode="L")
    walk_path = os.path.join(REPO, "assets", "map_walk.png")
    walk_img.save(walk_path)
    print("mask:", walk_path, walk_img.size)

    # 11. Tulis scripts/map_data_gen.gd.
    gen_path = os.path.join(REPO, "scripts", "map_data_gen.gd")
    with open(gen_path, "w") as f:
        f.write("class_name MapDataGen\n")
        f.write("## DATA HASIL GENERATE — JANGAN EDIT MANUAL.\n")
        f.write("## Dibuat oleh tools/trace_map.py dari ")
        f.write("petunjuk-area-map.png (Fase 3b1).\n")
        f.write("## Regenerasi:  python3 tools/trace_map.py   (dari root repo)\n")
        f.write("\n")
        f.write(f"const CELL_PX := {CELL_GAME}\n")
        f.write(f"const GRID_W := {bw}\n")
        f.write(f"const GRID_H := {bh}\n")
        f.write(f"const MAP_W := {map_w}\n")
        f.write(f"const MAP_H := {map_h}\n")
        f.write(f"const WALK_MASK := \"res://assets/map_walk.png\"\n")
        f.write(f"const TEMP_SPAWN := Vector2({ts_x}, {ts_y})\n")
        f.write("const TEMP_SPAWN_SLOTS: Array = [\n")
        for i, (sx, sy) in enumerate(slots):
            f.write(f"\tVector2({sx}, {sy}),")
            f.write("  # MP sementara 3b1\n" if i == 0 else "\n")
        f.write("]\n")
        f.write("const TEMP_DUMMY_SPOTS: Array = [\n")
        for dx_, dy_ in dummies:
            f.write(f"\tVector2({dx_}, {dy_}),\n")
        f.write("]\n")
        f.write(f"const WALL_RECTS: Array = [  # {len(wall_g)} rect\n")
        for x, y, w, h in wall_g:
            f.write(f"\tRect2({x}, {y}, {w}, {h}),\n")
        f.write("]\n")
        f.write(f"const FLOOR_RECTS: Array = [  # {len(floor_g)} rect\n")
        for x, y, w, h in floor_g:
            f.write(f"\tRect2({x}, {y}, {w}, {h}),\n")
        f.write("]\n")
    print("data:", gen_path)

    # 12. Preview PNG untuk review user (tidak di-commit).
    prev = Image.new("RGB", (bw, bh), (38, 38, 46))
    dr = ImageDraw.Draw(prev)
    for x, y, w, h in floor_g:
        dr.rectangle([x / CELL_GAME, y / CELL_GAME,
                      (x + w) / CELL_GAME, (y + h) / CELL_GAME],
                     fill=(33, 33, 46))
    for x, y, w, h in wall_g:
        dr.rectangle([x / CELL_GAME, y / CELL_GAME,
                      (x + w) / CELL_GAME, (y + h) / CELL_GAME],
                     fill=(97, 105, 133))
    sc = int(ts_x / CELL_GAME)
    sr = int(ts_y / CELL_GAME)
    dr.ellipse([sc - 2, sr - 2, sc + 2, sr + 2], fill=(255, 80, 80))
    prev_path = os.path.expanduser("~/workspace/game/map-design/preview-3b1.png")
    prev = prev.resize((bw * 2, bh * 2), Image.NEAREST)
    prev.save(prev_path)
    print("preview:", prev_path, prev.size)
    print("SELESAI — semua assert lolos.")


def greedy_merge(mask: np.ndarray):
    """Merge sel True menjadi rect terbesar (greedy). Return [(x,y,w,h)] sel."""
    h, w = mask.shape
    done = np.zeros_like(mask, dtype=bool)
    rects = []
    for y in range(h):
        for x in range(w):
            if not mask[y, x] or done[y, x]:
                continue
            # lebarkan ke kanan
            x2 = x
            while x2 + 1 < w and mask[y, x2 + 1] and not done[y, x2 + 1]:
                x2 += 1
            # lebarkan ke bawah selagi semua kolom penuh
            y2 = y
            while y2 + 1 < h:
                row = mask[y2 + 1, x:x2 + 1]
                drow = done[y2 + 1, x:x2 + 1]
                if row.all() and not drow.any():
                    y2 += 1
                else:
                    break
            done[y:y2 + 1, x:x2 + 1] = True
            rects.append((x, y, x2 - x + 1, y2 - y + 1))
    return rects


if __name__ == "__main__":
    sys.exit(main())
