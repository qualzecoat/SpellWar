extends PanelContainer
## Panel DEBUG khusus testing Fase 2 (BUKAN fitur game).
## Tombol: lukai diri, beri huruf, spawn dummy.
## Akan dimatikan/dihapus sebelum rilis. Tandai jelas: judul "DEBUG".

signal hurt_self_pressed
signal give_letter_pressed(letter: String)
signal spawn_dummy_pressed

var _letter_opt: OptionButton


func _ready() -> void:
	visible = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.10, 0.12, 0.92)
	bg.border_color = Color(1.0, 0.3, 0.3)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", bg)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "DEBUG (testing saja)"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	vbox.add_child(title)

	var hurt := Button.new()
	hurt.text = "Lukai diri 50"
	hurt.pressed.connect(func() -> void: hurt_self_pressed.emit())
	vbox.add_child(hurt)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)
	_letter_opt = OptionButton.new()
	for i in range(65, 91):
		_letter_opt.add_item(String.chr(i), i - 65)
	row.add_child(_letter_opt)
	var give := Button.new()
	give.text = "Beri huruf"
	give.pressed.connect(func() -> void: give_letter_pressed.emit(String.chr(_letter_opt.selected + 65)))
	row.add_child(give)

	var dummy := Button.new()
	dummy.text = "Spawn dummy di sini"
	dummy.pressed.connect(func() -> void: spawn_dummy_pressed.emit())
	vbox.add_child(dummy)


func toggle() -> void:
	visible = not visible
