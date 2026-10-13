class_name TouchKeyboard
extends Control
## Keyboard virtual di dalam game untuk perangkat touchscreen.
## Alasan: keyboard OS (mis. Gboard) tidak bisa mengetik ke LineEdit pada
## web export Godot (bug engine: godotengine/godot#99602) — tidak ada fix
## via project setting yang kredibel, jadi solusinya keyboard buatan sendiri.
## Dipakai dari menu.gd: tap pada field (touchscreen) -> open_for(...).
## Target berupa Callable get/set agar bisa dipakai untuk kontrol apa pun
## (di touchscreen field-nya BUKAN LineEdit — lihat menu.gd).
## Keyboard fisik tetap didukung via _unhandled_key_input saat terbuka
## (berguna untuk laptop touchscreen).

signal closed
signal opened

const KEY_H := 48.0
const KEY_SEP := 5
# Layout ala PS4: angka di atas, huruf kecil qwerty; baris z + shift/backspace
# dan baris spasi/simbol/OK dirakit khusus di _rebuild_keys().
const ROW_MAIN: Array[String] = ["1234567890", "qwertyuiop", "asdfghjkl"]
const ROW_Z := "zxcvbnm"
const ROW_SYMBOLS: Array[String] = [".", "-", "_"]

var _get_text: Callable
var _set_text: Callable
var _max_len: int = 0
var _charset := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
var _shift := false
var _panel: PanelContainer
var _title_l: Label
var _preview_l: Label
var _rows_box: VBoxContainer


func _ready() -> void:
	# Ukuran diatur parent via set_anchors_preset SEBELUM add_child (lihat menu.gd).
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
	_rows_box.add_theme_constant_override("separation", KEY_SEP)
	vb.add_child(_rows_box)


func _on_dim_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close()


func _has_target() -> bool:
	return _get_text.is_valid() and _set_text.is_valid()


func open_for(get_text: Callable, set_text: Callable, max_len: int, title: String, charset: String) -> void:
	_get_text = get_text
	_set_text = set_text
	_max_len = max_len
	_charset = charset
	_shift = false
	_title_l.text = title
	_rebuild_keys()
	_update_preview()
	visible = true
	opened.emit()


func close() -> void:
	visible = false
	_get_text = Callable()
	_set_text = Callable()
	closed.emit()


func is_open() -> bool:
	return visible


## Tinggi panel keyboard (untuk geser menu ke atas saat keyboard terbuka).
func panel_height() -> float:
	return -_panel.offset_top


## True jika charset mengandung huruf kecil (a-z) -> tombol shift ditampilkan.
func _has_lowercase() -> bool:
	for i in range(26):
		if _charset.contains(String.chr(97 + i)):
			return true
	return false


## Aturan tampil per huruf (ch dalam bentuk kecil):
## - lewati ("") jika charset tidak mengandung ch maupun versi besarnya
## - tampil uppercase jika _shift aktif ATAU charset hanya punya versi besar
## - selain itu tampil lowercase; digit/simbol tampil apa adanya
func _disp_char(ch: String) -> String:
	var lo := ch.to_lower()
	var up := ch.to_upper()
	var has_lo := _charset.contains(lo)
	var has_up := _charset.contains(up)
	if not has_lo and not has_up:
		return ""
	if lo == up:
		return ch
	if _shift or not has_lo:
		return up
	return lo


func _toggle_shift() -> void:
	_shift = not _shift
	_rebuild_keys()


func _rebuild_keys() -> void:
	for c in _rows_box.get_children():
		c.queue_free()
	var rows := 0
	# Baris utama: angka + qwerty kecil, difilter _charset.
	for qrow in ROW_MAIN:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", KEY_SEP)
		var n := 0
		for i in qrow.length():
			var d := _disp_char(qrow.substr(i, 1))
			if d != "":
				row.add_child(_make_key(d, _press.bind(d)))
				n += 1
		if n == 0:
			row.queue_free()
			continue
		_rows_box.add_child(row)
		rows += 1
	# Baris khusus: [⇧][z x c v b n m][⌫]. Shift hanya jika ada huruf kecil.
	var zrow := HBoxContainer.new()
	zrow.add_theme_constant_override("separation", KEY_SEP)
	if _has_lowercase():
		var sh := _make_key("⇧", _toggle_shift)
		if _shift:
			sh.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		zrow.add_child(sh)
	for i in ROW_Z.length():
		var d := _disp_char(ROW_Z.substr(i, 1))
		if d != "":
			zrow.add_child(_make_key(d, _press.bind(d)))
	zrow.add_child(_make_key("⌫", _backspace))
	_rows_box.add_child(zrow)
	rows += 1
	# Baris bawah: [Space lebar][.][-][_][OK]. Space & simbol difilter charset.
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", KEY_SEP)
	_rows_box.add_child(bottom)
	if _charset.contains(" "):
		var sp := _make_key("Space", _press.bind(" "))
		sp.size_flags_stretch_ratio = 3.0
		bottom.add_child(sp)
	for s in ROW_SYMBOLS:
		if _charset.contains(s):
			bottom.add_child(_make_key(s, _press.bind(s)))
	var ok := _make_key("OK", close)
	ok.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	ok.size_flags_stretch_ratio = 2.0
	bottom.add_child(ok)
	rows += 1
	# Sesuaikan tinggi panel dengan jumlah baris.
	_panel.offset_top = -(118.0 + float(rows) * (KEY_H + float(KEY_SEP)))


func _make_key(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(40, KEY_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	return b


func _press(ch: String) -> void:
	if not _has_target():
		return
	var t: String = _get_text.call()
	if _max_len > 0 and t.length() >= _max_len:
		return
	_set_text.call(t + ch)
	_update_preview()


func _backspace() -> void:
	if not _has_target():
		return
	var t: String = _get_text.call()
	if t.length() > 0:
		_set_text.call(t.substr(0, t.length() - 1))
	_update_preview()


func _update_preview() -> void:
	_preview_l.text = _get_text.call() if _has_target() else ""


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not _has_target():
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
		var raw := String.chr(k.unicode)
		var ch := ""
		if raw.length() == 1:
			if _charset.contains(raw):
				ch = raw
			elif _charset.contains(raw.to_upper()):
				ch = raw.to_upper()
		if ch != "":
			_press(ch)
			get_viewport().set_input_as_handled()
