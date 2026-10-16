extends ClientGameBase
## Mode solo (Main Sendiri): simulasi lokal penuh + training dummy + panel debug.
## Seluruh alur umum (input, inventory/drawer, minigame, mesin tukar, interaksi,
## kamera) diwarisi dari ClientGameBase. File ini HANYA berisi yang spesifik solo.

var _word_counts: Dictionary = {}    # word -> jumlah kemunculan aktif (stat boleh stack)
var _respawn_left := 0.0

# Sengaja untyped: akses member/sinyal custom tidak dikenal static typing base class.
@onready var player = $Player
@onready var debug_panel = $HUD/DebugPanel


func _ready() -> void:
	hud = $HUD
	inv_ui = $HUD/InventoryPanel
	minigame = $HUD/MinigamePanel
	exchange_ui = $HUD/ExchangePanel
	map = $Map
	camera = $Player/Camera2D
	super._ready()
	# 3b2: random spawn di salah satu dari 8 area resmi.
	player.position = Map3B.random_spawn()
	# --- khusus solo ---
	player.joystick = hud.joystick
	player.hp_changed.connect(_on_hp_changed)
	player.ep_changed.connect(_on_ep_changed)
	player.died.connect(_on_player_died)
	hud.debug_toggled.connect(_on_debug_toggled)
	# 3b1: zona mesin belum ada (baru 3b3/3b4) — connect dipindah ke sana.
	debug_panel.hurt_self_pressed.connect(_on_debug_hurt)
	debug_panel.give_letter_pressed.connect(_on_debug_give_letter)
	debug_panel.spawn_dummy_pressed.connect(_on_debug_spawn_dummy)
	_on_hp_changed(player.hp, player.max_hp)
	_on_ep_changed(player.ep, player.max_ep)
	_spawn_test_dummies()


func _process(delta: float) -> void:
	_tick_puzzle_cd(delta)
	_update_proximity()
	if _dead:
		_respawn_left -= delta
		hud.show_respawn(maxi(int(ceil(_respawn_left)), 0))
		if _respawn_left <= 0.0:
			_respawn_player()


# ---------- override hook base ----------

func _set_local_input(enabled: bool) -> void:
	player.input_enabled = enabled


func _on_minigame_success() -> void:
	_scatter_puzzle_reward(_interact_machine_idx)


func _sync_after_exchange() -> void:
	rescan_words()


func _refresh_weapons() -> void:
	for w in _word_counts.keys():
		if str(WordDB.WORDS[w]["kind"]) == "weapon":
			hud.show_weapon(w)
	_refresh_trap_count()


func _do_interact() -> void:
	if _interact_available:
		open_minigame()
	elif _exchange_available:
		open_exchange()
	elif _extract_available:
		# 3b4: logika ekstraksi = Fase 4+. Untuk sekarang tampilkan toast.
		hud.show_toast("Mesin ekstraksi segera hadir (Fase 4)!")
	else:
		_do_push()


func _do_weapon(weapon: String) -> void:
	if not player.alive:
		return
	match weapon:
		"SWORD":
			if not player.spend_ep(NetProto.SWORD_EP_COST):
				_ep_denied()
				return
			player.clear_protection()  # menyerang = proteksi hilang
			player.swing_sword()
			_melee_damage(NetProto.SWORD_DAMAGE)
		"PISTOL":
			if not player.spend_ep(NetProto.PISTOL_EP_COST):
				_ep_denied()
				return
			player.clear_protection()
			SpellProjectile.spawn(self, player.position, player.facing, player)
		"TRAP":
			# Tanpa mode pasang — tap langsung pasang trap di posisi kaki pemain.
			_place_trap_now()


func _on_exchange_confirmed(data: Dictionary) -> void:
	inv_ui.cancel_drag()
	var pay: Array = data["payment_origins"]
	SpellExchange.apply(inventory, int(data["source_origin"]), str(data["target"]), pay)
	exchange_ui.clear_slots()
	rescan_words()
	hud.show_toast("Tukar: %s jadi %s!" % [str(data["source_letter"]), str(data["target"])])


# ---------- inventory & kata (simulasi lokal) ----------

func on_inventory_changed() -> void:
	inv_ui.refresh(inventory, active_matches)
	rescan_words()


## Kata yang sama BOLEH muncul berkali-kali (stat stacking).
## Efek diterapkan/dicabut per DELTA jumlah kemunculan. Senjata tetap tidak stack —
## hanya match PERTAMA tiap kata weapon yang aktif (stabil antar-scan).
func rescan_words() -> void:
	var matches: Array = _select_words()
	var counts: Dictionary = {}
	for m in matches:
		var w := str(m["word"])
		counts[w] = int(counts.get(w, 0)) + 1
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
			player.set_max_hp(player.max_hp + NetProto.WORD_HP_MAX_BONUS)
			player.heal(NetProto.WORD_HP_HEAL)
		"EP":
			player.set_max_ep(player.max_ep + NetProto.WORD_EP_MAX_BONUS)
			player.add_ep_regen(NetProto.WORD_EP_REGEN_BONUS)
		"SP":
			# ADITIF — 1x=15%, 2x=30%, 3x=45%
			# (konsisten dengan HP +50/stack & EP +2 regen/stack).
			player.speed_mult += NetProto.WORD_SP_BONUS
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
			player.set_max_hp(player.max_hp - NetProto.WORD_HP_MAX_BONUS)
		"EP":
			player.set_max_ep(player.max_ep - NetProto.WORD_EP_MAX_BONUS)
			player.add_ep_regen(-NetProto.WORD_EP_REGEN_BONUS)
		"SP":
			player.speed_mult -= NetProto.WORD_SP_BONUS
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
		if to.length() > NetProto.MELEE_RANGE:
			continue
		if fwd.dot(to.normalized()) < 0.35:
			continue
		nd.take_damage(amount)


# ---------- trap: pasang langsung ----------
## Jumlah = MAKSIMAL trap aktif bersamaan, bukan amunisi.
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
	if not player.spend_ep(NetProto.TRAP_EP_COST):
		_ep_denied()
		return
	var t := SpellTrap.place(self, player.position, player)
	t.exploded.connect(_on_trap_exploded)
	_refresh_trap_count()
	player.clear_protection()  # menyerang = proteksi hilang
	hud.show_toast("Trap dipasang!")


# ---------- hadiah puzzle buyar ----------

# Hadiah puzzle TIDAK langsung masuk inventory — 5 huruf TERSEBAR di tanah
# sekitar konsol sebagai pickup. Pemain harus berjalan memungutnya.
func _scatter_puzzle_reward(machine_idx: int) -> void:
	var center: Vector2 = Map3B.PUZZLE_POS[machine_idx]
	for i in 5:
		var letter := String.chr(randi_range(65, 90))
		# Containment 3b1: huruf tidak boleh buyar di dalam tembok.
		var at := MapData.random_walkable_near(center,
			NetProto.SCATTER_REWARD_MIN, NetProto.SCATTER_REWARD_MAX)
		SpellPickup.drop(self, at, letter)
	hud.show_toast("Puzzle selesai! Pungut 5 huruf yang buyar!")


# ---------- zona interaksi 3b3 ----------

# Cek area interaksi mesin (Rect2). Dipanggil tiap frame.
# Prioritas: puzzle > tukar > ekstraksi.
func _update_proximity() -> void:
	if ui_open or _dead:
		return
	var found := -1
	for i in Map3B.PUZZLE_INTERACT.size():
		var r: Rect2 = Map3B.PUZZLE_INTERACT[i]
		if r.has_point(player.position):
			found = i
			break
	var show_exch := false
	if found < 0:
		for i in Map3B.EXCHANGE_INTERACT.size():
			var r: Rect2 = Map3B.EXCHANGE_INTERACT[i]
			if r.has_point(player.position):
				show_exch = true
				break
	var show_extr := false
	if found < 0 and not show_exch:
		for i in Map3B.EXTRACT_INTERACT.size():
			var r: Rect2 = Map3B.EXTRACT_INTERACT[i]
			if r.has_point(player.position):
				show_extr = true
				break
	if found != _interact_machine_idx or show_exch != _exchange_available or show_extr != _extract_available:
		_interact_machine_idx = found
		_interact_available = found >= 0
		_exchange_available = show_exch
		_extract_available = show_extr
		_refresh_interact()


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
	_respawn_left = NetProto.RESPAWN_TIME
	hud.show_respawn(int(NetProto.RESPAWN_TIME))
	hud.show_toast("Kamu mati! Huruf jatuh semua.")


func _drop_all_letters() -> void:
	var origin: Vector2 = player.position
	for i in SpellInventory.CELLS:
		var v = inventory.grid[i]
		if v == null:
			continue
		# Containment 3b1: huruf tidak boleh jatuh di dalam tembok.
		var at := MapData.random_walkable_near(origin,
			NetProto.SCATTER_DEATH_MIN, NetProto.SCATTER_DEATH_MAX)
		SpellPickup.drop(self, at, str(v))
		inventory.grid[i] = null
	on_inventory_changed()


func _respawn_player() -> void:
	_dead = false
	hud.hide_respawn()
	# Bonus stat dari kata ikut hilang karena semua huruf jatuh (aturan pecah-kata).
	player.respawn_at(Map3B.random_spawn())
	_refresh_interact()


func collect_pickup(letter: String) -> void:
	if _dead:
		return
	inventory.add_letters([letter])
	rescan_words()
	hud.show_toast("Pungut: " + letter)


# ---------- zona interaksi ----------

func _on_puzzle_zone(inside: bool) -> void:
	_interact_available = inside
	_refresh_interact()


func _on_exchange_zone(inside: bool) -> void:
	_exchange_available = inside
	_refresh_interact()


# ---------- dorong ----------

func _do_push() -> void:
	var fwd: Vector2 = player.facing
	var best: Node2D = null
	var best_d := NetProto.PUSH_RANGE
	for n in get_tree().get_nodes_in_group("damageable"):
		var nd := n as Node2D
		if nd == null or nd == player:
			continue
		if "alive" in nd and not bool(nd.get("alive")):
			continue
		var to: Vector2 = nd.global_position - player.global_position
		var d := to.length()
		if d > NetProto.PUSH_RANGE or d < 1.0:
			continue
		if fwd.dot(to.normalized()) < 0.3:
			continue
		if d < best_d:
			best_d = d
			best = nd
	if best != null and best.has_method("apply_knockback"):
		player.clear_protection()  # menyerang = proteksi hilang
		best.apply_knockback(fwd, NetProto.PUSH_FORCE)
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
