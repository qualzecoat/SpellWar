extends Node2D
## Koordinator Fase 1: model inventory, deteksi kata, efek kata,
## buka/tutup panel, trigger minigame, toast.

var inventory: SpellInventory
var active_words: Dictionary = {}
var ui_open := false

var _interact_available := false

# Sengaja untyped: akses member/sinyal custom (game, open_panel, dsb.)
# tidak dikenal oleh static typing base class Godot.
@onready var player = $Player
@onready var hud = $HUD
@onready var inv_ui = $HUD/InventoryPanel
@onready var minigame = $HUD/MinigamePanel
@onready var map = $Map


func _ready() -> void:
	inventory = SpellInventory.new()
	player.joystick = hud.joystick
	player.hp_changed.connect(_on_hp_changed)
	hud.inventory_pressed.connect(open_inventory)
	hud.weapon_pressed.connect(_on_weapon_pressed)
	hud.interact_pressed.connect(_on_interact_pressed)
	inv_ui.game = self
	inv_ui.closed.connect(close_inventory)
	minigame.finished.connect(_on_minigame_finished)
	map.puzzle_zone_changed.connect(_on_puzzle_zone)
	_on_hp_changed(player.hp, player.max_hp)
	hud.set_ep(player.ep, player.max_ep)
	inv_ui.refresh(inventory, active_words)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if _interact_available and not ui_open:
			open_minigame()
	elif event.is_action_pressed("ui_cancel"):
		if inv_ui.is_open():
			close_inventory()


# ---------- inventory & kata ----------

func on_inventory_changed() -> void:
	rescan_words()


func rescan_words() -> void:
	var found := inventory.scan_words()
	var removed: Array = []
	var added: Array = []
	for w in active_words.keys():
		if not found.has(w):
			removed.append(w)
	for w in found.keys():
		if not active_words.has(w):
			added.append(w)
	active_words = found
	for w in removed:
		_remove_word_effect(w)
	for w in added:
		_apply_word_effect(w)
	inv_ui.refresh(inventory, active_words)


func _apply_word_effect(word: String) -> void:
	match word:
		"SWORD":
			hud.show_weapon()
		"HP":
			player.set_max_hp(player.max_hp + 50)
			player.heal(50)
	hud.show_toast("Kata " + word + " aktif!")


func _remove_word_effect(word: String) -> void:
	match word:
		"SWORD":
			hud.hide_weapon()
		"HP":
			player.set_max_hp(player.max_hp - 50)
	hud.show_toast("Kata " + word + " pecah!")


func _on_hp_changed(hp: int, max_hp: int) -> void:
	hud.set_hp(hp, max_hp)


# ---------- panel ----------

func open_inventory() -> void:
	if ui_open:
		return
	ui_open = true
	player.input_enabled = false
	inv_ui.open_panel()


func close_inventory() -> void:
	inv_ui.close_panel()
	ui_open = false
	player.input_enabled = true


func open_minigame() -> void:
	if ui_open:
		return
	ui_open = true
	player.input_enabled = false
	hud.set_interact_visible(false)
	minigame.start_puzzle()


func _on_minigame_finished(success: bool) -> void:
	ui_open = false
	player.input_enabled = true
	if success:
		var letters: Array = []
		for i in 5:
			letters.append(String.chr(randi_range(65, 90)))
		inventory.add_letters(letters)
		rescan_words()
		hud.show_toast("Hadiah: " + " ".join(PackedStringArray(letters)))
	hud.set_interact_visible(_interact_available)


# ---------- interaksi ----------

func _on_puzzle_zone(inside: bool) -> void:
	_interact_available = inside
	if not ui_open:
		hud.set_interact_visible(inside)


func _on_interact_pressed() -> void:
	if _interact_available and not ui_open:
		open_minigame()


func _on_weapon_pressed() -> void:
	if active_words.has("SWORD"):
		player.swing_sword()
