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
# Spawn sementara 3b1 (spawn resmi + random: 3b2).
const SPAWN_POS := Vector2(2003.2, 1747.2)
const DUMMY_SPOT := Vector2(2163.2, 1747.2)
const DUMMY_PATROL_A := Vector2(1843.2, 1827.2)
const DUMMY_PATROL_B := Vector2(2003.2, 1587.2)
# Slot spawn sementara MP 3b1 (8 offset di sekitar titik tengah sementara).
const TEMP_SPAWN_SLOTS: Array = [
	Vector2(2214.4, 1849.6),
	Vector2(2186.3, 1917.5),
	Vector2(2118.4, 1945.6),
	Vector2(2050.5, 1917.5),
	Vector2(2022.4, 1849.6),
	Vector2(2050.5, 1781.7),
	Vector2(2118.4, 1753.6),
	Vector2(2186.3, 1781.7),
]
const TEMP_DUMMY_SPOTS: Array = [
	Vector2(2278.4, 1849.6),
	Vector2(1958.4, 1929.6),
	Vector2(2118.4, 1689.6),
]
