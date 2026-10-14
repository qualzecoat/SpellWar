extends SceneTree
## Uji logika map Fase 3b1 (trace dari desain user) secara headless.
## Jalankan: godot --headless --path <project> -s res://tests/test_map.gd
## Exit code = jumlah kegagalan (0 = semua lolos).

var _passed := 0
var _failed := 0


func _check(ok: bool, name: String) -> void:
	if ok:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		printerr("FAIL: " + name)


func _init() -> void:
	# --- mask termuat ---
	MapData._ensure_loaded()
	_check(not MapData._walk.is_empty(), "mask walkability termuat")
	_check(MapData._walk.size() == MapDataGen.GRID_W * MapDataGen.GRID_H,
		"ukuran mask = GRID_W x GRID_H")

	# --- spot check walkable / wall ---
	_check(MapData.is_walkable(MapDataGen.TEMP_SPAWN), "TEMP_SPAWN walkable")
	_check(not MapData.is_walkable(Vector2(-100, -100)),
		"luar bounds tidak walkable")
	# Titik tengah blok tembok interior (dari trace): harus wall.
	_check(not MapData.is_walkable(Vector2(1747.8, 1470.7)),
		"interior tembok tidak walkable")
	var slots_ok := true
	for s in NetProto.SPAWN_SLOTS:
		if not MapData.is_walkable(s):
			slots_ok = false
			break
	_check(slots_ok, "semua slot MP walkable")

	# --- konektivitas: flood fill dari TEMP_SPAWN harus 100% ---
	var gw: int = MapDataGen.GRID_W
	var gh: int = MapDataGen.GRID_H
	var total := 0
	for i in MapData._walk.size():
		if MapData._walk[i] > 127:
			total += 1
	var scx := int(MapDataGen.TEMP_SPAWN.x / MapDataGen.CELL_PX)
	var scy := int(MapDataGen.TEMP_SPAWN.y / MapDataGen.CELL_PX)
	var seen := PackedByteArray()
	seen.resize(gw * gh)
	var queue: Array = [[scx, scy]]
	var reached := 0
	while not queue.is_empty():
		var c: Array = queue.pop_back()
		var x: int = c[0]
		var y: int = c[1]
		if x < 0 or y < 0 or x >= gw or y >= gh:
			continue
		var idx := y * gw + x
		if seen[idx] == 1 or MapData._walk[idx] <= 127:
			continue
		seen[idx] = 1
		reached += 1
		queue.append([x + 1, y])
		queue.append([x - 1, y])
		queue.append([x, y + 1])
		queue.append([x, y - 1])
	_check(reached == total,
		"flood fill 100%% reachable (%d/%d)" % [reached, total])

	# --- containment: scatter tidak pernah di dalam tembok ---
	var bad := 0
	var centers := [MapDataGen.TEMP_SPAWN, Vector2(1747.8, 1470.7),
		Vector2(0, 0), Vector2(4000, 3000)]
	for center in centers:
		for i in 60:
			var p := MapData.random_walkable_near(center, 90.0, 150.0)
			if not MapData.is_walkable(p):
				bad += 1
	_check(bad == 0, "scatter containment: 240 sampel selalu walkable")
	# clamp dari dalam tembok -> walkable
	var cl := MapData.clamp_to_walkable(Vector2(1747.8, 1470.7))
	_check(MapData.is_walkable(cl), "clamp_to_walkable dari tembok -> walkable")

	# --- determinisme trace: jumlah rect hasil merge ---
	_check(MapDataGen.WALL_RECTS.size() == 254, "wall rects = 254 (trace)")
	_check(MapDataGen.FLOOR_RECTS.size() == 268, "floor rects = 268 (trace)")

	print("map: %d lolos, %d gagal" % [_passed, _failed])
	quit(_failed)
