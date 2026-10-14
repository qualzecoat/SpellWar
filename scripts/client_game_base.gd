class_name ClientGameBase
extends Node2D
## Lapisan "alur game" bersama untuk mode solo (game.gd) & multiplayer (mp_game.gd).
##
## Dibuat 2026-10-14 (refactor fondasi): sebelumnya kedua mode adalah dua orkestrator
## paralel yang harus di-porting manual tiap fitur -> drift & bug (respawn tak jalan di
## MP, wiring tukar huruf hilang di MP, tombol E tak ada di MP, gerak mati saat
## inventory terbuka di MP, ...).
##
## Aturan refactor:
## - SELURUH alur client yang identik tinggal di sini; subclass HANYA berisi yang
##   spesifik modenya (simulasi lokal vs netcode).
## - PERILAKU HARUS IDENTIK — ini refactor murni, bukan fitur baru (Fase 2 & 3 dikunci).
## - Subclass WAJIB mengisi referensi node di _ready() SEBELUM memanggil super._ready()
##   (path node berbeda antar scene: solo $Player vs MP $LocalVisual).

var inventory: SpellInventory
var active_matches: Array = []       # Array of {word, dir, cells} — untuk highlight
var _weapon_active_key: Dictionary = {}  # word -> key match senjata yang aktif
var _weapon_prev_keys: Dictionary = {}   # word -> Array key SEMUA match scan lalu

var ui_open := false
var _dead := false
var _exchange_open := false
var _interact_available := false   # zona puzzle
var _exchange_available := false   # zona mesin tukar
var _puzzle_cd := 0.0              # cooldown minigame per pemain (desain: 30 dtk)

# Referensi node bersama. Sengaja untyped: akses member/sinyal custom tidak
# dikenal static typing (pola yang sama dipakai game.gd sebelumnya).
var hud
var inv_ui
var minigame
var exchange_ui
var map
var camera: Camera2D


func _ready() -> void:
	inventory = SpellInventory.new()
	hud.inventory_pressed.connect(open_inventory)
	hud.weapon_pressed.connect(_on_weapon_pressed)
	hud.interact_pressed.connect(_on_interact_pressed)
	inv_ui.game = self
	inv_ui.exchange = exchange_ui
	inv_ui.closed.connect(close_inventory)
	exchange_ui.game = self
	exchange_ui.confirmed.connect(_on_exchange_confirmed)
	exchange_ui.cancelled.connect(close_exchange)
	minigame.finished.connect(_on_minigame_finished)
	inv_ui.refresh(inventory, active_matches)
	hud.set_sp_indicator(0)
	_refresh_interact()


func _unhandled_input(event: InputEvent) -> void:
	# Sama persis di kedua mode (sebelumnya duplikat di game.gd & mp_game.gd;
	# versi MP sempat tidak ada -> tombol E mati di MP).
	if event.is_action_pressed("interact"):
		if not ui_open and not _dead:
			_on_interact_pressed()
	elif event.is_action_pressed("ui_cancel"):
		if inv_ui.is_open():
			close_inventory()


# ---------- kata (seleksi stabil; efek diterapkan per mode) ----------

## Pilih kata stabil antar-scan + toast untuk duplikat senjata.
## Dipakai kedua mode. Solo lanjut terapkan efek lokal; MP lanjut kirim grid.
func _select_words() -> Array:
	var res: Dictionary = WordDB.select_stable_weapons(
		inventory.scan_words(), _weapon_active_key)
	var matches: Array = res["selected"]
	for w in res["dup_words"]:
		var prev: Array = _weapon_prev_keys.get(w, [])
		var cur: Array = res["all_keys"][w]
		var active_k := str(res["active_keys"][w])
		for k in cur:
			if str(k) != active_k and not prev.has(k):
				hud.show_toast("%s sudah aktif! Senjata tidak bisa di-stack." % w)
				break
	_weapon_active_key = res["active_keys"]
	_weapon_prev_keys = res["all_keys"]
	active_matches = matches
	return matches


# ---------- inventory: drawer ----------

func open_inventory() -> void:
	if ui_open or _dead:
		return
	ui_open = true
	# Desain: saat drawer terbuka pemain TETAP BISA GERAK, tapi tidak bisa action.
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


## Solo: tampilkan ulang senjata dari kata aktif. MP: no-op (senjata dari snapshot).
func _refresh_weapons() -> void:
	pass


func _shift_camera(open: bool) -> void:
	var target: float = inv_ui.get_drawer_w() * 0.5 if open else 0.0
	var tw := create_tween()
	tw.tween_property(camera, "offset:x", target, 0.25).set_trans(Tween.TRANS_CUBIC)


# ---------- minigame puzzle ----------

func open_minigame() -> void:
	if ui_open:
		return
	# Cooldown 30 dtk per pemain (desain) — cegah farming satu konsol.
	if _puzzle_cd > 0.0:
		hud.show_toast("Puzzle cooldown: %ds" % maxi(int(ceil(_puzzle_cd)), 1))
		return
	ui_open = true
	_set_local_input(false)
	hud.set_interact_visible(false)
	hud.set_machine_panel_open(true)  # panel di daerah joystick (touch)
	minigame.start_puzzle()


func _on_minigame_finished(success: bool) -> void:
	ui_open = false
	_set_local_input(true)
	hud.set_machine_panel_open(false)
	if success:
		_puzzle_cd = NetProto.PUZZLE_COOLDOWN
		_on_minigame_success()
	_refresh_interact()


## Solo: player.input_enabled. MP: no-op (server yang mengatur).
func _set_local_input(_enabled: bool) -> void:
	pass


## Solo: sebar hadiah huruf di tanah. MP: Net.send_puzzle_done().
func _on_minigame_success() -> void:
	pass


func _tick_puzzle_cd(delta: float) -> void:
	if _puzzle_cd > 0.0:
		_puzzle_cd = maxf(_puzzle_cd - delta, 0.0)


# ---------- mesin tukar huruf ----------

func open_exchange() -> void:
	if ui_open:
		return
	ui_open = true
	_exchange_open = true
	_set_local_input(false)
	hud.set_interact_visible(false)
	hud.set_machine_panel_open(true)
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
	_set_local_input(true)
	hud.set_machine_panel_open(false)
	_shift_camera(false)
	_sync_after_exchange()
	_refresh_interact()


## Setelah huruf kembali dari slot.
## Solo: rescan_words(). MP: on_inventory_changed() (sync grid ke server).
## Dipanggil setelah _exchange_open=false; di MP reserved=[] karena
## return_all_to_inventory() sudah clear_slots() — identik dengan urutan lama.
func _sync_after_exchange() -> void:
	pass


## Solo: terapkan tukar lokal. MP: kirim Net.send_exchange().
func _on_exchange_confirmed(_data: Dictionary) -> void:
	pass


# ---------- interaksi ----------

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


func _on_interact_pressed() -> void:
	if ui_open or _dead:
		return
	_do_interact()


## Solo: buka puzzle/exchange/dorong. MP: kirim pesan ke server.
func _do_interact() -> void:
	pass


func _on_weapon_pressed(weapon: String) -> void:
	if ui_open or _dead:
		return
	_do_weapon(weapon)


## Solo: logika senjata lokal. MP: Net.send_weapon(weapon).
func _do_weapon(_weapon: String) -> void:
	pass
