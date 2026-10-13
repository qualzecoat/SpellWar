class_name RemotePlayerVisual
extends Node2D
## Visual pemain di mode multiplayer: sprite + nama + overhead bar HP/EP
## (dengan garis segmentasi yang sama: tiap 50 HP / 25 EP) + jejak SP.
## Digerakkan oleh snapshot server (smoothing, tanpa prediksi).

const BAR_W := 76.0

# Palet tint ringan agar pemain bisa dibedakan (sprite dasar merah).
const TINTS: Array = [
	Color(1.0, 1.0, 1.0), Color(0.65, 0.85, 1.0), Color(0.7, 1.0, 0.7),
	Color(1.0, 1.0, 0.55), Color(1.0, 0.75, 0.9), Color(0.85, 0.8, 1.0),
	Color(1.0, 0.85, 0.6), Color(0.7, 1.0, 0.95),
]

var pid := 0
var is_self := false
var target_pos := Vector2.ZERO
var facing := Vector2.RIGHT

var hp := 100
var max_hp := 100
var ep := 100
var max_ep := 100
var sp_stacks := 0
var alive := true
var prot := false
var is_dc := false

var _spr: Sprite2D
var _name_label: Label
var _trail: Array = []
var _blink_t := 0.0


func setup(p_name: String, p_pid: int, p_self: bool) -> void:
	pid = p_pid
	is_self = p_self
	_spr = Sprite2D.new()
	_spr.texture = load("res://assets/player.svg")
	_spr.modulate = TINTS[p_pid % TINTS.size()]
	add_child(_spr)
	_name_label = Label.new()
	_name_label.text = p_name
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_name_label.add_theme_constant_override("outline_size", 4)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(-60, -108)
	_name_label.size = Vector2(120, 22)
	add_child(_name_label)
	z_index = 1


func apply_snap(d: Dictionary) -> void:
	target_pos = Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
	facing = Vector2(float(d.get("fx", 1.0)), float(d.get("fy", 0.0)))
	hp = int(d.get("hp", 100))
	max_hp = int(d.get("max_hp", 100))
	ep = int(d.get("ep", 100))
	max_ep = int(d.get("max_ep", 100))
	sp_stacks = int(d.get("sp", 0))
	alive = bool(d.get("alive", true))
	prot = bool(d.get("prot", false))
	is_dc = bool(d.get("dc", false))
	visible = alive
	if not alive:
		_trail.clear()
	queue_redraw()


func _process(delta: float) -> void:
	# Smoothing menuju posisi snapshot.
	var k := 1.0 - exp(-12.0 * delta)
	position = position.lerp(target_pos, k)
	if _spr != null:
		_spr.flip_h = facing.x < 0.0
	# Kedip saat spawn protection / gray saat disconnect.
	if prot and alive:
		_blink_t += delta
		_spr.modulate.a = 0.35 + 0.65 * absf(sin(_blink_t * 14.0))
	elif is_dc:
		_spr.modulate.a = 0.45
	else:
		_spr.modulate.a = 1.0
	# Jejak SP: catat posisi saat buff aktif & bergerak.
	if sp_stacks > 0 and alive:
		if _trail.is_empty() or _trail[_trail.size() - 1]["p"].distance_to(position) > 26.0:
			_trail.append({"p": position, "age": 0.0})
			if _trail.size() > 10:
				_trail.remove_at(0)
	for i in range(_trail.size() - 1, -1, -1):
		_trail[i]["age"] = float(_trail[i]["age"]) + delta
		if float(_trail[i]["age"]) >= 0.35:
			_trail.remove_at(i)
	if not _trail.is_empty() or prot:
		queue_redraw()


func _draw() -> void:
	if not alive:
		return
	# Jejak SP di belakang sprite (digambar parent sebelum children).
	for t in _trail:
		var kk := 1.0 - float(t["age"]) / 0.35
		var col := Color(0.45, 0.85, 1.0, 0.4 * clampf(kk, 0.0, 1.0))
		var lp: Vector2 = to_local(t["p"])
		draw_circle(lp, 20.0, col)
	# Overhead bar HP/EP.
	var y0 := -84.0
	_draw_bar(y0, float(hp) / float(maxi(max_hp, 1)), Color(0.9, 0.28, 0.28),
		max_hp, 50.0)
	_draw_bar(y0 + 12.0, float(ep) / float(maxi(max_ep, 1)), Color(0.28, 0.58, 0.95),
		max_ep, 25.0)


func _draw_bar(y: float, frac: float, color: Color, maxv: int, step: float) -> void:
	var h := 8.0
	draw_rect(Rect2(-BAR_W / 2, y, BAR_W, h), Color(0, 0, 0, 0.6))
	var f := clampf(frac, 0.0, 1.0)
	if f > 0.0:
		draw_rect(Rect2(-BAR_W / 2 + 1, y + 1, (BAR_W - 2) * f, h - 2), color)
	# Garis segmentasi — sama seperti HUD: tiap `step` unit.
	var n := maxi(1, int(round(float(maxv) / step)))
	for i in range(1, n):
		var x := -BAR_W / 2 + BAR_W * float(i) / float(n)
		draw_line(Vector2(x, y - 2), Vector2(x, y + h + 2), Color(0, 0, 0, 0.75), 2.0)


## Visual ayunan pedang (paritas solo) — dipicu event "sword" dari server.
func play_swing() -> void:
	var arc := SwingArc.new()
	arc.facing_angle = facing.angle()
	add_child(arc)
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
