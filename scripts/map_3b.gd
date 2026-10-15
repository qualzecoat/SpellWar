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
# 2026-10-16: dipindah ke ruang tengah map baru user (titik lama ketiban tembok).
# 2026-10-16 (pm): digeser ke (3900,4100) — titik lama ketiban wall mesin
# ekstraksi 240x240 di (4262,3774).
const SPAWN_POS := Vector2(3900.0, 4100.0)
const DUMMY_SPOT := Vector2(4060.0, 4100.0)
const DUMMY_PATROL_A := Vector2(3740.0, 4180.0)
const DUMMY_PATROL_B := Vector2(3900.0, 3940.0)
# Slot spawn sementara MP 3b1 (8 offset di sekitar titik tengah sementara).
const TEMP_SPAWN_SLOTS: Array = [
	Vector2(3996.0, 4100.0),
	Vector2(3967.9, 4167.9),
	Vector2(3900.0, 4196.0),
	Vector2(3832.1, 4167.9),
	Vector2(3804.0, 4100.0),
	Vector2(3832.1, 4032.1),
	Vector2(3900.0, 4004.0),
	Vector2(3967.9, 4032.1),
]
const TEMP_DUMMY_SPOTS: Array = [
	Vector2(4060.0, 4100.0),
	Vector2(3740.0, 4180.0),
	Vector2(3900.0, 3940.0),
]
