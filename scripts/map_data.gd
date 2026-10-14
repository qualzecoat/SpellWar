class_name MapData
extends RefCounted
## Logika walkability & containment map Fase 3b1.
## Data geometri: MapDataGen (hasil tools/trace_map.py, JANGAN edit manual).
## Dipakai client (visual spawn/containment) DAN server (spawn/pickup) —
## script shared: perubahan di sini WAJIB rebuild server.

static var _walk: PackedByteArray = PackedByteArray()
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	# Mask disimpan sebagai base64-text (assets/map_walk.b64) agar aman
	# di-push via push_files (tool teks). Isinya PNG grayscale 1 byte/px.
	var f := FileAccess.open("res://assets/map_walk.b64", FileAccess.READ)
	if f == null:
		push_error("MapData: gagal buka res://assets/map_walk.b64")
		return
	var img := Image.new()
	if img.load_png_from_buffer(Marshalls.base64_to_raw(f.get_as_text())) != OK \
			or img.is_empty():
		push_error("MapData: gagal decode mask walkability")
		return
	if img.get_format() != Image.FORMAT_L8:
		img.convert(Image.FORMAT_L8)
	_walk = img.get_data()


static func _cell_at(cx: int, cy: int) -> bool:
	if cx < 0 or cy < 0 or cx >= MapDataGen.GRID_W or cy >= MapDataGen.GRID_H:
		return false
	return _walk[cy * MapDataGen.GRID_W + cx] > 127


## Apakah titik (koordinat game px) berada di area walkable.
static func is_walkable(pos: Vector2) -> bool:
	_ensure_loaded()
	if _walk.is_empty():
		return true  # fallback: mask gagal load, jangan blokir game
	var cx := int(floor(pos.x / MapDataGen.CELL_PX))
	var cy := int(floor(pos.y / MapDataGen.CELL_PX))
	return _cell_at(cx, cy)


## Kembalikan titik walkable terdekat (pusat sel). Dipakai agar scatter
## huruf / efek tidak pernah mendarat di dalam tembok (keputusan user 3b1:
## merah = tembok absolut).
static func clamp_to_walkable(pos: Vector2, radius: float = 64.0) -> Vector2:
	_ensure_loaded()
	if is_walkable(pos):
		return pos
	var cx := int(floor(pos.x / MapDataGen.CELL_PX))
	var cy := int(floor(pos.y / MapDataGen.CELL_PX))
	var best := Vector2(-1, -1)
	var best_d := INF
	var rc := int(ceil(radius / MapDataGen.CELL_PX)) + 1
	for dy in range(-rc, rc + 1):
		for dx in range(-rc, rc + 1):
			if _cell_at(cx + dx, cy + dy):
				var c := Vector2((cx + dx + 0.5) * MapDataGen.CELL_PX,
						(cy + dy + 0.5) * MapDataGen.CELL_PX)
				var d := pos.distance_squared_to(c)
				if d < best_d:
					best_d = d
					best = c
	if best.x < 0.0:
		return MapDataGen.TEMP_SPAWN  # fallback, praktis tidak terjadi
	return best


## Titik walkable acak di cincin [min_d, max_d] sekitar center.
## Untuk scatter huruf: retry beberapa kali, fallback ke clamp.
static func random_walkable_near(center: Vector2, min_d: float, max_d: float,
		tries: int = 12) -> Vector2:
	_ensure_loaded()
	for i in tries:
		var ang := randf() * TAU
		var dist := randf_range(min_d, max_d)
		var p := center + Vector2(cos(ang), sin(ang)) * dist
		if is_walkable(p):
			return p
	return clamp_to_walkable(center)
