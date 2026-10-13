class_name TouchKeyboard
extends Control
## Keyboard virtual di dalam game untuk perangkat touchscreen.
## Alasan: keyboard OS (mis. Gboard) tidak bisa mengetik ke LineEdit pada
## web export Godot (bug engine: godotengine/godot#99602) — tidak ada fix
## via project setting yang kredibel, jadi solusinya keyboard buatan sendiri.
## Dipakai dari menu.gd: tap pada field (touchscreen) -> open_for(field,...).
## Keyboard fisik tetap didukung via _unhandled_key_input saat terbuka
## (berguna untuk laptop touchscreen).

signal closed

const KEY_H := 54.0
const PER_ROW := 8

var _target: LineEdit = null
var _charset := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
var _panel: PanelContainer
var _title_l: Label
var _preview_l: Label
var _rows_box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Latar redup: tap di luar panel = tutup.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	dim.gui_input.connect(_on_dim_input)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -360.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.17)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_panel.add_child(vb)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vb.add_child(header)
	_title_l = Label.new()
	_title_l.add_theme_font_size_override("font_size", 20)
	_title_l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_l)
	_preview_l = Label.new()
	_preview_l.add_theme_font_size_override("font_size", 20)
	_preview_l.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	_preview_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_preview_l)
	var close_b := Button.new()
	close_b.text = "✕"
	close_b.custom_minimum_size = Vector2(52, 40)
	close_b.add_theme_font_size_override("font_size", 20)
	close_b.pressed.connect(close)
	header.add_child(close_b)

	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 6)
	vb.add_child(_rows_box)


func _on_dim_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close()


func open_for(field: LineEdit, title: String, charset: String) -> void:
	_target = field
	_charset = charset
	_title_l.text = title
	_rebuild_keys()
	_update_preview()
	visible = true


func close() -> void:
	visible = false
	_target = null
	closed.emit()


func is_open() -> bool:
	return visible


func _rebuild_keys() -> void:
	for c in _rows_box.get_children():
		c.queue_free()
	var i := 0
	var rows := 0
	while i < _charset.length():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_rows_box.add_child(row)
		for j in range(PER_ROW):
			if i < _charset.length():
				var ch := _charset.substr(i, 1)
				row.add_child(_make_key(ch, _press.bind(ch)))
				i += 1
			else:
				# Pengisi agar ukuran tombol seragam di baris terakhir.
				var sp := Control.new()
				sp.custom_minimum_size = Vector2(40, KEY_H)
				sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(sp)
		rows += 1
	# Baris bawah: backspace + OK.
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	_rows_box.add_child(bottom)
	var bs := _make_key("⌫", _backspace)
	bottom.add_child(bs)
	var ok := _make_key("OK", close)
	ok.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	bottom.add_child(ok)
	# Sesuaikan tinggi panel dengan jumlah baris.
	_panel.offset_top = -(118.0 + float(rows + 1) * (KEY_H + 6.0))


func _make_key(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(40, KEY_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	return b


func _press(ch: String) -> void:
	if _target == null:
		return
	if _target.max_length > 0 and _target.text.length() >= _target.max_length:
		return
	_target.text += ch
	_update_preview()


func _backspace() -> void:
	if _target == null:
		return
	var t := _target.text
	if t.length() > 0:
		_target.text = t.substr(0, t.length() - 1)
	_update_preview()


func _update_preview() -> void:
	_preview_l.text = _target.text if _target != null else ""


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or _target == null:
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.is_echo():
		return
	if k.keycode == KEY_BACKSPACE:
		_backspace()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	else:
		var ch := String.chr(k.unicode).to_upper()
		if ch.length() == 1 and _charset.contains(ch):
			_press(ch)
			get_viewport().set_input_as_handled()
