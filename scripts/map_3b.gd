class_name Map3B
extends Node2D
## Map Fase 3b1 — SINGLE SOURCE OF TRUTH = scenes/map_3b.tscn (editable di
## editor Godot: geser/ubah ukuran node Wall_XXX / Floor_XXX).
## Setelah edit scene: jalankan `python3 tools/export_map_data.py` dari root
## repo untuk meregenerasi data turunan (walkability), lalu commit + push +
## deploy (web + rebuild server). Lihat PROJECT.md bagian gotcha.
##
## Script ini HANYA berisi konstanta sementara 3b1. TIDAK ada logika build —
## geometri dibaca dari node-node scene.

# --- 3b1 SEMENTARA ---
# Belum ada mesin (baru di 3b3/3b4). Sentinel di luar map agar validasi jarak
# interaksi selalu gagal dengan aman: tidak crash, tidak bisa dipakai.
const PUZZLE_POS := Vector2(-99999, -99999)
const EXCHANGE_POS := Vector2(-99999, -99999)
const MACHINE_POS := Vector2(-99999, -99999)
# 3b2: 8 area spawn resmi = posisi angka 1-8 yang SUDAH DIGAMBAR di texture
# map user (pink/magenta). Player random spawn di salah satu dari 8 titik ini.
# Koordinat dari deteksi piksel pink di texture, diverifikasi walkable.
const SPAWN_POINTS: Array = [
	Vector2(633.6, 3526.4),   # 1: kiri
	Vector2(2425.6, 1939.2),  # 2: kiri atas
	Vector2(5216.0, 1644.8),  # 3: atas tengah
	Vector2(7801.6, 3718.4),  # 4: kanan atas
	Vector2(8352.0, 5523.2),  # 5: kanan (ujung)
	Vector2(6099.2, 5664.0),  # 6: kanan bawah
	Vector2(3795.2, 6854.4),  # 7: bawah tengah
	Vector2(1977.6, 5792.0),  # 8: kiri bawah
]
# Backward compat: SPAWN_POS = spawn 1 (dipakai fallback).
const SPAWN_POS := Vector2(633.6, 3526.4)
const DUMMY_SPOT := Vector2(4060.0, 4100.0)
const DUMMY_PATROL_A := Vector2(3740.0, 4180.0)
const DUMMY_PATROL_B := Vector2(3900.0, 3940.0)
# Alias: slot MP sekarang = 8 titik resmi (bukan lingkaran sementara).
const TEMP_SPAWN_SLOTS: Array = SPAWN_POINTS
const TEMP_DUMMY_SPOTS: Array = [
	Vector2(4060.0, 4100.0),
	Vector2(3740.0, 4180.0),
	Vector2(3900.0, 3940.0),
]

## Kembalikan satu titik spawn acak dari 8 area resmi.
static func random_spawn() -> Vector2:
	return SPAWN_POINTS[randi() % SPAWN_POINTS.size()]
# NOTE: TIDAK ada marker runtime — angka 1-8 sudah digambar di texture map
# oleh user. Spawn memakai posisi angka tersebut.
