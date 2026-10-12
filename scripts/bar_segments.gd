class_name BarSegments
extends Control
## Overlay garis segmentasi di atas ProgressBar: garis vertikal tipis tiap
## `step` unit dari max saat ini (mis. HP tiap 50, EP tiap 25) — sehingga
## saat stack spell word, "penebalan" bar terasa (segmen bertambah).
## FIX 2026-10-13 (Fix 6).

var step := 50.0
var max_value := 100.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func set_params(p_step: float, p_max: float) -> void:
	step = p_step
	max_value = p_max
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if max_value <= 0.0 or step <= 0.0 or size.x <= 0.0:
		return
	var k := 1
	while k * step < max_value - 0.001:
		var x := size.x * (k * step / max_value)
		draw_line(Vector2(x, 1.0), Vector2(x, size.y - 1.0),
			Color(0, 0, 0, 0.6), 2.0)
		k += 1
