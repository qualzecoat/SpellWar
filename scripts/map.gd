extends Node2D
## Map Fase 1 (disederhanakan dari map-konsep-v1):
## ruang ekstraksi (tengah) + 1 koridor + 1 ruang puzzle.
## Lantai, dinding (dengan collision), mesin ekstraksi (placeholder),
## zona puzzle (Area2D -> sinyal untuk tombol interact).

signal puzzle_zone_changed(inside: bool)
signal exchange_zone_changed(inside: bool)

const WALL_T := 18.0
const FLOOR_COLOR := Color(0.13, 0.13, 0.18)
const WALL_COLOR := Color(0.38, 0.41, 0.52)

const ROOM_EXTRACTION := Rect2(700, 400, 600, 500)   # x 700-1300, y 400-900
const ROOM_CORRIDOR := Rect2(940, 100, 120, 300)     # x 940-1060, y 100-400
const ROOM_PUZZLE := Rect2(800, -300, 400, 400)      # x 800-1200, y -300-100

const MACHINE_POS := Vector2(1000, 650)
const PUZZLE_POS := Vector2(1000, -100)
const EXCHANGE_POS := Vector2(820, 780)


func _ready() -> void:
	_build_floors()
	_build_walls()
	_build_machine()
	_build_puzzle_spot()
	_build_exchange()


func _build_floors() -> void:
	for r in [ROOM_EXTRACTION, ROOM_CORRIDOR, ROOM_PUZZLE]:
		var p := Polygon2D.new()
		p.polygon = PackedVector2Array([
			r.position,
			r.position + Vector2(r.size.x, 0),
			r.position + r.size,
			r.position + Vector2(0, r.size.y),
		])
		p.color = FLOOR_COLOR
		add_child(p)


func _build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	add_child(walls)
	# Tiap segmen: [dari, ke]. Celah pintu di ujung koridor.
	var segs: Array = [
		# ruang ekstraksi
		[Vector2(700, 400), Vector2(940, 400)],
		[Vector2(1060, 400), Vector2(1300, 400)],
		[Vector2(700, 900), Vector2(1300, 900)],
		[Vector2(700, 400), Vector2(700, 900)],
		[Vector2(1300, 400), Vector2(1300, 900)],
		# koridor (ujung utara & selatan terbuka ke ruangan)
		[Vector2(940, 100), Vector2(940, 400)],
		[Vector2(1060, 100), Vector2(1060, 400)],
		# ruang puzzle
		[Vector2(800, 100), Vector2(940, 100)],
		[Vector2(1060, 100), Vector2(1200, 100)],
		[Vector2(800, -300), Vector2(1200, -300)],
		[Vector2(800, -300), Vector2(800, 100)],
		[Vector2(1200, -300), Vector2(1200, 100)],
	]
	for s in segs:
		_add_wall(walls, s[0], s[1])


func _add_wall(parent: Node, a: Vector2, b: Vector2) -> void:
	var mid := (a + b) * 0.5
	var length := a.distance_to(b)
	var vertical := absf(a.x - b.x) < 1.0
	var shape := RectangleShape2D.new()
	if vertical:
		shape.size = Vector2(WALL_T, length + WALL_T)
	else:
		shape.size = Vector2(length + WALL_T, WALL_T)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = mid
	parent.add_child(col)
	var line := Line2D.new()
	line.points = PackedVector2Array([a, b])
	line.width = WALL_T
	line.default_color = WALL_COLOR
	add_child(line)


func _build_machine() -> void:
	var body := StaticBody2D.new()
	body.name = "Machine"
	body.position = MACHINE_POS
	add_child(body)
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 42.0
	col.shape = circle
	body.add_child(col)
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/machine.svg")
	body.add_child(sprite)
	var label := Label.new()
	label.text = "MESIN EKSTRAKSI"
	label.position = Vector2(-70, 52)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.88, 0.64, 0.35))
	body.add_child(label)


func _build_puzzle_spot() -> void:
	var body := StaticBody2D.new()
	body.name = "PuzzleConsole"
	body.position = PUZZLE_POS
	add_child(body)
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(90, 70)
	col.shape = rect
	body.add_child(col)
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/puzzle.svg")
	body.add_child(sprite)

	var zone := Area2D.new()
	zone.name = "PuzzleZone"
	zone.position = PUZZLE_POS
	add_child(zone)
	var zcol := CollisionShape2D.new()
	var zrect := RectangleShape2D.new()
	zrect.size = Vector2(260, 220)
	zcol.shape = zrect
	zone.add_child(zcol)
	zone.body_entered.connect(_on_zone_body.bind(true))
	zone.body_exited.connect(_on_zone_body.bind(false))


func _on_zone_body(body: Node2D, inside: bool) -> void:
	if body.is_in_group("player"):
		puzzle_zone_changed.emit(inside)


## Mesin Tukar Huruf (Fase 1b): di ruang ekstraksi, pola interaksi sama
## seperti konsol puzzle (zona -> tombol ACTION/E).
func _build_exchange() -> void:
	var body := StaticBody2D.new()
	body.name = "ExchangeMachine"
	body.position = EXCHANGE_POS
	add_child(body)
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 42.0
	col.shape = circle
	body.add_child(col)
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/machine.svg")
	sprite.modulate = Color(0.55, 0.90, 1.0)
	body.add_child(sprite)
	var label := Label.new()
	label.text = "MESIN TUKAR HURUF"
	label.position = Vector2(-82, 52)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.55, 0.90, 1.0))
	body.add_child(label)

	var zone := Area2D.new()
	zone.name = "ExchangeZone"
	zone.position = EXCHANGE_POS
	add_child(zone)
	var zcol := CollisionShape2D.new()
	var zrect := RectangleShape2D.new()
	zrect.size = Vector2(260, 220)
	zcol.shape = zrect
	zone.add_child(zcol)
	zone.body_entered.connect(_on_exchange_zone_body.bind(true))
	zone.body_exited.connect(_on_exchange_zone_body.bind(false))


func _on_exchange_zone_body(body: Node2D, inside: bool) -> void:
	if body.is_in_group("player"):
		exchange_zone_changed.emit(inside)
