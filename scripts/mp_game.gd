extends Node2D
## Koordinator multiplayer client Fase 3.
## - Gerak/aksi dikirim sebagai input ke server; semua state gameplay
##   (posisi, HP/EP, kata/efek, senjata) datang dari snapshot server.
## - Inventory UI dipakai ulang: drag-drop lokal untuk kenyamanan,
##   grid dikirim ke server; server otoritatif (validasi permutasi huruf).
## - Panel debug MATI di mode ini (anti cheat).

@onready var map = $Map
@onready var hud = $HUD
@onready var inv_ui = $HUD/InventoryPanel
@onready var minigame = $HUD/MinigamePanel
@onready var exchange_ui = $HUD/ExchangePanel
@onready var local_visual: RemotePlayerVisual = $LocalVisual
@onready var camera = $LocalVisual/Camera2D
@onready var remotes_node = $Remotes
@onready var pickups_node = $Pickups
@onready var traps_node = $Traps
@onready var projs_node = $Projectiles

var inventory: SpellInventory
var active_matches: Array = []
var _weapon_active_key: Dictionary = {}
var _weapon_prev_keys: Dictionary = {}

var ui_open := false
var _exchange_open := false
var _dead := false
var _my_id := 0
var _my_pos := Vector2.ZERO
var _interact_available := false
var _exchange_available := false

var _remotes: Dictionary = {}   # pid -> RemotePlayerVisual
var _pickups: Dictionary = {}   # id -> Node2D
var _traps: Dictionary = {}     # id -> Node2D
var _projs: Dictionary = {}     # id -> Node2D
var _darkness: DarknessOverlay = null


func _ready() -> void:
	inventory = SpellInventory.new()
	# Panel debug MATI saat multiplayer.
	hud.get_node("DebugButton").visible = false
	hud.get_node("DebugPanel").visible = false

	local_visual.setup(Net.nickname, Net.player_id, true)

	hud.inventory_pressed.connect(open_inventory)
	hud.weapon_pressed.connect(_on_weapon_pressed)
	hud.interact_pressed.connect(_on_interact_pressed)
	inv_ui.game = self
	inv_ui.exchange = exchange_ui  # FIX 2026-10-13: tanpa ini drop huruf ke
	# slot mesin tukar/puzzle gagal diam-diam di MP (exchange == null).
	inv_ui.closed.connect(close_inventory)
	exchange_ui.game = self
	exchange_ui.confirmed.connect(_on_exchange_confirmed)
	exchange_ui.cancelled.connect(close_exchange)
	minigame.finished.connect(_on_minigame_finished)

	Net.snapshot.connect(_on_snapshot)
	Net.grid_sync.connect(_on_grid_sync)
	Net.toast_msg.connect(func(m: String) -> void: hud.show_toast(m))
	Net.panel_ok.connect(_on_panel_ok)
	Net.exchange_result.connect(_on_exchange_result)
	Net.server_disconnected.connect(_on_server_dc)

	inv_ui.refresh(inventory, active_matches)
	hud.set_sp_indicator(0)
	hud.set_hp(100, 100)
	hud.set_ep(100, 100)
	_make_darkness()
	_refresh_interact()
	if Net.last_error != "":
		hud.show_toast(Net.last_error)
		Net.last_error = ""


func _physics_process(delta: float) -> void:
	var mv := _read_input()
	# FIX 2026-10-13: inventory (drawer) saja terbuka -> gerak TETAP BOLEH
	# (desain); yang memblokir hanya: mati / mesin tukar / minigame.
	if NetProto.movement_blocked(_dead, _exchange_open, minigame.visible):
		mv = Vector2.ZERO
	Net.send_input(mv, delta)
	_update_proximity()


## FIX 2026-10-13: samakan dengan game.gd (solo) — tombol E = interact,
## Esc = tutup inventory. Sebelumnya MP tidak menangani E sama sekali.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if not ui_open and not _dead:
			_on_interact_pressed()
	elif event.is_action_pressed("ui_cancel"):
		if inv_ui.is_open():
			close_inventory()


func _read_input() -> Vector2:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var joy: Vector2 = hud.joystick.output
	if joy.length() > 0.05:
		if dir.length() < 0.05:
			dir = joy
		else:
			dir = (dir + joy).limit_length(1.0)
	return dir.limit_length(1.0)


# ---------- snapshot ----------

func _on_snapshot(s: Dictionary) -> void:
	_my_id = int(s.get("you", 0))
	var seen: Dictionary = {}
	for p in s.get("players", []):
		var d: Dictionary = p
		var pid := int(d.get("id", 0))
		seen[pid] = true
		if pid == _my_id:
			_update_self(d)
		else:
			_update_remote(pid, d)
	for pid in _remotes.keys():
		if not seen.has(pid):
			(_remotes[pid] as Node).queue_free()
			_remotes.erase(pid)
	_sync_nodes(_pickups, pickups_node, s.get("pickups", []), _make_pickup_visual)
	_sync_nodes(_traps, traps_node, s.get("traps", []), _make_trap_visual)
	_sync_nodes(_projs, projs_node, s.get("projs", []), _make_proj_visual)
	for e in s.get("ev", []):
		_handle_event(e)


func _update_self(d: Dictionary) -> void:
	_my_pos = Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
	local_visual.apply_snap(d)
	_dead = not bool(d.get("alive", true))
	hud.set_hp(int(d.get("hp", 100)), int(d.get("max_hp", 100)))
	hud.set_ep(int(d.get("ep", 100)), int(d.get("max_ep", 100)))
	hud.set_sp_indicator(int(d.get("sp", 0)))
	var words: Array = d.get("words", [])
	for w in ["SWORD", "PISTOL", "TRAP"]:
		if w in words:
			hud.show_weapon(w)
		else:
			hud.hide_weapon(w)
	hud.set_trap_count(int(d.get("traps", 0)), 3)
	if _dead:
		hud.show_respawn(int(d.get("resp", 0)))
	else:
		hud.hide_respawn()


func _update_remote(pid: int, d: Dictionary) -> void:
	var v: RemotePlayerVisual = _remotes.get(pid)
	if v == null:
		v = RemotePlayerVisual.new()
		v.setup(str(d.get("name", "?")), pid, false)
		v.position = Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
		v.target_pos = v.position
		remotes_node.add_child(v)
		_remotes[pid] = v
	v.apply_snap(d)


func _sync_nodes(cache: Dictionary, parent: Node, items: Array, maker: Callable) -> void:
	var seen: Dictionary = {}
	for it in items:
		var d: Dictionary = it
		var eid := int(d.get("id", 0))
		seen[eid] = true
		var n: Node2D = cache.get(eid)
		if n == null:
			n = maker.call(d)
			n.position = Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
			parent.add_child(n)
			cache[eid] = n
		else:
			n.position = n.position.lerp(
				Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0))), 0.5)
		if n.has_method("apply_snap"):
			n.apply_snap(d)
	for eid in cache.keys():
		if not seen.has(eid):
			(cache[eid] as Node).queue_free()
			cache.erase(eid)


func _handle_event(e: Dictionary) -> void:
	match str(e.get("k", "")):
		"dmg":
			_float_text(int(e.get("id", 0)), "-%d" % int(e.get("n", 0)),
				Color(1.0, 0.4, 0.4))
		"die":
			hud.show_toast("%s mati!" % str(e.get("name", "?")))
		"trap":
			_float_text(int(e.get("id", 0)), "TRAP!", Color(1.0, 0.7, 0.2))


func _float_text(pid: int, text: String, color: Color) -> void:
	var at := _my_pos
	if pid != _my_id and _remotes.has(pid):
		at = (_remotes[pid] as Node2D).position
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.position = at + Vector2(-20, -110)
	add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 46.0, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(l.queue_free)


# ---------- visual pickup/trap/proyektil ----------

func _make_pickup_visual(d: Dictionary) -> Node2D:
	var n := PickupVisual.new()
	n.letter = str(d.get("L", "A"))
	return n


func _make_trap_visual(d: Dictionary) -> Node2D:
	var n := TrapVisual.new()
	return n


func _make_proj_visual(d: Dictionary) -> Node2D:
	var n := ProjVisual.new()
	var dir := Vector2(float(d.get("dx", 1.0)), float(d.get("dy", 0.0)))
	n.rotation = dir.angle()
	return n


class PickupVisual extends Node2D:
	var letter := "A"
	func _ready() -> void:
		var lbl := Label.new()
		lbl.name = "Label"
		lbl.text = letter
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color(0.15, 0.10, 0.02))
		lbl.position = Vector2(-8, -16)
		add_child(lbl)
	func _draw() -> void:
		draw_rect(Rect2(-16, -16, 32, 32), Color(0.85, 0.70, 0.25))
		draw_rect(Rect2(-16, -16, 32, 32), Color(0.45, 0.32, 0.08), false, 3.0)
	func apply_snap(d: Dictionary) -> void:
		var nl := str(d.get("L", "A"))
		if nl != letter:
			letter = nl
			($Label as Label).text = letter
			queue_redraw()


class TrapVisual extends Node2D:
	func _draw() -> void:
		for i in 12:
			var a := TAU * i / 12.0
			var dir := Vector2(cos(a), sin(a))
			draw_line(dir * 22.0, dir * 34.0, Color(0.95, 0.25, 0.2), 6.0)
		draw_circle(Vector2.ZERO, 22.0, Color(0.45, 0.10, 0.10))
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, Color(0.95, 0.35, 0.3), 3.0)
	func apply_snap(d: Dictionary) -> void:
		modulate.a = 1.0 if bool(d.get("armed", true)) else 0.5


class ProjVisual extends Node2D:
	func _ready() -> void:
		z_index = 2
		var dot := Polygon2D.new()
		dot.polygon = PackedVector2Array([
			Vector2(14, 0), Vector2(-10, 7), Vector2(-10, -7)])
		dot.color = Color(1.0, 0.85, 0.25)
		add_child(dot)
	func apply_snap(_d: Dictionary) -> void:
		pass


# ---------- inventory (dipakai ulang UI-nya) ----------

func on_inventory_changed() -> void:
	# Highlight lokal instan (visual saja); efek gameplay dari server.
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
	inv_ui.refresh(inventory, active_matches)
	Net.send_grid(inventory.grid)


func _on_grid_sync(cells: Array, note: String) -> void:
	if cells.size() != SpellInventory.CELLS:
		return
	inv_ui.cancel_drag()
	for i in SpellInventory.CELLS:
		var v = cells[i]
		inventory.grid[i] = str(v) if v != null else null
	if _exchange_open:
		# Hasil tukar dari server: slot dibersihkan (sudah dihitung server).
		exchange_ui.clear_slots()
	on_inventory_changed_silent()
	if note != "":
		hud.show_toast(note)


func on_inventory_changed_silent() -> void:
	var res: Dictionary = WordDB.select_stable_weapons(
		inventory.scan_words(), _weapon_active_key)
	_weapon_active_key = res["active_keys"]
	_weapon_prev_keys = res["all_keys"]
	active_matches = res["selected"]
	inv_ui.refresh(inventory, active_matches)


# ---------- panel & drawer (mirror game.gd) ----------

func open_inventory() -> void:
	if ui_open or _dead:
		return
	ui_open = true
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
	_refresh_interact()


func _shift_camera(open: bool) -> void:
	var target: float = inv_ui.get_drawer_w() * 0.5 if open else 0.0
	var tw := create_tween()
	tw.tween_property(camera, "offset:x", target, 0.25).set_trans(Tween.TRANS_CUBIC)


func open_minigame() -> void:
	if ui_open:
		return
	ui_open = true
	hud.set_interact_visible(false)
	hud.set_machine_panel_open(true)
	minigame.start_puzzle()


func _on_minigame_finished(success: bool) -> void:
	ui_open = false
	hud.set_machine_panel_open(false)
	if success:
		Net.send_puzzle_done()
	_refresh_interact()


func open_exchange() -> void:
	if ui_open:
		return
	ui_open = true
	_exchange_open = true
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
	# FIX 2026-10-13: huruf yang kembali ke inventory harus di-sync ke server
	# (sebelumnya desync: server tetap menganggap huruf di slot sudah hangus).
	on_inventory_changed()
	exchange_ui.close_panel()
	inv_ui.close_panel()
	_exchange_open = false
	ui_open = false
	hud.set_machine_panel_open(false)
	_shift_camera(false)
	_refresh_interact()


func _on_exchange_confirmed(data: Dictionary) -> void:
	inv_ui.cancel_drag()
	var pay: Array = data["payment_origins"]
	# Validasi & aplikasi di server; grid otoritatif datang via grid_sync.
	Net.send_exchange(int(data["source_origin"]), str(data["target"]),
		str(data["source_letter"]), pay)


func _on_exchange_result(ok: bool, msg: String) -> void:
	hud.show_toast(msg)


func _on_panel_ok(kind: String) -> void:
	if kind == "puzzle":
		open_minigame()
	elif kind == "exchange":
		open_exchange()


# ---------- aksi ----------

func _on_weapon_pressed(weapon: String) -> void:
	if ui_open or _dead:
		return
	Net.send_weapon(weapon)


func _update_proximity() -> void:
	if ui_open or _dead:
		return
	var dp := _my_pos.distance_to(map.PUZZLE_POS)
	var de := _my_pos.distance_to(map.EXCHANGE_POS)
	var show_puzzle := dp < 150.0
	var show_exch := de < 150.0 and not show_puzzle
	if show_puzzle != _interact_available or show_exch != _exchange_available:
		_interact_available = show_puzzle
		_exchange_available = show_exch
		_refresh_interact()


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
	if _interact_available:
		Net.send_interact_puzzle()
	elif _exchange_available:
		Net.send_interact_exchange()
	else:
		Net.send_push()


func _on_server_dc() -> void:
	Net.last_error = "Koneksi ke server putus."
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


# ---------- kegelapan ala Among Us ----------

func _make_darkness() -> void:
	# Overlay full-screen via shader (scripts/darkness_overlay.gd +
	# shaders/darkness.gdshader). Menggantikan Sprite2D radial lama yang
	# hanya menggelapkan kotak di tengah layar. Overlay melacak posisi
	# screen pemain sendiri tiap frame (lihat DarknessOverlay._process).
	_darkness = DarknessOverlay.new()
	_darkness.setup(local_visual)
	add_child(_darkness)
