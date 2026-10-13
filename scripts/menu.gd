extends Control
## Menu utama SpellWar Fase 3: nickname -> Main Sendiri / Buat Room / Join Room.
## Juga menangani lobby (daftar pemain, kode room, tombol MULAI untuk host).
## Jika argumen --server diberikan: langsung alihkan ke server_main.tscn.

const CFG_PATH := "user://spellwar.cfg"

var _name_edit: LineEdit
var _code_edit: LineEdit
var _status: Label
var _room_label: Label
var _lobby_info: Label
var _player_list: VBoxContainer
var _start_btn: Button

var _panels: Array = []
var _main_panel: VBoxContainer
var _join_panel: VBoxContainer
var _lobby_panel: VBoxContainer
var _kb: TouchKeyboard = null
var _is_touch: bool = false
var _name_value_b: Button = null  # tombol field di mode touchscreen
var _code_value_b: Button = null


func _ready() -> void:
	if "--server" in OS.get_cmdline_user_args():
		call_deferred("_go_server")
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_main_panel = _vbox(14)
	center.add_child(_main_panel)
	var title := Label.new()
	title.text = "SPELLWAR"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_panel.add_child(title)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_main_panel.add_child(name_row)
	var nl := Label.new()
	nl.text = "Nama:"
	nl.add_theme_font_size_override("font_size", 24)
	name_row.add_child(nl)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Nickname"
	_name_edit.max_length = 12
	_name_edit.custom_minimum_size = Vector2(280, 44)
	_name_edit.add_theme_font_size_override("font_size", 24)
	name_row.add_child(_name_edit)

	_add_btn(_main_panel, "MAIN SENDIRI", _on_solo)
	_add_btn(_main_panel, "BUAT ROOM", _on_create)
	_add_btn(_main_panel, "JOIN ROOM", func() -> void: _show(_join_panel))

	# Panel join.
	_join_panel = _vbox(12)
	center.add_child(_join_panel)
	var jl := Label.new()
	jl.text = "Kode Room:"
	jl.add_theme_font_size_override("font_size", 24)
	jl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_join_panel.add_child(jl)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "XXXXXX"
	_code_edit.max_length = 6
	_code_edit.custom_minimum_size = Vector2(280, 48)
	_code_edit.add_theme_font_size_override("font_size", 28)
	_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_join_panel.add_child(_code_edit)
	_add_btn(_join_panel, "GABUNG", _on_join_go)
	_add_btn(_join_panel, "KEMBALI", func() -> void: _show(_main_panel))

	# Panel lobby.
	_lobby_panel = _vbox(10)
	center.add_child(_lobby_panel)
	_room_label = Label.new()
	_room_label.add_theme_font_size_override("font_size", 40)
	_room_label.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_panel.add_child(_room_label)
	_lobby_info = Label.new()
	_lobby_info.add_theme_font_size_override("font_size", 20)
	_lobby_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_panel.add_child(_lobby_info)
	_player_list = VBoxContainer.new()
	_player_list.add_theme_constant_override("separation", 6)
	_lobby_panel.add_child(_player_list)
	_start_btn = Button.new()
	_start_btn.text = "MULAI"
	_start_btn.custom_minimum_size = Vector2(280, 56)
	_start_btn.add_theme_font_size_override("font_size", 28)
	_start_btn.pressed.connect(func() -> void: Net.send_start())
	_lobby_panel.add_child(_start_btn)
	_add_btn(_lobby_panel, "KELUAR", _on_leave)

	_panels = [_main_panel, _join_panel, _lobby_panel]

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 20)
	_status.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status.offset_top = -90
	_status.offset_bottom = -50
	add_child(_status)

	_show(_main_panel)

	# Keyboard virtual untuk touchscreen: keyboard OS (mis. Gboard) tidak bisa
	# mengetik ke LineEdit pada web export (bug engine godot#99602), dan
	# FOCUS_NONE ternyata tidak cukup mencegah keyboard OS muncul di
	# browser HP (quirk sisi browser). Solusi deterministik: di touchscreen
	# TIDAK ADA LineEdit yang bisa difokus sama sekali — field diganti
	# "field palsu" berupa Button yang di-style seperti kolom teks
	# (sinyal pressed terbukti merespons tap di browser HP, tidak seperti
	# gui_input manual). Tap tombol -> membuka keyboard buatan game.
	# Tanpa kontrol teks yang bisa fokus, keyboard OS tidak mungkin muncul.
	# Di PC (non-touch) LineEdit tetap normal via keyboard fisik.
	_kb = TouchKeyboard.new()
	add_child(_kb)
	_is_touch = _is_touch_device()
	if _is_touch:
		_name_value_b = _swap_touch_field(_name_edit, "Nickname", 24, false)
		_code_value_b = _swap_touch_field(_code_edit, "XXXXXX", 28, true)
		_setup_touch_field(_name_value_b, "NICKNAME",
			"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", 12)
		_setup_touch_field(_code_value_b, "KODE ROOM",
			NetProto.CODE_CHARS, 6)

	Net.connected_to_server.connect(func() -> void: _set_status("Terhubung.", false))
	Net.conn_failed.connect(_on_net_failed)
	Net.hello_ok.connect(_on_hello_ok)
	Net.hello_error.connect(_on_hello_error)
	Net.lobby_updated.connect(_on_lobby)
	Net.match_started.connect(_on_match_started)
	Net.server_disconnected.connect(_on_server_dc)
	_load_name()
	if Net.last_error != "":
		_set_status(Net.last_error, true)
		Net.last_error = ""


func _go_server() -> void:
	get_tree().change_scene_to_file("res://scenes/server_main.tscn")


func _vbox(sep: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	return v


func _add_btn(parent: VBoxContainer, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 54)
	b.add_theme_font_size_override("font_size", 26)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _show(panel: VBoxContainer) -> void:
	for p in _panels:
		(p as VBoxContainer).visible = (p == panel)
	if _kb != null and _kb.is_open():
		_kb.close()
	_set_status("", false)


func _is_touch_device() -> bool:
	return DisplayServer.is_touchscreen_available()


# Membuat "field palsu" untuk touchscreen: Button yang di-style seperti
# kolom teks (focus_mode NONE, tidak bisa memicu keyboard OS). LineEdit asli
# disembunyikan (kontrol tersembunyi tidak bisa difokus engine).
# Tap via sinyal pressed (terbukti jalan di browser HP) -> keyboard game.
# Mengembalikan Button field-nya.
func _swap_touch_field(le: LineEdit, placeholder: String, font_size: int, centered: bool) -> Button:
	var parent: Control = le.get_parent()
	var idx := le.get_index()
	le.visible = false
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = le.custom_minimum_size
	b.add_theme_font_size_override("font_size", font_size)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.15, 0.21)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.35, 0.38, 0.48)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("focus", sb)
	var sbp := sb.duplicate() as StyleBoxFlat
	sbp.bg_color = Color(0.09, 0.11, 0.15)
	b.add_theme_stylebox_override("pressed", sbp)
	b.set_meta("placeholder", placeholder)
	b.set_meta("value", "")
	parent.add_child(b)
	parent.move_child(b, idx)
	_refresh_touch_button(b)
	return b


func _refresh_touch_button(b: Button) -> void:
	var v := str(b.get_meta("value", ""))
	var col := Color(0.45, 0.47, 0.55) if v == "" else Color(1, 1, 1)
	b.text = str(b.get_meta("placeholder", "")) if v == "" else v
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col)
	b.add_theme_color_override("font_pressed_color", col)
	b.add_theme_color_override("font_focus_color", col)


func _get_name_text() -> String:
	if _is_touch:
		return str(_name_value_b.get_meta("value", ""))
	return _name_edit.text


func _set_name_text(v: String) -> void:
	if _is_touch:
		_name_value_b.set_meta("value", v)
		_refresh_touch_button(_name_value_b)
	else:
		_name_edit.text = v


func _get_code_text() -> String:
	if _is_touch:
		return str(_code_value_b.get_meta("value", ""))
	return _code_edit.text


func _setup_touch_field(b: Button, title: String, charset: String, max_len: int) -> void:
	# Tap pada tombol field (sinyal pressed) -> buka keyboard buatan game.
	# focus_mode NONE, jadi tidak ada yang bisa memicu keyboard OS.
	# TODO DEBUG SEMENTARA (hapus setelah diagnosis): status DBG di bawah.
	b.pressed.connect(func() -> void:
		_set_status("DBG: pressed, kb=" + ("null" if _kb == null else "ada"), false)
		_kb.open_for(
			func() -> String: return str(b.get_meta("value", "")),
			func(v: String) -> void:
				b.set_meta("value", v)
				_refresh_touch_button(b),
			max_len, title, charset)
		_set_status("DBG: open_for selesai, kb.visible=" + str(_kb.visible), false)
	)


func _set_status(t: String, is_error: bool) -> void:
	_status.text = t
	_status.add_theme_color_override("font_color",
		Color(1.0, 0.6, 0.6) if is_error else Color(0.7, 0.9, 0.7))


# ---------- aksi ----------

func _nickname() -> String:
	return _get_name_text().strip_edges()


func _on_solo() -> void:
	_save_name()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_create() -> void:
	var n := _nickname()
	if n == "":
		_set_status("Isi nickname dulu.", true)
		return
	_save_name()
	_set_status("Menghubungi server...", false)
	Net.connect_room(n, "create")


func _on_join_go() -> void:
	var n := _nickname()
	if n == "":
		_set_status("Isi nickname dulu.", true)
		return
	var code := _get_code_text().strip_edges().to_upper()
	if code.length() != 6:
		_set_status("Kode room 6 karakter.", true)
		return
	_save_name()
	_set_status("Menghubungi server...", false)
	Net.connect_room(n, "join", code)


func _on_leave() -> void:
	Net.disconnect_now()
	_show(_main_panel)


# ---------- net ----------

func _on_net_failed(reason: String) -> void:
	_set_status(reason, true)
	_show(_main_panel)


func _on_hello_ok(code: String, pid: int, host: bool, reconnected: bool) -> void:
	Net.room_code = code
	Net.player_id = pid
	Net.is_host = host
	_room_label.text = "ROOM: " + code
	_show(_lobby_panel)
	_set_status("Reconnect berhasil!" if reconnected else "", false)


func _on_hello_error(msg: String) -> void:
	_set_status(msg, true)
	_show(_main_panel)


func _on_lobby(players: Array, host_id: int, code: String) -> void:
	for c in _player_list.get_children():
		c.queue_free()
	for pl in players:
		var d: Dictionary = pl
		var l := Label.new()
		var mark := " (HOST)" if int(d.get("id", 0)) == host_id else ""
		l.text = str(d.get("name", "?")) + mark
		l.add_theme_font_size_override("font_size", 24)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_player_list.add_child(l)
	_start_btn.visible = Net.is_host
	_lobby_info.text = "%d/8 pemain — %s" % [players.size(),
		"menunggu host menekan MULAI" if not Net.is_host else
		("bisa mulai (min 2)" if players.size() >= 2 else "butuh min 2 pemain")]


func _on_match_started() -> void:
	get_tree().change_scene_to_file("res://scenes/mp_main.tscn")


func _on_server_dc() -> void:
	_set_status("Koneksi ke server putus.", true)
	_show(_main_panel)


# ---------- nickname tersimpan ----------

func _load_name() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		_set_name_text(str(cfg.get_value("menu", "nickname", "")))


func _save_name() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("menu", "nickname", _nickname())
	cfg.save(CFG_PATH)
