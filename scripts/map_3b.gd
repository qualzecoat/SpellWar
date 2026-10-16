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
# 3b2: 8 area spawn resmi (angka 1-8 di map user). Player random spawn di
# salah satu dari 8 titik ini. Semua terverifikasi walkable, jarak min 806px.
const SPAWN_POINTS: Array = [
	Vector2(1785.6, 1836.8),  # 1: kiri atas
	Vector2(1132.8, 3347.2),  # 2: kiri bawah
	Vector2(3398.4, 2796.8),  # 3: tengah kiri-atas
	Vector2(3398.4, 3603.2),  # 4: tengah kiri-bawah
	Vector2(4806.4, 2502.4),  # 5: tengah kanan-atas
	Vector2(6406.4, 2988.8),  # 6: kanan atas
	Vector2(6496.0, 4512.0),  # 7: kanan bawah
	Vector2(4806.4, 3603.2),  # 8: tengah kanan-bawah
]
# Backward compat: SPAWN_POS = spawn 1 (dipakai fallback).
const SPAWN_POS := Vector2(1785.6, 1836.8)
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

# 3b2: gambar marker angka 1-8 di tiap area spawn (visual saja, walkable).
func _ready() -> void:
	for i in SPAWN_POINTS.size():
		var pos: Vector2 = SPAWN_POINTS[i]
		# Lingkaran background.
		var bg := Polygon2D.new()
		var pts := PackedVector2Array()
		for a in range(24):
			var t := TAU * a / 24.0
			pts.append(Vector2(cos(t), sin(t)) * 36.0)
		bg.polygon = pts
		bg.color = Color(1.0, 0.35, 0.55, 0.35)
		bg.position = pos
		add_child(bg)
		# Angka.
		var label := Label.new()
		label.text = str(i + 1)
		label.add_theme_font_size_override("font_size", 40)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		label.position = pos + Vector2(-13, -28)
		add_child(label)
