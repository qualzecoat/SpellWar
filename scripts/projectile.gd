class_name SpellProjectile
extends Area2D
## Proyektil pistol: terbang lurus ke arah hadap, damage 50 saat kena
## damageable (bukan penembak), hancur saat kena dinding / kehabisan jarak.

const SPEED := 700.0
const RANGE := 900.0
const DAMAGE := NetProto.PISTOL_DAMAGE

var direction := Vector2.RIGHT
var shooter: Node2D = null

var _traveled := 0.0


static func spawn(parent: Node, from: Vector2, dir: Vector2, by: Node2D) -> void:
	var p := SpellProjectile.new()
	p.direction = dir.normalized()
	p.shooter = by
	p.position = from + p.direction * 40.0
	p.rotation = p.direction.angle()
	parent.add_child(p)


func _ready() -> void:
	# Proyektil tetap di atas karakter (z=2), seperti sebelum Player naik ke z=1.
	z_index = 2
	add_to_group("projectile")
	collision_layer = 0
	collision_mask = 1  # dinding (StaticBody2D) & damageable di layer 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	# Visual: peluru kuning kecil + trail.
	var dot := Polygon2D.new()
	dot.polygon = PackedVector2Array([
		Vector2(14, 0), Vector2(-10, 7), Vector2(-10, -7),
	])
	dot.color = Color(1.0, 0.85, 0.25)
	add_child(dot)


func _physics_process(delta: float) -> void:
	var step := SPEED * delta
	position += direction * step
	_traveled += step
	if _traveled >= RANGE:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body == shooter:
		return
	if body.is_in_group("damageable") and body.has_method("take_damage"):
		body.take_damage(DAMAGE)
		_spawn_hit_fx()
		queue_free()
	elif body is StaticBody2D:
		_spawn_hit_fx()
		queue_free()


func _spawn_hit_fx() -> void:
	# Efek tabrakan sederhana: kilatan yang memudar.
	var fx := Node2D.new()
	fx.position = position
	get_parent().add_child(fx)
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(16, 0), Vector2(0, 16), Vector2(-16, 0), Vector2(0, -16),
	])
	poly.color = Color(1.0, 0.9, 0.4, 0.8)
	fx.add_child(poly)
	var tw := fx.create_tween()
	tw.tween_property(poly, "modulate:a", 0.0, 0.2)
	tw.tween_callback(fx.queue_free)
