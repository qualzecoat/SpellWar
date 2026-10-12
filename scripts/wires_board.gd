extends Control
## Papan minigame "sambung kabel" ala Among Us.
## Kiri: 4 kabel (urutan tetap). Kanan: 4 terminal (urutan diacak).
## Tarik kabel kiri ke terminal kanan yang warnanya sama.

signal puzzle_done

const PORT_R := 22.0
const HIT_R := 40.0

const COLORS: Array = [
	Color(0.95, 0.28, 0.28),  # merah
	Color(0.30, 0.58, 0.96),  # biru
	Color(0.96, 0.82, 0.28),  # kuning
	Color(0.30, 0.80, 0.48),  # hijau
]

var _right_order: Array = [0, 1, 2, 3]  # warna per slot kanan (diacak)
var _connected_left: Array = [false, false, false, false]
var _connected_right: Array = [false, false, false, false]
var _dragging := -1  # index kabel kiri yang ditarik


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func start() -> void:
	_right_order = [0, 1, 2, 3]
	_right_order.shuffle()
	_connected_left = [false, false, false, false]
	_connected_right = [false, false, false, false]
	_dragging = -1
	queue_redraw()


func _left_pos(i: int) -> Vector2:
	return Vector2(80, 55 + i * 84)


func _right_pos(slot: int) -> Vector2:
	return Vector2(size.x - 80, 55 + slot * 84)


func _mouse_local() -> Vector2:
	return get_global_mouse_position() - global_position


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var mp := _mouse_local()
			for i in 4:
				if not _connected_left[i] and mp.distance_to(_left_pos(i)) < HIT_R:
					_dragging = i
					accept_event()
					break


func _input(event: InputEvent) -> void:
	if _dragging < 0:
		return
	if event is InputEventMouseMotion:
		queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_try_connect()
			_dragging = -1
			queue_redraw()


func _try_connect() -> void:
	var mp := _mouse_local()
	for slot in 4:
		if _connected_right[slot]:
			continue
		if mp.distance_to(_right_pos(slot)) < HIT_R:
			if _right_order[slot] == _dragging:
				_connected_left[_dragging] = true
				_connected_right[slot] = true
				if _connected_left.all(func(b: bool) -> bool: return b):
					puzzle_done.emit()
			return


func _draw() -> void:
	# garis kabel yang sudah tersambung
	for i in 4:
		if _connected_left[i]:
			var slot := _right_order.find(i)
			draw_line(_left_pos(i), _right_pos(slot), COLORS[i], 10.0)
	# kabel kiri (port + sisa kabel)
	for i in 4:
		var p := _left_pos(i)
		if not _connected_left[i]:
			draw_line(p, p + Vector2(46, 0), COLORS[i], 10.0)
		draw_circle(p, PORT_R, COLORS[i])
		draw_arc(p, PORT_R, 0.0, TAU, 32, Color(0, 0, 0, 0.45), 3.0)
	# terminal kanan
	for slot in 4:
		var p := _right_pos(slot)
		var ci: int = _right_order[slot]
		draw_line(p - Vector2(46, 0), p, Color(0.25, 0.25, 0.30), 14.0)
		draw_circle(p, PORT_R, COLORS[ci] if not _connected_right[slot] else Color(0.45, 0.45, 0.50))
		draw_arc(p, PORT_R, 0.0, TAU, 32, Color(1, 1, 1, 0.7), 3.0)
	# kabel yang sedang ditarik
	if _dragging >= 0:
		draw_line(_left_pos(_dragging), _mouse_local(), COLORS[_dragging], 10.0)
