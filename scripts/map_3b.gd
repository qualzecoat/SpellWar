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

# --- 3b3: 16 mesin puzzle ---
# Posisi badan mesin (pillar hijau) dari deteksi piksel hijau di texture.
# 8 dekat spawn + 8 di tengah (sesuai desain user).
const PUZZLE_POS: Array = [
	Vector2(1313, 2906),  # 1
	Vector2(6077, 829),   # 2
	Vector2(5323, 6683),  # 3
	Vector2(2628, 4044),  # 4
	Vector2(5888, 2784),  # 5
	Vector2(3007, 2779),  # 6
	Vector2(7203, 4479),  # 7
	Vector2(2628, 4613),  # 8
	Vector2(5011, 4607),  # 9
	Vector2(2377, 6683),  # 10
	Vector2(3195, 708),   # 11
	Vector2(5510, 4605),  # 12
	Vector2(3505, 2780),  # 13
	Vector2(5890, 3344),  # 14
	Vector2(874, 2150),   # 15
	Vector2(7643, 5235),  # 16
]
# Area interaksi tiap mesin: kotak abu-abu 2 panah di BAWAH mesin (walkable).
# Rect2(position=top-left, size). Semua terverifikasi walkable di mask 3b3.
const PUZZLE_INTERACT: Array = [
	Rect2(1233, 2951, 160, 110),  # 1: (1313,3006)
	Rect2(5997, 874, 160, 110),   # 2: (6077,929)
	Rect2(5243, 6728, 160, 110),  # 3: (5323,6783)
	Rect2(2548, 4089, 160, 110),  # 4: (2628,4144)
	Rect2(5808, 2829, 160, 110),  # 5: (5888,2884)
	Rect2(2937, 2829, 140, 100),  # 6: (3007,2879) disesuaikan
	Rect2(7123, 4524, 160, 110),  # 7: (7203,4579)
	Rect2(2548, 4658, 160, 110),  # 8: (2628,4713)
	Rect2(4931, 4652, 160, 110),  # 9: (5011,4707)
	Rect2(2297, 6728, 160, 110),  # 10: (2377,6783)
	Rect2(3115, 753, 160, 110),   # 11: (3195,808)
	Rect2(5430, 4650, 160, 110),  # 12: (5510,4705)
	Rect2(3425, 2825, 160, 110),  # 13: (3505,2880)
	Rect2(5830, 3409, 120, 90),   # 14: (5890,3454) disesuaikan
	Rect2(794, 2195, 160, 110),   # 15: (874,2250)
	Rect2(7563, 5280, 160, 110),  # 16: (7643,5335)
]
# Sentinel untuk 3b4 (belum ada mesin tukar/ekstraksi).
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
