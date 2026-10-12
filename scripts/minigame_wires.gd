extends Control
## Panel minigame sambung kabel. Emit finished(true) saat semua kabel benar.

signal finished(success: bool)

var _board: Control
var _status: Label
var _busy := false


func _ready() -> void:
	_build()
	visible = false


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 600)
	var pbg := StyleBoxFlat.new()
	pbg.bg_color = Color(0.14, 0.15, 0.20)
	pbg.set_corner_radius_all(12)
	pbg.border_color = Color(0.4, 0.45, 0.6)
	pbg.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", pbg)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "SAMBUNG KABEL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Tarik tiap kabel kiri ke terminal kanan yang warnanya sama."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	vbox.add_child(sub)

	_board = preload("res://scripts/wires_board.gd").new()
	_board.custom_minimum_size = Vector2(700, 372)
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.puzzle_done.connect(_on_puzzle_done)
	vbox.add_child(_board)

	var row := HBoxContainer.new()
	vbox.add_child(row)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.add_theme_font_size_override("font_size", 20)
	row.add_child(_status)
	var close := Button.new()
	close.text = "Tutup"
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(func() -> void: _close(false))
	row.add_child(close)


func start_puzzle() -> void:
	_busy = false
	_status.text = ""
	_board.start()
	visible = true


func _on_puzzle_done() -> void:
	if _busy:
		return
	_busy = true
	_status.text = "BERHASIL! +5 huruf"
	_status.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_callback(func() -> void: _close(true))


func _close(success: bool) -> void:
	visible = false
	finished.emit(success)
