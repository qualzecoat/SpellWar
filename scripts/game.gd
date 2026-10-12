extends Node2D
## Koordinator Fase 2: model inventory, deteksi kata, efek 6 kata,
## combat (pistol/sword/trap), EP, kematian/drop/respawn,
## drawer + geser kamera, action button, debug tools.

const DRAWER_SHIFT := 350.0  # = DRAWER_W/2: kamera geser agar karakter di tengah area terlihat
const RESPAWN_TIME := 30.0
const PUSH_RANGE := 110.0
const PUSH_FORCE := 500.0

var inventory: SpellInventory
var active_words: Dictionary = {}
var ui_open := false

var trap_quota := 0
var trap_place_mode := false

var _interact_available := false   # zona puzzle
var _exchange_available := false   # zona mesin tukar
var _exchange_open := false
var _dead := false
var _respawn_left := 0.0
var _trap_preview: Node2D = null

# Sengaja untyped: akses member/sinyal custom tidak dikenal static typing base class.
@onready var player = $Player
@onready var camera = $Player/Camera2D
@onready var hud = $HUD
@onready var inv_ui = $HUD/InventoryPanel
@onready var minigame = $HUD/MinigamePanel
@onready var exchange_ui = $HUD/ExchangePanel
@onready var debug_panel = $HUD/DebugPanel
@onready var map = $Map


func _ready() -> void:
	inventory = SpellInventory.new()
	player.joystick = hud.joystick
	player.hp_changed.connect(_on_hp_changed)
	player.ep_changed.connect(_on_ep_changed)
	player.died.connect(_on_player_died)
	hud.inventory_pressed.connect(open_inventory)
	hud.weapon_pressed.connect(_on_weapon_pressed)
	hud.interact_pressed.connect(_on_interact_pressed)
	hud.debug_toggled.connect(_on_debug_toggled)
	inv_ui.game = self
	inv_ui.exchange = exchange_ui
	inv_ui.closed.connect(close_inventory)
	exchange_ui.game = self
	exchange_ui.confirmed.connect(_on_exchange_confirmed)
	exchange_ui.cancelled.connect(close_exchange)
	minigame.finished.connect(_on_minigame_finished)
	map.puzzle_zone_changed.connect(_on_puzzle_zone)
	map.exchange_zone_changed.connect(_on_exchange_zone)
	debug_panel.hurt_self_pressed.connect(_on_debug_hurt)
	debug_panel.give_letter_pressed.connect(_on_debug_give_letter)
	debug_panel.spawn_dummy_pressed.connect(_on_debug_spawn_dummy)
	_on_hp_changed(player.hp, player.max_hp)
	_on_ep_changed(player.ep, player.max_ep)
	_spawn_test_dummies()
	inv_ui.refresh(inventory, active_words)
	_refresh_interact()


func _process(delta: float) -> void:
	if _dead:
		_respawn_left -= delta
		hud.show_respawn(maxi(int(ceil(_respawn_left)), 0))
		if _respawn_left <= 0.0:
			_respawn_player()
	if trap_place_mode:
		_update_trap_preview()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if not ui_open:
			_on_interact_pressed()
	elif event.is_action_pressed("ui_cancel"):
		if inv_ui.is_open():
			close_inventory()
		elif trap_place_mode:
			_exit_trap_place_mode()


# ---------- inventory & kata ----------

func on_inventory_changed() -> void:
	inv_ui.refresh(inventory, active_words)
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
			hud.show_weapon("SWORD")
		"PISTOL":
			hud.show_weapon("PISTOL")
		"TRAP":
			trap_quota = 3
			hud.show_weapon("TRAP")
			hud.set_trap_quota(trap_quota)
		"HP":
			player.set_max_hp(player.max_hp + 50)
			player.heal(50)
		"EP":
			player.set_max_ep(player.max_ep + 25)
			player.add_ep_regen(2.0)
		"SP":
			player.speed_mult *= 1.15
	hud.show_toast("Kata " + word + " aktif!")


func _remove_word_effect(word: String) -> void:
	match word:
		"SWORD":
			hud.hide_weapon("SWORD")
		"PISTOL":
			hud.hide_weapon("PISTOL")
		"TRAP":
			_exit_trap_place_mode()
			_remove_player_traps()
			trap_quota = 0
			hud.hide_weapon("TRAP")
		"HP":
			player.set_max_hp(player.max_hp - 50)
		"EP":
			player.set_max_ep(player.max_ep - 25)
			player.add_ep_regen(-2.0)
		"SP":
			player.speed_mult /= 1.15
	hud.show_toast("Kata " + word + " pecah!")


func _remove_player_traps() -> void:
	for n in get_tree().get_nodes_in_group("trap"):
		var t := n as SpellTrap
		if t != null and t.owner_node == player:
			t.queue_free()


func _on_hp_changed(hp: int, max_hp: int) -> void:
	hud.set_hp(hp, max_hp)


func _on_ep_changed(ep: int, max_ep: int) -> void:
	hud.set_ep(ep, max_ep)


# ---------- senjata ----------

func _on_weapon_pressed(weapon: String) -> void:
	if ui_open or _dead or not player.alive:
		return
	match weapon:
		"SWORD":
			if not player.spend_ep(8):
				_ep_denied()
				return
			player.swing_sword()
			_melee_damage(25)
		"PISTOL":
			if not player.spend_ep(10):
				_ep_denied()
				return
			SpellProjectile.spawn(self, player.position, player.facing, player)
		"TRAP":
			# Tap 1: masuk mode pasang. Tap 2 (dalam mode): pasang di posisi.
			if trap_place_mode:
				_place_trap_here()
			else:
				_enter_trap_place_mode()


func _ep_denied() -> void:
	hud.flash_ep()
	hud.show_toast("EP tidak cukup!")


func _melee_damage(amount: int) -> void:
	var fwd: Vector2 = player.facing
	for n in get_tree().get_nodes_in_group("damageable"):
		var nd := n as Node2D
		if nd == null or nd == player:
			continue
		if "alive" in nd and not bool(nd.get("alive")):
			continue
		var to: Vector2 = nd.global_position - player.global_position
		if to.length() > 100.0:
			continue
		if fwd.dot(to.normalized()) < 0.35:
			continue
		nd.take_damage(amount)


# ---------- trap: mode pasang ----------

func _enter_trap_place_mode() -> void:
	if trap_place_mode:
		return
	if trap_quota <= 0:
		hud.show_toast("Jatah trap habis!")
		return
	trap_place_mode = true
	hud.set_trap_place_mode(true)
	hud.show_toast("Mode pasang: tap TRAP lagi untuk pasang di posisimu")
	_ensure_trap_preview()


func _exit_trap_place_mode() -> void:
	if not trap_place_mode:
		return
	trap_place_mode = false
	hud.set_trap_place_mode(false)
	hud.set_trap_quota(trap_quota)
	if _trap_preview != null:
		_trap_preview.queue_free()
		_trap_preview = null


func _ensure_trap_preview() -> void:
	if _trap_preview != null:
		return
	_trap_preview = _TrapPreview.new()
	add_child(_trap_preview)


func _update_trap_preview() -> void:
	if _trap_preview != null:
		_trap_preview.position = player.position


func _place_trap_here() -> void:
	if trap_quota <= 0:
		hud.show_toast("Jatah trap habis!")
		_exit_trap_place_mode()
		return
	if not player.spend_ep(15):
		_ep_denied()
		return
	SpellTrap.place(self, player.position, player)
	trap_quota -= 1
	hud.set_trap_quota(trap_quota)
	hud.show_toast("Trap dipasang! Sisa: %d" % trap_quota)
	if trap_quota <= 0:
		_exit_trap_place_mode()


class _TrapPreview extends Node2D:
	func _draw() -> void:
		draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 32, Color(1.0, 0.4, 0.35, 0.8), 3.0)
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 24, Color(1.0, 0.4, 0.35, 0.4), 2.0)

	func _process(_delta: float) -> void:
		queue_redraw()


# ---------- panel & drawer ----------

func open_inventory() -> void:
	if ui_open:
		return
	ui_open = true
	# Fase 2: saat drawer terbuka pemain TETAP BISA GERAK, tapi tidak bisa action.
	hud.set_actions_enabled(false)
	_shift_camera(true)
	inv_ui.open_panel()


func close_inventory() -> void:
	if _exchange_open:
		close_exchange()
		return
	inv_ui.cancel_drag()
	inv_ui.close_panel()
	ui_open = false
	hud.set_actions_enabled(true)
	_shift_camera(false)
	_refresh_weapons()
	_refresh_interact()


func _shift_camera(open: bool) -> void:
	var target := DRAWER_SHIFT if open else 0.0
	var tw := create_tween()
	tw.tween_property(camera, "offset:x", target, 0.25).set_trans(Tween.TRANS_CUBIC)


func _refresh_weapons() -> void:
	for w in active_words.keys():
		if str(WordDB.WORDS[w]["kind"]) == "weapon":
			hud.show_weapon(w)
	if trap_place_mode:
		hud.set_trap_place_mode(true)
	else:
		hud.set_trap_quota(trap_quota)


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
	_refresh_interact()


# ---------- mesin tukar huruf (Fase 1b) ----------

func open_exchange() -> void:
	if ui_open:
		return
	ui_open = true
	_exchange_open = true
	_exit_trap_place_mode()
	player.input_enabled = false
	hud.set_interact_visible(false)
	_shift_camera(true)
	inv_ui.open_panel()
	exchange_ui.open_panel()


func close_exchange() -> void:
	if not _exchange_open:
		return
	inv_ui.cancel_drag()
	exchange_ui.return_all_to_inventory()
	exchange_ui.close_panel()
	inv_ui.close_panel()
	_exchange_open = false
	ui_open = false
	player.input_enabled = true
	_shift_camera(false)
	rescan_words()
	_refresh_interact()


func _on_exchange_confirmed(data: Dictionary) -> void:
	inv_ui.cancel_drag()
	var pay: Array = data["payment_origins"]
	SpellExchange.apply(inventory, int(data["source_origin"]), str(data["target"]), pay)
	exchange_ui.clear_slots()
	rescan_words()
	hud.show_toast("Tukar: %s jadi %s!" % [str(data["source_letter"]), str(data["target"])])


# ---------- kematian, drop, respawn ----------

func _on_player_died() -> void:
	if _dead:
		return
	_dead = true
	_exit_trap_place_mode()
	if inv_ui.is_open():
		close_inventory()
	player.input_enabled = false
	player.visible = false
	_drop_all_letters()
	_respawn_left = RESPAWN_TIME
	hud.show_respawn(int(RESPAWN_TIME))
	hud.show_toast("Kamu mati! Huruf jatuh semua.")


func _drop_all_letters() -> void:
	var origin: Vector2 = player.position
	for i in SpellInventory.CELLS:
		var v = inventory.grid[i]
		if v == null:
			continue
		var ang := randf() * TAU
		var dist := randf_range(60.0, 150.0)
		SpellPickup.drop(self, origin + Vector2(cos(ang), sin(ang)) * dist, str(v))
		inventory.grid[i] = null
	on_inventory_changed()


func _respawn_player() -> void:
	_dead = false
	hud.hide_respawn()
	# Bonus stat dari kata ikut hilang karena semua huruf jatuh (aturan pecah-kata).
	player.respawn_at(map.SPAWN_POS)
	_refresh_interact()


func collect_pickup(letter: String) -> void:
	if _dead:
		return
	inventory.add_letters([letter])
	rescan_words()
	hud.show_toast("Pungut: " + letter)


# ---------- interaksi & dorong ----------

func _refresh_interact() -> void:
	if ui_open or _dead:
		hud.set_interact_visible(false)
		return
	hud.set_interact_visible(true)
	if _interact_available:
		hud.set_interact_text("PUZZLE (E)")
		hud.set_interact_highlighted(true)
	elif _exchange_available:
		hud.set_interact_text("TUKAR (E)")
		hud.set_interact_highlighted(true)
	else:
		hud.set_interact_text("DORONG")
		hud.set_interact_highlighted(false)


func _on_puzzle_zone(inside: bool) -> void:
	_interact_available = inside
	_refresh_interact()


func _on_exchange_zone(inside: bool) -> void:
	_exchange_available = inside
	_refresh_interact()


func _on_interact_pressed() -> void:
	if ui_open or _dead:
		return
	if _interact_available:
		open_minigame()
	elif _exchange_available:
		open_exchange()
	else:
		_do_push()


func _do_push() -> void:
	var fwd: Vector2 = player.facing
	var best: Node2D = null
	var best_d := PUSH_RANGE
	for n in get_tree().get_nodes_in_group("damageable"):
		var nd := n as Node2D
		if nd == null or nd == player:
			continue
		if "alive" in nd and not bool(nd.get("alive")):
			continue
		var to: Vector2 = nd.global_position - player.global_position
		var d := to.length()
		if d > PUSH_RANGE or d < 1.0:
			continue
		if fwd.dot(to.normalized()) < 0.3:
			continue
		if d < best_d:
			best_d = d
			best = nd
	if best != null and best.has_method("apply_knockback"):
		best.apply_knockback(fwd, PUSH_FORCE)
		hud.show_toast("Dorong!")
	else:
		hud.show_toast("Tidak ada yang didorong.")


# ---------- dummy & debug ----------

func _spawn_test_dummies() -> void:
	# Satu diam di sudut ruang ekstraksi, satu patroli di koridor (untuk tes trap).
	SpellDummy.spawn(self, map.DUMMY_SPOT)
	SpellDummy.spawn(self, map.DUMMY_PATROL_A, map.DUMMY_PATROL_B)


func _on_debug_toggled() -> void:
	debug_panel.toggle()


func _on_debug_hurt() -> void:
	if not _dead:
		player.take_damage(50)


func _on_debug_give_letter(letter: String) -> void:
	if _dead:
		return
	inventory.add_letters([letter])
	rescan_words()
	hud.show_toast("Debug: +" + letter)


func _on_debug_spawn_dummy() -> void:
	SpellDummy.spawn(self, player.position + player.facing * 160.0)
	hud.show_toast("Debug: dummy spawn")
