extends CharacterBody2D
## Pemain: gerak 8 arah ala Among Us (kecepatan konstan, tanpa akselerasi),
## karakter tidak memutar badan (hanya flip kiri-kanan). HP/EP + ayunan pedang.

const SPEED := 220.0

var hp := 100
var max_hp := 100
var ep := 100
var max_ep := 100

var facing := Vector2.RIGHT
var input_enabled := true
var joystick = null  # di-set oleh game.gd; punya properti `output` (untyped, lihat game.gd)

signal hp_changed(hp: int, max_hp: int)
signal ep_changed(ep: int, max_ep: int)


func _ready() -> void:
	add_to_group("player")


func _physics_process(_delta: float) -> void:
	if not input_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if joystick != null:
		var joy: Vector2 = joystick.output
		if joy.length() > 0.05:
			if dir.length() < 0.05:
				dir = joy
			else:
				dir = (dir + joy).limit_length(1.0)
	velocity = dir * SPEED
	move_and_slide()
	if dir.length() > 0.1:
		facing = _snap4(dir)
	if dir.x != 0.0:
		$Sprite2D.flip_h = dir.x < 0.0


func _snap4(v: Vector2) -> Vector2:
	if absf(v.x) >= absf(v.y):
		return Vector2(signf(v.x), 0.0)
	return Vector2(0.0, signf(v.y))


func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)


func set_max_hp(value: int) -> void:
	max_hp = maxi(value, 1)
	hp = mini(hp, max_hp)
	hp_changed.emit(hp, max_hp)


## Ayunan pedang: busur visual ke arah hadap selama 0.25 detik.
func swing_sword() -> void:
	var arc := SwingArc.new()
	arc.facing_angle = facing.angle()
	$SwingPivot.add_child(arc)
	var tw := create_tween()
	tw.tween_property(arc, "modulate:a", 0.0, 0.25)
	tw.tween_callback(arc.queue_free)


class SwingArc extends Node2D:
	var facing_angle := 0.0
	var radius := 78.0

	func _draw() -> void:
		var pts := PackedVector2Array()
		pts.append(Vector2.ZERO)
		var spread := 1.0
		for i in range(17):
			var a := facing_angle - spread + i * (spread * 2.0 / 16.0)
			pts.append(Vector2(cos(a), sin(a)) * radius)
		draw_colored_polygon(pts, Color(1.0, 1.0, 1.0, 0.55))
		draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.9), 4.0)
