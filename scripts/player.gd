extends CharacterBody2D
## Pemain Fase 2: gerak 8 arah ala Among Us, HP/EP + regen EP,
## damage/kematian, efek slow, speed multiplier (kata SP),
## knockback (dorong), ayunan pedang.

const BASE_SPEED := 220.0
const BASE_MAX_HP := 100
const BASE_MAX_EP := 100
const BASE_EP_REGEN := 5.0

var hp := BASE_MAX_HP
var max_hp := BASE_MAX_HP
var ep := BASE_MAX_EP
var max_ep := BASE_MAX_EP
var ep_regen := BASE_EP_REGEN
var speed_mult := 1.0

var facing := Vector2.RIGHT
var input_enabled := true
var alive := true
var joystick = null  # di-set oleh game.gd; punya properti `output` (untyped)

var _slow_time := 0.0
var _knockback := Vector2.ZERO
var _knock_time := 0.0
var _ep_frac := 0.0  # FIX 2026-10-12 (Fix 2): akumulator fraksi regen EP
var _trail_timer := 0.0

signal hp_changed(hp: int, max_hp: int)
signal ep_changed(ep: int, max_ep: int)
signal died


func _ready() -> void:
	add_to_group("player")
	add_to_group("damageable")


func _process(delta: float) -> void:
	if not alive:
		return
	# Regen EP selalu jalan (di luar combat sekalipun).
	# FIX 2026-10-12 (Fix 2): pakai akumulator float — int(ep + regen*delta)
	# memotong fraksi tiap frame sehingga EP tidak pernah naik.
	if ep < max_ep:
		_ep_frac += ep_regen * delta
		var gain := int(_ep_frac)
		if gain > 0:
			_ep_frac -= gain
			ep = mini(ep + gain, max_ep)
			ep_changed.emit(ep, max_ep)
	else:
		_ep_frac = 0.0
	if _slow_time > 0.0:
		_slow_time -= delta


func _physics_process(_delta: float) -> void:
	if not input_enabled or not alive:
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
	var spd := BASE_SPEED * speed_mult
	if _slow_time > 0.0:
		spd *= 0.5
	velocity = dir * spd
	if _knock_time > 0.0:
		_knock_time -= _delta
		velocity += _knockback
	move_and_slide()
	if dir.length() > 0.1:
		facing = _snap4(dir)
	if dir.x != 0.0:
		$Sprite2D.flip_h = dir.x < 0.0
	# FIX 2026-10-12 (Fix 4): jejak gerak agar buff SP terasa secara visual.
	if speed_mult > 1.0 and dir.length() > 0.1:
		_trail_timer -= _delta
		if _trail_timer <= 0.0:
			_trail_timer = 0.09
			_spawn_trail_ghost()
	else:
		_trail_timer = 0.0


## Ghost kapsul memudar di posisi terakhir — efek "ngebut" saat buff SP aktif.
func _spawn_trail_ghost() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var g := TrailGhost.new()
	parent.add_child(g)
	g.global_position = global_position


class TrailGhost extends Node2D:
	var life := 0.35
	const MAX_LIFE := 0.35

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var a := clampf(life / MAX_LIFE, 0.0, 1.0) * 0.45
		var col := Color(0.45, 0.85, 1.0, a)
		draw_circle(Vector2(0, -8), 24.0, col)
		draw_circle(Vector2(0, 8), 24.0, col)
		draw_rect(Rect2(-24, -8, 48, 16), col)


func _snap4(v: Vector2) -> Vector2:
	if absf(v.x) >= absf(v.y):
		return Vector2(signf(v.x), 0.0)
	return Vector2(0.0, signf(v.y))


# ---------- HP ----------

func heal(amount: int) -> void:
	if not alive:
		return
	hp = mini(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)


func set_max_hp(value: int) -> void:
	max_hp = maxi(value, 1)
	hp = mini(hp, max_hp)
	hp_changed.emit(hp, max_hp)


func take_damage(amount: int) -> void:
	if not alive:
		return
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		alive = false
		died.emit()


func apply_slow(duration: float) -> void:
	_slow_time = maxf(_slow_time, duration)


func apply_knockback(direction: Vector2, force: float, duration: float = 0.18) -> void:
	_knockback = direction.normalized() * force
	_knock_time = duration


# ---------- EP ----------

func set_max_ep(value: int) -> void:
	max_ep = maxi(value, 1)
	ep = mini(ep, max_ep)
	ep_changed.emit(ep, max_ep)


func add_ep_regen(amount: float) -> void:
	ep_regen = maxf(ep_regen + amount, 0.0)


## Coba pakai EP. Return false jika tidak cukup (tidak dikurangi).
func spend_ep(cost: int) -> bool:
	if ep < cost:
		return false
	ep -= cost
	ep_changed.emit(ep, max_ep)
	return true


func restore_full() -> void:
	hp = max_hp
	ep = max_ep
	hp_changed.emit(hp, max_hp)
	ep_changed.emit(ep, max_ep)


func respawn_at(pos: Vector2) -> void:
	position = pos
	alive = true
	_slow_time = 0.0
	_knock_time = 0.0
	velocity = Vector2.ZERO
	restore_full()
	visible = true
	input_enabled = true


## Ayunan pedang: busur visual ke arah hadap selama 0.25 detik.
## Damage dihitung oleh game.gd (area busur).
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
