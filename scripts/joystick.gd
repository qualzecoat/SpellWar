extends Control
## Virtual joystick kiri-bawah. Hanya menangani mouse events — sentuhan
## di-emulate menjadi mouse (input_devices/pointing/emulate_mouse_from_touch).

const RADIUS := 80.0

var output := Vector2.ZERO

var _dragging := false
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_dragging = true
			_update_knob(_mouse_local())
			accept_event()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		_update_knob(_mouse_local())
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_release()


func _mouse_local() -> Vector2:
	return get_global_mouse_position() - global_position


func _update_knob(local: Vector2) -> void:
	var center := size * 0.5
	var off := local - center
	if off.length() > RADIUS:
		off = off.normalized() * RADIUS
	_knob = off
	output = off / RADIUS
	queue_redraw()


func _release() -> void:
	_dragging = false
	_knob = Vector2.ZERO
	output = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, RADIUS, Color(1, 1, 1, 0.10))
	draw_arc(center, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
	draw_circle(center + _knob, 34.0, Color(1, 1, 1, 0.35))
