class_name SpellTrap
extends Area2D
## Jebakan TRAP: dipasang pemain, terpicu saat diinjak damageable LAIN
## (pemilik kebal). Efek: 30 damage + slow 50% selama 2 detik.
## Hilang setelah terpicu sekali. Maksimal 3 trap aktif bersamaan per pemain
## (bukan amunisi — trap meledak = slot kembali).
## Visibilitas: PEMILIK SELALU melihat penuh. (Aturan "non-pemilik hanya
## dalam radius kecil" berlaku per-viewer dan diimplementasikan saat
## multiplayer/Fase 3 — tiap client me-render pandangannya sendiri.)

const TRIGGER_DAMAGE := NetProto.TRAP_DAMAGE
const SLOW_DURATION := NetProto.TRAP_SLOW_DURATION
const MAX_CONCURRENT := NetProto.TRAP_MAX
## FIX 2026-10-13 (Fix 5): trap butuh 3 detik "arming" setelah dipasang —
## selama arming TIDAK bisa terpicu siapa pun (mencegah disalahgunakan
## sebagai serangan jarak dekat: pasang di kaki musuh -> langsung meledak).
const ARM_TIME := NetProto.TRAP_ARM_TIME

signal exploded(trap: SpellTrap)

var owner_node: Node2D = null
var armed := false

var _triggered := false
var _arm_left := ARM_TIME


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


func _process(delta: float) -> void:
	if armed:
		return
	_arm_left -= delta
	if _arm_left <= 0.0:
		armed = true
		modulate.a = 1.0
	else:
		# Visual arming: berkedip — sinyal "belum bisa meledak".
		var t := Time.get_ticks_msec() / 1000.0
		modulate.a = 0.45 + 0.35 * sin(t * 12.0)


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
	if not armed:
		return  # FIX 2026-10-13 (Fix 5): masa arming 3 dtk — belum bisa meledak.
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
	exploded.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)
