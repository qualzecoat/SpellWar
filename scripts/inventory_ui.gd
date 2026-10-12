extends Control
## Panel inventory: drawer geser dari kanan, grid 8x8 drag-drop huruf
## (mouse & sentuh via emulasi mouse), highlight kata aktif.

signal closed

const DRAWER_W := 700.0
const CELL_PX := 56.0

var game = null  # di-set oleh game.gd; punya inventory, on_inventory_changed(), close_inventory()
var exchange = null  # ExchangePanel, di-set oleh game.gd (untuk drop antar-panel)

var _cells: Array = []
var _active_list: VBoxContainer
var _word_list: VBoxContainer
var _word_labels: Dictionary = {}  # kata -> Label (untuk highlight "bisa dibentuk")
var _drawer: Panel
var _is_open := false
var _dragging := false
var _drag_from := -1
var _drag_payload: Dictionary = {}  # {kind: "inv"|"source"|"payment", from/slot, origin, letter}
var _drag_label: Label = null
var _style_normal: StyleBoxFlat
var _style_word: StyleBoxFlat


func _ready() -> void:
	_make_styles()
	_build()
	visible = false


func _make_styles() -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.16, 0.16, 0.22)
	_style_normal.border_color = Color(0.35, 0.38, 0.50)
	_style_normal.set_border_width_all(2)
	_style_normal.set_corner_radius_all(6)
	_style_word = StyleBoxFlat.new()
	_style_word.bg_color = Color(0.16, 0.32, 0.20)
	_style_word.border_color = Color(0.35, 0.85, 0.45)
	_style_word.set_border_width_all(3)
	_style_word.set_corner_radius_all(6)


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.5)
	add_child(dim)

	_drawer = Panel.new()
	_drawer.anchor_left = 1.0
	_drawer.anchor_top = 0.0
	_drawer.anchor_right = 1.0
	_drawer.anchor_bottom = 1.0
	_drawer.offset_left = 0.0
	_drawer.offset_top = 0.0
	_drawer.offset_right = 0.0
	_drawer.offset_bottom = 0.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.55, 0.16, 0.14)
	_drawer.add_theme_stylebox_override("panel", bg)
	add_child(_drawer)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_drawer.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "INVENTORY"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	header.add_child(title)
	var back := Button.new()
	back.text = "← Kembali"
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(func() -> void: closed.emit())
	header.add_child(back)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(160, 0)
	left.add_theme_constant_override("separation", 6)
	content.add_child(left)

	var active_title := Label.new()
	active_title.text = "Kata aktif:"
	active_title.add_theme_font_size_override("font_size", 20)
	left.add_child(active_title)
	_active_list = VBoxContainer.new()
	_active_list.add_theme_constant_override("separation", 4)
	left.add_child(_active_list)

	var words_title := Label.new()
	words_title.text = "Daftar kata:"
	words_title.add_theme_font_size_override("font_size", 20)
	left.add_child(words_title)
	var word_scroll := ScrollContainer.new()
	word_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	word_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(word_scroll)
	_word_list = VBoxContainer.new()
	_word_list.add_theme_constant_override("separation", 4)
	_word_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	word_scroll.add_child(_word_list)
	for word in WordDB.WORDS.keys():
		var lbl := Label.new()
		lbl.text = word + "\n" + str(WordDB.DESCRIPTIONS.get(word, ""))
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_word_list.add_child(lbl)
		_word_labels[word] = lbl

	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(grid)

	for i in SpellInventory.CELLS:
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(CELL_PX, CELL_PX)
		cell.add_theme_font_size_override("font_size", 26)
		cell.add_theme_stylebox_override("normal", _style_normal)
		cell.add_theme_stylebox_override("hover", _style_normal)
		cell.add_theme_stylebox_override("pressed", _style_normal)
		cell.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var idx := i
		cell.gui_input.connect(_on_cell_gui_input.bind(idx))
		_cells.append(cell)
		grid.add_child(cell)


func is_open() -> bool:
	return _is_open


func open_panel() -> void:
	visible = true
	_is_open = true
	var tw := create_tween()
	tw.tween_property(_drawer, "offset_left", -DRAWER_W, 0.25).set_trans(Tween.TRANS_CUBIC)


func close_panel() -> void:
	_is_open = false
	_end_drag()
	var tw := create_tween()
	tw.tween_property(_drawer, "offset_left", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(func() -> void: visible = false)


## Sinkron tampilan dengan model.
func refresh(inventory: SpellInventory, active_words: Dictionary) -> void:
	var word_cells: Dictionary = {}
	for word in active_words.keys():
		for ci in active_words[word]["cells"]:
			word_cells[ci] = true
	for i in _cells.size():
		var v = inventory.grid[i]
		_cells[i].text = str(v) if v != null else ""
		_cells[i].add_theme_stylebox_override(
			"normal", _style_word if word_cells.has(i) else _style_normal)
		_cells[i].add_theme_stylebox_override(
			"hover", _style_word if word_cells.has(i) else _style_normal)
		_cells[i].add_theme_stylebox_override(
			"pressed", _style_word if word_cells.has(i) else _style_normal)
	for child in _active_list.get_children():
		child.queue_free()
	if active_words.is_empty():
		var lbl := Label.new()
		lbl.text = "-"
		lbl.add_theme_font_size_override("font_size", 18)
		_active_list.add_child(lbl)
	for word in active_words.keys():
		var lbl := Label.new()
		lbl.text = word
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
		_active_list.add_child(lbl)
	# Highlight kata yang BISA dibentuk dari huruf saat ini (hint, bukan aktif).
	var counts := inventory.letter_counts()
	for word in _word_labels.keys():
		var wlbl: Label = _word_labels[word]
		if active_words.has(word):
			wlbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
		elif SpellInventory.can_form(str(word), counts):
			wlbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
		else:
			wlbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))


func _on_cell_gui_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and game != null:
			if game.inventory.grid[idx] != null:
				_dragging = true
				_drag_from = idx
				_drag_payload = {"kind": "inv", "from": idx, "letter": str(game.inventory.grid[idx])}
				_make_drag_label(str(game.inventory.grid[idx]))
				accept_event()


## Mulai drag dari slot panel mesin (dipanggil exchange_ui).
## payload: {kind: "source"|"payment", slot: int, origin: int}
func begin_external_drag(letter: String, payload: Dictionary) -> void:
	if _dragging:
		return
	_dragging = true
	_drag_from = -1
	_drag_payload = payload.duplicate()
	_drag_payload["letter"] = letter
	_make_drag_label(letter)


## Batalkan drag yang sedang berjalan; kembalikan huruf ke slot asalnya.
func cancel_drag() -> void:
	if not _dragging:
		return
	var kind := str(_drag_payload.get("kind", "inv"))
	if kind != "inv" and exchange != null:
		exchange.place_in_slot(kind, int(_drag_payload.get("slot", -1)),
			str(_drag_payload.get("letter", "")),
			int(_drag_payload.get("origin", -1)))
	_end_drag()


func _make_drag_label(letter: String) -> void:
	_drag_label = Label.new()
	_drag_label.text = letter
	_drag_label.add_theme_font_size_override("font_size", 34)
	_drag_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_drag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# FIX 2026-10-12: ghost drag harus selalu render DI ATAS semua UI
	# (termasuk panel mesin lain seperti ExchangePanel yang merupakan sibling
	# dan digambar belakangan). z absolut dalam CanvasLayer yang sama.
	_drag_label.z_as_relative = false
	_drag_label.z_index = 4096
	add_child(_drag_label)


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		_update_drag_label()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_finish_drag()


func _process(_delta: float) -> void:
	if _dragging:
		_update_drag_label()


func _update_drag_label() -> void:
	if _drag_label != null:
		_drag_label.global_position = get_global_mouse_position() + Vector2(-12, -24)


func _finish_drag() -> void:
	if game == null:
		_end_drag()
		return
	var mp := get_global_mouse_position()
	var kind := str(_drag_payload.get("kind", "inv"))
	var letter := str(_drag_payload.get("letter", ""))
	# 1. Drop ke cell inventory?
	var target := -1
	for i in _cells.size():
		if (_cells[i] as Control).get_global_rect().has_point(mp):
			target = i
			break
	if target != -1:
		if kind == "inv":
			var from_idx: int = _drag_payload["from"]
			if target != from_idx:
				game.inventory.move_letter(from_idx, target)
				game.on_inventory_changed()
		else:
			# Dari slot mesin -> cell inventory (swap jika terisi).
			var cell_v = game.inventory.grid[target]
			game.inventory.grid[target] = letter
			if cell_v != null:
				exchange.place_in_slot(kind, int(_drag_payload["slot"]), str(cell_v), target)
			else:
				exchange.clear_slot(kind, int(_drag_payload["slot"]))
			game.on_inventory_changed()
		_end_drag()
		return
	# 2. Drop ke slot mesin?
	if exchange != null and exchange.is_open():
		var origin := -1
		if kind == "inv":
			origin = int(_drag_payload["from"])
		else:
			origin = int(_drag_payload.get("origin", -1))
		if exchange.try_drop_slot(mp, letter, origin, kind):
			if kind == "inv":
				game.inventory.grid[origin] = null
			# kind mesin: slot asal sudah dikosongkan saat drag dimulai
			game.on_inventory_changed()
			_end_drag()
			return
	# 3. Tidak kena apa-apa -> kembalikan ke asal.
	if kind != "inv" and exchange != null:
		exchange.place_in_slot(kind, int(_drag_payload["slot"]), letter,
			int(_drag_payload.get("origin", -1)))
	_end_drag()


func _end_drag() -> void:
	_dragging = false
	_drag_from = -1
	if _drag_label != null:
		_drag_label.queue_free()
		_drag_label = null
