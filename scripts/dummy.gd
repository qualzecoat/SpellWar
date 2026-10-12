class_name SpellDummy
extends CharacterBody2D
## Boneka latihan (alat testing Fase 2, BUKAN musuh AI):
## punya HP, bisa ditembak/ditebas (angka damage muncul), mati -> hidup lagi.
## Varian patroli: mondar-mandir di antara dua titik (untuk ngetes trap).

const RESPAWN_DELAY := 5.0
const PATROL_SPEED := 90.0

var max_hp := 100
var hp := 100
var alive := true
var patrol := false
var patrol_a := Vector2.ZERO
var patrol_b := Vector2.ZERO

var _patrol_dir := 1.0
var _slow_time := 0.0
var _respawn_timer := 0.0
var _bar: ProgressBar = null
# FIX 2026-10-12 (Fix 5): knockback via velocity + move_and_slide agar
# menghormati collision (tidak tembus dinding/keluar map). Pola sama
# seperti player.gd; berlaku juga untuk pemain di Fase 3.
var _knockback := Vector2.ZERO
var _knock_time := 0.0


static func spawn(parent: Node, at: Vector2, patrol_to: Vector2 = Vector2.INF) -> SpellDummy:
	var d := SpellDummy.new()
	d.position = at
	if patrol_to != Vector2.INF:
		d.patrol = true
		d.patrol_a = at
		d.patrol_b = patrol_to
	parent.add_child(d)
	return d


func _ready() -> void:
	# Karakter: z=1 seperti Player agar trap/trail selalu di bawah kakinya.
	z_index = 1
	add_to_group("damageable")
	add_to_group("dummy")
	collision_layer = 1
	collision_mask = 1
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	col.shape = circle
	add_child(col)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(64, 10)
	_bar.position = Vector2(-32, -56)
	_bar.max_value = max_hp
	_bar.value = hp
	_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.35, 0.9, 0.4)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fg)
	add_child(_bar)
	set_physics_process(true)


func _draw() -> void:
	# Boneka: kapsul abu-abu dengan wajah "X".
	draw_circle(Vector2(0, -8), 24.0, Color(0.55, 0.58, 0.65))
	draw_circle(Vector2(0, 8), 24.0, Color(0.55, 0.58, 0.65))
	draw_rect(Rect2(-24, -8, 48, 16), Color(0.55, 0.58, 0.65))
	draw_line(Vector2(-10, -14), Vector2(10, 2), Color(0.2, 0.2, 0.25), 4.0)
	draw_line(Vector2(10, -14), Vector2(-10, 2), Color(0.2, 0.2, 0.25), 4.0)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	var vel := Vector2.ZERO
	if patrol:
		if _slow_time > 0.0:
			_slow_time -= delta
		var target := patrol_b if _patrol_dir > 0.0 else patrol_a
		var to: Vector2 = target - position
		if to.length() < 8.0:
			_patrol_dir *= -1.0
		else:
			var spd := PATROL_SPEED * (0.5 if _slow_time > 0.0 else 1.0)
			vel = to.normalized() * spd
	if _knock_time > 0.0:
		_knock_time -= delta
		vel += _knockback
	velocity = vel
	move_and_slide()


func take_damage(amount: int) -> void:
	if not alive:
		return
	hp = maxi(hp - amount, 0)
	_bar.value = hp
	_spawn_damage_number(amount)
	if hp <= 0:
		_die()


func apply_slow(duration: float) -> void:
	_slow_time = maxf(_slow_time, duration)


func apply_knockback(direction: Vector2, force: float, duration: float = 0.18) -> void:
	if not alive:
		return
	_knockback = direction.normalized() * force
	_knock_time = duration


func _die() -> void:
	alive = false
	visible = false
	set_physics_process(false)
	_respawn_timer = RESPAWN_DELAY
	set_process(true)


func _process(delta: float) -> void:
	if alive:
		return
	_respawn_timer -= delta
	if _respawn_timer <= 0.0:
		hp = max_hp
		_bar.value = hp
		alive = true
		visible = true
		_knockback = Vector2.ZERO
		_knock_time = 0.0
		set_physics_process(true)
		set_process(false)


func _spawn_damage_number(amount: int) -> void:
	var lbl := Label.new()
	lbl.text = "-%d" % amount
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.position = Vector2(-18, -76)
	lbl.z_index = 100
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 44.0, 0.8)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(lbl.queue_free)
