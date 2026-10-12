extends CanvasLayer
## HUD Fase 1: bar HP/EP, tombol inventory, tombol senjata, tombol interact,
## joystick virtual, toast notifikasi.

signal inventory_pressed
signal weapon_pressed
signal interact_pressed

# Sengaja untyped (lihat catatan di game.gd).
@onready var hp_bar = $TopLeft/HPRow/HPBar
@onready var ep_bar = $TopLeft/EPRow/EPBar
@onready var inventory_button = $InventoryButton
@onready var weapon_button = $WeaponButton
@onready var interact_button = $InteractButton
@onready var joystick = $Joystick
@onready var toast_label = $ToastLabel


func _ready() -> void:
	inventory_button.pressed.connect(func() -> void: inventory_pressed.emit())
	weapon_button.pressed.connect(func() -> void: weapon_pressed.emit())
	interact_button.pressed.connect(func() -> void: interact_pressed.emit())
	weapon_button.visible = false
	interact_button.visible = false
	_style_bar(hp_bar, Color(0.90, 0.28, 0.28))
	_style_bar(ep_bar, Color(0.28, 0.58, 0.95))


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


func set_ep(ep: int, max_ep: int) -> void:
	ep_bar.max_value = max_ep
	ep_bar.value = ep


func show_weapon() -> void:
	weapon_button.visible = true


func hide_weapon() -> void:
	weapon_button.visible = false


func set_interact_visible(v: bool) -> void:
	interact_button.visible = v


func show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.5)
