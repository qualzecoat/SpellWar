extends Control
## Panel Mesin Tukar Huruf (sisi kiri layar) — POLA STANDAR untuk semua mesin:
## interaksi -> inventory terbuka otomatis + panel mesin di kiri,
## semua transfer huruf via DRAG-AND-DROP dari/ke inventory.
## Batal/tutup -> huruf yang di-drag ke slot kembali ke inventory (reserved).
##
## Drag dikoordinasi oleh inventory_ui (begin_external_drag); panel ini
## menyediakan slot: try_drop_slot / place_in_slot / clear_slot.

signal confirmed(data: Dictionary)
signal cancelled

const PANEL_W := 400.0
const SOURCE_PX := 60.0
const TARGET_PX := 44.0
const PAY_PX := 46.0
const MAX_PAY := 13

var game = null  # game.gd: inventory, inv_ui, on_inventory_changed()

var _is_open := false
var _source: Dictionary = {}          # {letter, origin} atau {}
var _source_btn: Button
var _target := ""
var _target_btns: Dictionary = {}     # huruf -> Button
var _cost := 0
var _cost_label: Label
var _payments: Array = []             # MAX_PAY elemen: {letter, origin} atau {}
var _pay_btns: Array = []
var _swap_btn: Button

var _style_slot: StyleBoxFlat
var _style_target: StyleBoxFlat
var _style_selected: StyleBoxFlat


func _ready() -> void:
	for i in MAX_PAY:
		_payments.append({})
	_make_styles()
	_build()
	visible = false


func _make_styles() -> void:
	_style_slot = StyleBoxFlat.new()
	_style_slot.bg_color = Color(0.10, 0.20, 0.24)
	_style_slot.border_color = Color(0.35, 0.65, 0.75)
	_style_slot.set_border_width_all(2)
	_style_slot.set_corner_radius_all(6)
	_style_target = StyleBoxFlat.new()
	_style_target.bg_color = Color(0.13, 0.16, 0.22)
	_style_target.border_color = Color(0.35, 0.38, 0.50)
	_style_target.set_border_width_all(2)
	_style_target.set_corner_radius_all(6)
	_style_selected = StyleBoxFlat.new()
	_style_selected.bg_color = Color(0.12, 0.38, 0.34)
	_style_selected.border_color = Color(0.35, 0.95, 0.75)
	_style_selected.set_border_width_all(3)
	_style_selected.set_corner_radius_all(6)


func _make_button(text: String, px: float, font_size: int, style: StyleBoxFlat) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(px, px)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", style)
	b.add_theme_stylebox_override("pressed", style)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", style)
	return b


func _make_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var panel := Panel.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = PANEL_W
	panel.offset_bottom = 0.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.19, 0.23)
	bg.border_color = Color(0.30, 0.60, 0.70)
	bg.set_border_width_all(0)
	bg.border_width_right = 3
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := _make_label("TUKAR HURUF", 30)
	vbox.add_child(title)
	vbox.add_child(_make_label(
		"Drag 1 huruf dari inventory ke slot sumber, pilih huruf target, lalu bayar biaya dengan huruf apa saja.",
		15))

	vbox.add_child(_make_label("Huruf sumber:", 18))
	_source_btn = _make_button("", SOURCE_PX, 30, _style_slot)
	_source_btn.gui_input.connect(_on_source_gui_input)
	vbox.add_child(_source_btn)

	vbox.add_child(_make_label("Huruf target:", 18))
	var tgrid := GridContainer.new()
	tgrid.columns = 7
	tgrid.add_theme_constant_override("h_separation", 4)
	tgrid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(tgrid)
	for i in 26:
		var letter := String.chr(65 + i)
		var b := _make_button(letter, TARGET_PX, 20, _style_target)
		b.pressed.connect(_on_target_pressed.bind(letter))
		_target_btns[letter] = b
		tgrid.add_child(b)

	_cost_label = _make_label("Biaya: -", 20)
	vbox.add_child(_cost_label)

	vbox.add_child(_make_label("Pembayaran (drag huruf ke sini):", 18))
	var pgrid := GridContainer.new()
	pgrid.columns = 7
	pgrid.add_theme_constant_override("h_separation", 4)
	pgrid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(pgrid)
	for i in MAX_PAY:
		var b := _make_button("", PAY_PX, 24, _style_slot)
		var idx := i
		b.gui_input.connect(_on_pay_gui_input.bind(idx))
		_pay_btns.append(b)
		pgrid.add_child(b)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)
	_swap_btn = Button.new()
	_swap_btn.text = "TUKAR"
	_swap_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_swap_btn.add_theme_font_size_override("font_size", 22)
	_swap_btn.pressed.connect(_on_confirm)
	row.add_child(_swap_btn)
	var cancel := Button.new()
	cancel.text = "Batal"
	cancel.add_theme_font_size_override("font_size", 22)
	cancel.pressed.connect(func() -> void: cancelled.emit())
	row.add_child(cancel)

	_refresh_all()


func is_open() -> bool:
	return _is_open


func open_panel() -> void:
	_source = {}
	_target = ""
	_cost = 0
	for i in MAX_PAY:
		_payments[i] = {}
	_refresh_all()
	visible = true
	_is_open = true


func close_panel() -> void:
	_is_open = false
	visible = false


func clear_slots() -> void:
	_source = {}
	_target = ""
	_cost = 0
	for i in MAX_PAY:
		_payments[i] = {}
	_refresh_all()


## Kembalikan semua huruf di slot ke inventory (dipakai saat batal/tutup).
func return_all_to_inventory() -> void:
	if game == null:
		return
	var letters: Array = []
	if not _source.is_empty():
		letters.append(str(_source["letter"]))
	for p in _payments:
		if not (p as Dictionary).is_empty():
			letters.append(str((p as Dictionary)["letter"]))
	if not letters.is_empty():
		game.inventory.add_letters(letters)
	clear_slots()


# ---------- protokol drag (dipanggil inventory_ui) ----------

## Coba jatuhkan huruf ke slot (sumber dulu, lalu area pembayaran).
## from_kind: "inv" | "source" | "payment".
## Pembayaran: cukup drop di AREA kotak pembayaran (bukan harus tepat per kotak)
## -> huruf otomatis masuk ke KOTAK KOSONG PALING KIRI.
func try_drop_slot(mp: Vector2, letter: String, origin: int, _from_kind: String) -> bool:
	if _source.is_empty() and (_source_btn as Control).get_global_rect().has_point(mp):
		_source = {"letter": letter, "origin": origin}
		_after_change()
		return true
	if _cost > 0:
		var area := Rect2()
		var has_area := false
		for i in _cost:
			var r := (_pay_btns[i] as Control).get_global_rect()
			if not has_area:
				area = r
				has_area = true
			else:
				area = area.merge(r)
		if has_area and area.has_point(mp):
			for i in _cost:
				if (_payments[i] as Dictionary).is_empty():
					_payments[i] = {"letter": letter, "origin": origin}
					_after_change()
					return true
	return false


## Kembalikan/taruh huruf ke slot tertentu (swap atau drop gagal).
func place_in_slot(kind: String, slot_idx: int, letter: String, origin: int) -> void:
	if kind == "source":
		_source = {"letter": letter, "origin": origin}
	elif kind == "payment" and slot_idx >= 0 and slot_idx < MAX_PAY:
		_payments[slot_idx] = {"letter": letter, "origin": origin}
	_after_change()


func clear_slot(kind: String, slot_idx: int) -> void:
	if kind == "source":
		_source = {}
	elif kind == "payment" and slot_idx >= 0 and slot_idx < MAX_PAY:
		_payments[slot_idx] = {}
	_after_change()


# ---------- interaksi slot ----------

func _on_source_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and game != null:
			if not _source.is_empty():
				var letter := str(_source["letter"])
				var origin := int(_source["origin"])
				_source = {}
				_after_change()
				game.inv_ui.begin_external_drag(letter, {"kind": "source", "slot": -1, "origin": origin})
				accept_event()


func _on_pay_gui_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and game != null:
			var p: Dictionary = _payments[idx]
			if not p.is_empty():
				var letter := str(p["letter"])
				var origin := int(p["origin"])
				_payments[idx] = {}
				_after_change()
				game.inv_ui.begin_external_drag(letter, {"kind": "payment", "slot": idx, "origin": origin})
				accept_event()


func _on_target_pressed(letter: String) -> void:
	if not _source.is_empty() and letter == str(_source["letter"]):
		return  # huruf sama = tidak bisa (biaya 0)
	_target = letter
	_after_change()


# ---------- state ----------

func _after_change() -> void:
	if not _source.is_empty() and _target == str(_source["letter"]):
		_target = ""
	_recalc_cost()
	_refresh_all()


func _recalc_cost() -> void:
	var new_cost := 0
	if not _source.is_empty() and _target != "":
		new_cost = SpellExchange.cost(str(_source["letter"]), _target)
	if new_cost != _cost:
		# Kembalikan pembayaran yang melebihi biaya baru ke inventory.
		for i in range(new_cost, MAX_PAY):
			var p: Dictionary = _payments[i]
			if not p.is_empty():
				if game != null:
					game.inventory.add_letters([str(p["letter"])])
				_payments[i] = {}
		_cost = new_cost
		if game != null:
			game.on_inventory_changed()


func _count_payments() -> int:
	var n := 0
	for i in _cost:
		if not (_payments[i] as Dictionary).is_empty():
			n += 1
	return n


func _refresh_all() -> void:
	_source_btn.text = str(_source.get("letter", ""))
	for letter in _target_btns.keys():
		var b: Button = _target_btns[letter]
		b.disabled = not _source.is_empty() and letter == str(_source["letter"])
		var st: StyleBoxFlat = _style_selected if letter == _target else _style_target
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		b.add_theme_stylebox_override("pressed", st)
	if not _source.is_empty() and _target != "":
		_cost_label.text = "Biaya: %d huruf" % _cost
	else:
		_cost_label.text = "Biaya: -"
	for i in _pay_btns.size():
		var pb: Button = _pay_btns[i]
		pb.visible = i < _cost
		pb.text = str((_payments[i] as Dictionary).get("letter", ""))
	var ready := (not _source.is_empty() and _target != ""
		and _cost > 0 and _count_payments() == _cost)
	_swap_btn.disabled = not ready


func _on_confirm() -> void:
	if _swap_btn.disabled:
		return
	var pay_origins: Array = []
	for i in _cost:
		pay_origins.append(int((_payments[i] as Dictionary)["origin"]))
	confirmed.emit({
		"source_letter": str(_source["letter"]),
		"source_origin": int(_source["origin"]),
		"target": _target,
		"payment_origins": pay_origins,
	})
