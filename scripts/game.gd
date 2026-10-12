extends Node2D
## Koordinator Fase 2: model inventory, deteksi kata, efek 6 kata,
## combat (pistol/sword/trap), EP, kematian/drop/respawn,
## drawer + geser kamera, action button, debug tools.

const RESPAWN_TIME := 30.0
const PUSH_RANGE := 110.0
const PUSH_FORCE := 500.0

var inventory: SpellInventory
var active_matches: Array = []       # Array of {word, dir, cells} — untuk highlight
var _word_counts: Dictionary = {}    # word -> jumlah kemunculan aktif (stat boleh stack)
var ui_open := false

var _interact_available := false   # zona puzzle
var _exchange_available := false   # zona mesin tukar
var _exchange_open := false
var _dead := false
var _respawn_left := 0.0

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
	inv_ui.refresh(inventory, active_matches)
	hud.set_sp_indicator(0)
	_refresh_interact()


func _process(delta: float) -> void:
	if _dead:
		_respawn_left -= delta
		hud.show_respawn(maxi(int(ceil(_respawn_left)), 0))
		if _respawn_left <= 0.0:
			_respawn_player()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if not ui_open:
			_on_interact_pressed()
	elif event.is_action_pressed("ui_cancel"):
		if inv_ui.is_open():
			close_inventory()


# ---------- inventory & kata ----------

func on_inventory_changed() -> void:
	inv_ui.refresh(inventory, active_matches)
	rescan_words()


## FIX 2026-10-12 (Fix 4): kata yang sama BOLEH muncul berkali-kali
## (stat stacking). Efek diterapkan/dicabut per DELTA jumlah kemunculan.
## Senjata tetap tidak stack (diclamp ke 1).
func rescan_words() -> void:
	var matches: Array = inventory.scan_words()
	var counts: Dictionary = {}
	for m in matches:
		var w := str(m["word"])
		counts[w] = int(counts.get(w, 0)) + 1
	for w in counts.keys():
		if str(WordDB.WORDS[w]["kind"]) == "weapon":
			counts[w] = 1
	var universe: Dictionary = {}
	for w in _word_counts.keys():
		universe[w] = true
	for w in counts.keys():
		universe[w] = true
	for w in universe.keys():
		var before: int = int(_word_counts.get(w, 0))
		var after: int = int(counts.get(w, 0))
		if after > before:
			for i in range(after - before):
				_apply_word_effect(w)
		elif after < before:
			for i in range(before - after):
				_remove_word_effect(w)
	_word_counts = counts
	active_matches = matches
	inv_ui.refresh(inventory, active_matches)
	hud.set_sp_indicator(int(_word_counts.get("SP", 0)))


func _apply_word_effect(word: String) -> void:
	match word:
		"SWORD":
			hud.show_weapon("SWORD")
		"PISTOL":
			hud.show_weapon("PISTOL")
		"TRAP":
			hud.show_weapon("TRAP")
			_refresh_trap_count()
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
			_remove_player_traps()
			hud.hide_weapon("TRAP")
			_refresh_trap_count()
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
			# FIX 2026-10-12 (Fix 3): tanpa mode pasang — tap langsung
			# pasang trap di posisi kaki pemain.
			_place_trap_now()


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


# ---------- trap: pasang langsung (Fix 3, 2026-10-12) ----------
## Jumlah = MAKSIMAL trap aktif bersamaan (3), bukan amunisi.
## Trap meledak -> slot kembali, bisa pasang lagi.

func _active_trap_count() -> int:
	var c := 0
	for n in get_tree().get_nodes_in_group("trap"):
		var t := n as SpellTrap
		if t != null and t.owner_node == player and not t.is_queued_for_deletion():
			c += 1
	return c


func _refresh_trap_count() -> void:
	hud.set_trap_count(_active_trap_count(), SpellTrap.MAX_CONCURRENT)


func _on_trap_exploded(_t: SpellTrap) -> void:
	_refresh_trap_count()


func _place_trap_now() -> void:
	if _active_trap_count() >= SpellTrap.MAX_CONCURRENT:
		hud.show_toast("Trap maksimal!")
		return
	if not player.spend_ep(15):
		_ep_denied()
		return
	var t := SpellTrap.place(self, player.position, player)
	t.exploded.connect(_on_trap_exploded)
	_refresh_trap_count()
	hud.show_toast("Trap dipasang!")



# ---------- panel & drawer ----------

func open_inventory() -> void:
	if ui_open or _dead:
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
	var target := inv_ui.get_drawer_w() * 0.5 if open else 0.0
	var tw := create_tween()
	tw.tween_property(camera, "offset:x", target, 0.25).set_trans(Tween.TRANS_CUBIC)


func _refresh_weapons() -> void:
	for w in _word_counts.keys():
		if str(WordDB.WORDS[w]["kind"]) == "weapon":
			hud.show_weapon(w)
	_refresh_trap_count()


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
