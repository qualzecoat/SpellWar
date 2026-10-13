extends CanvasLayer
## HUD Fase 2: bar HP/EP (+angka), tombol inventory, 3 tombol senjata
## (SWORD/PISTOL/TRAP — muncul hanya jika katanya terbentuk),
## tombol interact kontekstual, joystick virtual, toast, label respawn,
## tombol debug.

signal inventory_pressed
signal weapon_pressed(weapon: String)
signal interact_pressed
signal debug_toggled

# Sengaja untyped (lihat catatan di game.gd).
@onready var top_left = $TopLeft
@onready var hp_bar = $TopLeft/HPRow/HPBar
@onready var hp_label = $TopLeft/HPRow/HPBar/ValueLabel
@onready var ep_bar = $TopLeft/EPRow/EPBar
@onready var ep_label = $TopLeft/EPRow/EPBar/ValueLabel

var sp_label: Label = null
# FIX 2026-10-13 (Fix 6): overlay garis segmentasi bar.
var _hp_seg: BarSegments = null
var _ep_seg: BarSegments = null
@onready var inventory_button = $InventoryButton
@onready var sword_button = $SwordButton
@onready var pistol_button = $PistolButton
@onready var trap_button = $TrapButton
@onready var interact_button = $InteractButton
@onready var joystick = $Joystick
@onready var toast_label = $ToastLabel
@onready var respawn_label = $RespawnLabel
@onready var debug_button = $DebugButton
@onready var debug_panel = $DebugPanel

var _actions_enabled := true
# FIX 2026-10-13: panel mesin (tukar huruf, minigame) menutupi area joystick.
# Counter agar joystick selalu kembali tampil setelah SEMUA panel mesin tertutup.
var _machine_panels := 0


func _ready() -> void:
	inventory_button.pressed.connect(func() -> void: inventory_pressed.emit())
	sword_button.pressed.connect(func() -> void: weapon_pressed.emit("SWORD"))
	pistol_button.pressed.connect(func() -> void: weapon_pressed.emit("PISTOL"))
	trap_button.pressed.connect(func() -> void: weapon_pressed.emit("TRAP"))
	interact_button.pressed.connect(func() -> void: interact_pressed.emit())
	debug_button.pressed.connect(func() -> void: debug_toggled.emit())
	sword_button.visible = false
	pistol_button.visible = false
	trap_button.visible = false
	interact_button.visible = false
	respawn_label.visible = false
	_style_bar(hp_bar, Color(0.90, 0.28, 0.28))
	_style_bar(ep_bar, Color(0.28, 0.58, 0.95))
	# FIX 2026-10-13 (Fix 6): garis segmentasi — HP tiap 50, EP tiap 25.
	# Overlay di belakang ValueLabel (label tetap paling atas).
	_hp_seg = BarSegments.new()
	hp_bar.add_child(_hp_seg)
	hp_bar.move_child(_hp_seg, 0)
	_ep_seg = BarSegments.new()
	ep_bar.add_child(_ep_seg)
	ep_bar.move_child(_ep_seg, 0)
	# FIX 2026-10-12 (Fix 4): indikator buff SP di bawah bar EP.
	sp_label = Label.new()
	sp_label.add_theme_font_size_override("font_size", 18)
	sp_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
	sp_label.visible = false
	top_left.add_child(sp_label)


func _style_bar(bar: ProgressBar, fill: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(6)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	bar.show_percentage = false


func set_hp(hp: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_label.text = "%d/%d" % [hp, max_hp]
	if _hp_seg != null:
		_hp_seg.set_params(50.0, float(max_hp))


func set_ep(ep: int, max_ep: int) -> void:
	ep_bar.max_value = max_ep
	ep_bar.value = ep
	ep_label.text = "%d/%d" % [ep, max_ep]
	if _ep_seg != null:
		_ep_seg.set_params(25.0, float(max_ep))


## FIX 2026-10-12 (Fix 4): indikator buff SP, mis. "SP +15%" (stack: +30%).
## FIX 2026-10-13 (Fix 4): ADITIF — 15% per stack (1x=15%, 2x=30%, 3x=45%).
func set_sp_indicator(stacks: int) -> void:
	if sp_label == null:
		return
	if stacks <= 0:
		sp_label.visible = false
		return
	sp_label.visible = true
	var pct := int(round(0.15 * stacks * 100.0))
	sp_label.text = "SP +%d%%" % pct


## EP kurang: bar berkedip + tombol bergoyang.
func flash_ep() -> void:
	var tw := create_tween()
	for i in 3:
		tw.tween_property(ep_bar, "modulate:a", 0.3, 0.08)
		tw.tween_property(ep_bar, "modulate:a", 1.0, 0.08)


func show_weapon(weapon: String) -> void:
	match weapon:
		"SWORD":
			sword_button.visible = _actions_enabled
		"PISTOL":
			pistol_button.visible = _actions_enabled
		"TRAP":
			trap_button.visible = _actions_enabled
			# Teks count diurus game.gd via set_trap_count (jangan reset di sini).


func hide_weapon(weapon: String) -> void:
	match weapon:
		"SWORD":
			sword_button.visible = false
		"PISTOL":
			pistol_button.visible = false
		"TRAP":
			trap_button.visible = false


## FIX 2026-10-12 (Fix 3): jumlah = trap AKTIF terpasang / maksimal (3).
## Bukan amunisi — trap meledak = slot kembali.
func set_trap_count(active: int, max_n: int) -> void:
	trap_button.text = "TRAP (%d/%d)" % [active, max_n]


## Saat drawer inventory terbuka: action dimatikan (tombol disembunyikan),
## tapi joystick/gerak tetap jalan.
func set_actions_enabled(v: bool) -> void:
	_actions_enabled = v
	if not v:
		sword_button.visible = false
		pistol_button.visible = false
		trap_button.visible = false
		interact_button.visible = false
	# Saat dinyalakan lagi, game.gd memanggil refresh via show_weapon ulang.


## FIX 2026-10-13: panel mesin (tukar huruf, minigame/puzzle) tampil di daerah
## joystick — sembunyikan joystick selama ADA panel mesin terbuka, tampilkan
## lagi saat semua tertutup. Drawer inventory SAJA tidak memanggil ini
## (joystick tetap tampil & bisa dipakai). Panel mesin berikutnya (mis.
## ekstraksi Fase 4) cukup panggil fungsi ini saat buka/tutup.
func set_machine_panel_open(open: bool) -> void:
	if open:
		_machine_panels += 1
	else:
		_machine_panels = maxi(0, _machine_panels - 1)
	joystick.visible = _machine_panels == 0


func set_interact_visible(v: bool) -> void:
	interact_button.visible = v and _actions_enabled


func set_interact_text(t: String) -> void:
	interact_button.text = t


## Interact tersedia: tombol menyala (highlight). Tidak ada: redup (mode dorong).
func set_interact_highlighted(active: bool) -> void:
	if active:
		interact_button.modulate = Color(1.0, 1.0, 1.0)
	else:
		interact_button.modulate = Color(1.0, 1.0, 1.0, 0.55)


func show_respawn(seconds: int) -> void:
	respawn_label.visible = true
	respawn_label.text = "Respawn: %d" % seconds


func hide_respawn() -> void:
	respawn_label.visible = false


func show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.5)
