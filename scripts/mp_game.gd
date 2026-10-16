extends ClientGameBase
## Koordinator multiplayer client Fase 3.
## - Gerak/aksi dikirim sebagai input ke server; semua state gameplay
##   (posisi, HP/EP, kata/efek, senjata) datang dari snapshot server.
## - Inventory UI dipakai ulang: drag-drop lokal untuk kenyamanan,
##   grid dikirim ke server; server otoritatif (validasi permutasi huruf).
## - Panel debug MATI di mode ini (anti cheat).
## Seluruh alur umum (input, inventory/drawer, minigame, mesin tukar, interaksi,
## kamera) diwarisi dari ClientGameBase. File ini HANYA berisi netcode & visual.

@onready var local_visual: RemotePlayerVisual = $LocalVisual
@onready var remotes_node = $Remotes
@onready var pickups_node = $Pickups
@onready var traps_node = $Traps
@onready var projs_node = $Projectiles

var _my_id := 0
var _my_pos := Vector2.ZERO

var _remotes: Dictionary = {}   # pid -> RemotePlayerVisual
var _pickups: Dictionary = {}   # id -> Node2D
var _traps: Dictionary = {}     # id -> Node2D
var _projs: Dictionary = {}     # id -> Node2D
var _darkness: DarknessOverlay = null


func _ready() -> void:
	hud = $HUD
	inv_ui = $HUD/InventoryPanel
	minigame = $HUD/MinigamePanel
	exchange_ui = $HUD/ExchangePanel
	map = $Map
	camera = $LocalVisual/Camera2D
	super._ready()
	# --- khusus MP ---
	# Panel debug MATI saat multiplayer.
	hud.get_node("DebugButton").visible = false
	hud.get_node("DebugPanel").visible = false

	local_visual.setup(Net.nickname, Net.player_id, true)

	Net.snapshot.connect(_on_snapshot)
	Net.grid_sync.connect(_on_grid_sync)
	Net.toast_msg.connect(func(m: String) -> void: hud.show_toast(m))
	Net.panel_ok.connect(_on_panel_ok)
	Net.exchange_result.connect(_on_exchange_result)
	Net.server_disconnected.connect(_on_server_dc)

	hud.set_hp(100, 100)
	hud.set_ep(100, 100)
	_make_darkness()
	if Net.last_error != "":
		hud.show_toast(Net.last_error)
		Net.last_error = ""


func _physics_process(delta: float) -> void:
	var mv := _read_input()
	# Inventory (drawer) saja terbuka -> gerak TETAP BOLEH (desain);
	# yang memblokir hanya: mati / mesin tukar / minigame.
	if NetProto.movement_blocked(_dead, _exchange_open, minigame.visible):
		mv = Vector2.ZERO
	Net.send_input(mv, delta)
	_tick_puzzle_cd(delta)
	_update_proximity()


func _read_input() -> Vector2:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var joy: Vector2 = hud.joystick.output
	if joy.length() > 0.05:
		if dir.length() < 0.05:
			dir = joy
		else:
			dir = (dir + joy).limit_length(1.0)
	return dir.limit_length(1.0)


# ---------- override hook base ----------

func _on_minigame_success() -> void:
	Net.send_puzzle_done(_interact_machine_idx)


func _sync_after_exchange() -> void:
	# Huruf yang kembali ke inventory harus di-sync ke server
	# (sebelumnya desync: server tetap menganggap huruf di slot sudah hangus).
	on_inventory_changed()


func _do_interact() -> void:
	if _interact_available:
		Net.send_interact_puzzle(_interact_machine_idx)
	elif _exchange_available:
		Net.send_interact_exchange()
	else:
		Net.send_push()


func _do_weapon(weapon: String) -> void:
	Net.send_weapon(weapon)


func _on_exchange_confirmed(data: Dictionary) -> void:
	inv_ui.cancel_drag()
	var pay: Array = data["payment_origins"]
	# Validasi & aplikasi di server; grid otoritatif datang via grid_sync.
	Net.send_exchange(int(data["source_origin"]), str(data["target"]),
		str(data["source_letter"]), pay)


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
	if _dead and _exchange_open:
		close_exchange()  # seperti solo: mati -> panel mesin ditutup
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
		"sword":
			_play_swing(int(e.get("id", 0)))


## Visual ayunan pedang (paritas dengan solo: player.swing_sword()).
## Server mengirim event "sword" agar semua client me-render-nya.
func _play_swing(pid: int) -> void:
	var v: RemotePlayerVisual = null
	if pid == _my_id:
		v = local_visual
	else:
		v = _remotes.get(pid)
	if v != null:
		v.play_swing()


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
	_select_words()
	inv_ui.refresh(inventory, active_matches)
	# Kirim tampilan grid yang slot-aware — huruf yang reserved di slot
	# exchange dikembalikan ke originnya, sehingga server selalu melihat
	# permutasi valid dan tidak pernah me-reject.
	Net.send_grid(SpellInventory.reserved_grid_view(inventory.grid,
		exchange_ui.get_reserved() if _exchange_open else []))


func _on_grid_sync(cells: Array, note: String, exchanged: bool) -> void:
	if cells.size() != SpellInventory.CELLS:
		return
	inv_ui.cancel_drag()
	if exchanged:
		exchange_ui.apply_server_result(inventory, cells)
	else:
		# Grid biasa (pickup/dll): pertahankan lubang huruf yang reserved
		# di slot exchange agar tidak duplikat dengan grid lokal.
		var reserved := {}
		if _exchange_open:
			for r in exchange_ui.get_reserved():
				reserved[int((r as Dictionary)["origin"])] = true
		var server_count := 0
		for v in cells:
			if v != null:
				server_count += 1
		if server_count < reserved.size():
			# State rusak (mis. mati saat panel terbuka): reset penuh.
			exchange_ui.clear_slots()
			reserved.clear()
		for i in SpellInventory.CELLS:
			if reserved.has(i):
				continue
			var v2 = cells[i]
			inventory.grid[i] = str(v2) if v2 != null else null
	on_inventory_changed_silent()
	if note != "":
		hud.show_toast(note)


func on_inventory_changed_silent() -> void:
	_select_words()
	inv_ui.refresh(inventory, active_matches)


# ---------- proximity mesin ----------

func _update_proximity() -> void:
	if ui_open or _dead:
		return
	var found := -1
	for i in Map3B.PUZZLE_INTERACT.size():
		var r: Rect2 = Map3B.PUZZLE_INTERACT[i]
		if r.has_point(_my_pos):
			found = i
			break
	var de := _my_pos.distance_to(map.EXCHANGE_POS)
	var show_puzzle := found >= 0
	var show_exch := de < 150.0 and not show_puzzle
	if found != _interact_machine_idx or show_puzzle != _interact_available or show_exch != _exchange_available:
		_interact_machine_idx = found
		_interact_available = show_puzzle
		_exchange_available = show_exch
		_refresh_interact()


func _on_server_dc() -> void:
	Net.last_error = "Koneksi ke server putus."
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


# ---------- kegelapan ala Among Us ----------

func _make_darkness() -> void:
	# Overlay full-screen via shader (scripts/darkness_overlay.gd +
	# shaders/darkness.gdshader). Overlay melacak posisi screen pemain
	# sendiri tiap frame (lihat DarknessOverlay._process).
	_darkness = DarknessOverlay.new()
	_darkness.setup(local_visual)
	add_child(_darkness)


# ---------- panel hasil ----------

func _on_exchange_result(ok: bool, msg: String) -> void:
	hud.show_toast(msg)


func _on_panel_ok(kind: String) -> void:
	if kind == "puzzle":
		open_minigame()
	elif kind == "exchange":
		open_exchange()
