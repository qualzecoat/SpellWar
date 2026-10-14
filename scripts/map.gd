extends Node2D
## Map Fase 3b1: geometri dari desain user (trace petunjuk-area-map.png).
## 3b1 = LANTAI + DINDING SAJA. Tanpa mesin, tanpa spawn area, tanpa zona
## interaksi (itu 3b2-3b4).
## Data: scripts/map_data_gen.gd (hasil tools/trace_map.py). Jangan edit manual.

const FLOOR_COLOR := Color(0.13, 0.13, 0.18)
const WALL_COLOR := Color(0.38, 0.41, 0.52)

# --- 3b1 SEMENTARA ---
# Belum ada mesin (baru di 3b3/3b4). Sentinel di luar map agar validasi jarak
# interaksi selalu gagal dengan aman: tidak crash, tidak bisa dipakai.
const PUZZLE_POS := Vector2(-99999, -99999)
const EXCHANGE_POS := Vector2(-99999, -99999)
const MACHINE_POS := Vector2(-99999, -99999)
# Spawn sementara 3b1 (spawn resmi + random: 3b2).
const SPAWN_POS := Vector2(2003.2, 1747.2)  # == MapDataGen.TEMP_SPAWN
const DUMMY_SPOT := Vector2(2163.2, 1747.2)
const DUMMY_PATROL_A := Vector2(1843.2, 1827.2)
const DUMMY_PATROL_B := Vector2(2003.2, 1587.2)


func _ready() -> void:
	_build_background()
	_build_floors()
	_build_walls()


func _build_background() -> void:
	# Satu rect seukuran map dengan warna dinding; lantai digambar di atasnya.
	var bg := Polygon2D.new()
	bg.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(MapDataGen.MAP_W, 0),
		Vector2(MapDataGen.MAP_W, MapDataGen.MAP_H),
		Vector2(0, MapDataGen.MAP_H),
	])
	bg.color = WALL_COLOR
	add_child(bg)


func _build_floors() -> void:
	for r in MapDataGen.FLOOR_RECTS:
		var rr: Rect2 = r
		var p := Polygon2D.new()
		p.polygon = PackedVector2Array([
			rr.position,
			rr.position + Vector2(rr.size.x, 0),
			rr.position + rr.size,
			rr.position + Vector2(0, rr.size.y),
		])
		p.color = FLOOR_COLOR
		add_child(p)


func _build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	add_child(walls)
	for r in MapDataGen.WALL_RECTS:
		var rr: Rect2 = r
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rr.size
		col.shape = shape
		col.position = rr.position + rr.size * 0.5
		walls.add_child(col)
