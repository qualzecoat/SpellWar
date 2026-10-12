class_name SpellPickup
extends Area2D
## Huruf yang jatuh saat pemain mati: melayang di lokasi, bisa dipungut
## dengan berjalan melewatinya (masuk ke inventory).

var letter := "A"

var _t := 0.0
var _base_y := 0.0
var _taken := false


static func drop(parent: Node, at: Vector2, letter_value: String) -> SpellPickup:
	var p := SpellPickup.new()
	p.letter = letter_value
	p.position = at
	parent.add_child(p)
	return p


func _ready() -> void:
	add_to_group("pickup")
	collision_layer = 0
	collision_mask = 1  # deteksi badan pemain (CharacterBody2D, layer 1)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	add_child(shape)
	_base_y = position.y
	var lbl := Label.new()
	lbl.text = letter
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.15, 0.10, 0.02))
	lbl.position = Vector2(-8, -16)
	add_child(lbl)
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	# Tile huruf kecil keemasan.
	draw_rect(Rect2(-16, -16, 32, 32), Color(0.85, 0.70, 0.25))
	draw_rect(Rect2(-16, -16, 32, 32), Color(0.45, 0.32, 0.08), false, 3.0)


func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * 3.0) * 5.0
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _taken:
		return
	if not body.is_in_group("player"):
		return
	_taken = true
	var game := _find_game()
	if game != null and game.has_method("collect_pickup"):
		game.collect_pickup(letter)
	queue_free()


func _find_game() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.current_scene
