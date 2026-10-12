class_name SpellTrap
extends Area2D
## Jebakan TRAP: dipasang pemain, terpicu saat diinjak damageable LAIN
## (pemilik kebal). Efek: 30 damage + slow 50% selama 2 detik.
## Hilang setelah terpicu sekali. Visibilitas: pemilik selalu melihat penuh;
## non-pemilik hanya melihat samar dalam radius kecil (150 px).

const TRIGGER_DAMAGE := 30
const SLOW_DURATION := 2.0
const SPOT_RADIUS := 150.0

var owner_node: Node2D = null

var _triggered := false
var _last_bucket := -1


static func place(parent: Node, at: Vector2, owner: Node2D) -> SpellTrap:
	var t := SpellTrap.new()
	t.owner_node = owner
	t.position = at
	parent.add_child(t)
	return t


func _ready() -> void:
	add_to_group("trap")
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 34.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	# Placeholder: lingkaran merah bergigi (seperti ranjau).
	var teeth := 12
	for i in teeth:
		var a := TAU * i / teeth
		var dir := Vector2(cos(a), sin(a))
		draw_line(dir * 22.0, dir * 34.0, Color(0.95, 0.25, 0.2), 6.0)
	draw_circle(Vector2.ZERO, 22.0, Color(0.45, 0.10, 0.10))
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, Color(0.95, 0.35, 0.3), 3.0)


func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if body == owner_node:
		return
	if not body.is_in_group("damageable"):
		return
	if not body.has_method("take_damage"):
		return
	_triggered = true
	body.take_damage(TRIGGER_DAMAGE)
	if body.has_method("apply_slow"):
		body.apply_slow(SLOW_DURATION)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


func _process(_delta: float) -> void:
	# Visibilitas untuk non-pemilik: samar hanya dalam radius kecil.
	# (Fase 2 solo: pemilik = pemain, selalu terlihat penuh.)
	var nearest := _nearest_foe_dist()
	var alpha := 1.0
	if nearest >= 0.0:
		alpha = 0.45 if nearest <= SPOT_RADIUS else 0.0
	var bucket := int(alpha * 10.0)
	if bucket != _last_bucket:
		_last_bucket = bucket
		modulate.a = alpha
		queue_redraw()


func _nearest_foe_dist() -> float:
	var best := -1.0
	var tree := get_tree()
	if tree == null:
		return best
	for n in tree.get_nodes_in_group("damageable"):
		var nd := n as Node2D
		if nd == null or nd == owner_node:
			continue
		var alive_prop = nd.get("alive")
		if alive_prop != null and not bool(alive_prop):
			continue
		var d := global_position.distance_to(nd.global_position)
		if best < 0.0 or d < best:
			best = d
	return best
