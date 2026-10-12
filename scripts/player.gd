extends CharacterBody2D
## Pemain placeholder Fase 0.
## Gerak 8 arah ala Among Us: kecepatan konstan, tanpa akselerasi/gesekan.
## Karakter tidak memutar badan, hanya flip horizontal (kiri-kanan).

const SPEED := 220.0


func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * SPEED
	move_and_slide()
	if dir.x != 0.0:
		$Sprite2D.flip_h = dir.x < 0.0
