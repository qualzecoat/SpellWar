extends Node2D
## Dedicated server SpellWar Fase 3 — WebSocket, authoritative.
## Dijalankan via binary Linux headless: ./server --headless -- --server
## (menu.gd mengalihkan ke scenes/server_main.tscn).
##
## Tanggung jawab: room/lobby, simulasi fisika pemain, combat, pickup,
## jebakan, proyektil, kata/efek, respawn, reconnect 90 detik.
## Client tidak dipercaya — semua divalidasi wajar di sini.
## Geometri map: scenes/map_3b.tscn (di-instance via server_main.tscn);
## konstanta map via class Map3B (scripts/map_3b.gd).


class Room:
	var code := ""
	var host_id := 0
	var started := false
	var players: Dictionary = {}  # pid -> ServerPlayer
	var next_pid := 1
	var pickups: Array = []       # {id, letter, pos}
	var traps: Array = []         # {id, owner, pos, arm_left}
	var projs: Array = []         # {id, pos, dir, traveled, shooter}
	var events: Array = []        # [{k,...}] — dikosongkan tiap snapshot
	var next_ent := 1
	var tick := 0


var _tcp := TCPServer.new()
var _pending: Array = []   # {ws: WebSocketPeer, t: float} — handshake/hello
var _conns: Array = []     # {ws: WebSocketPeer, room: Room, pid: int}
var _rooms: Dictionary = {}  # code -> Room
var _players_node: Node2D = null
var _snap_acc := 0.0


func _ready() -> void:
	# Node Map (map_3b.tscn) sudah ada di server_main.tscn — collision dinding
	# dipakai simulasi fisika server (move_and_slide).
	_players_node = Node2D.new()
	_players_node.name = "Players"
	add_child(_players_node)
	var err := _tcp.listen(NetProto.SERVER_PORT)
	if err != OK:
		push_error("[server] listen gagal: %s" % err)
	else:
		print("[server] listen 0.0.0.0:%d" % NetProto.SERVER_PORT)


# ---------- koneksi ----------

func _process(delta: float) -> void:
	while _tcp.is_connection_available():
		var ws := WebSocketPeer.new()
		ws.accept_stream(_tcp.take_connection())
		_pending.append({"ws": ws, "t": 0.0})
	# Pending: tunggu handshake + hello (timeout 15 dtk).
	for i in range(_pending.size() - 1, -1, -1):
		var p: Dictionary = _pending[i]
		var ws: WebSocketPeer = p["ws"]
		ws.poll()
		p["t"] = float(p["t"]) + delta
		var st := ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			var got_hello := false
			for m in _read_ws(ws):
				if str(m.get("t", "")) == "hello":
					_handle_hello(ws, m)
					got_hello = true
			if got_hello:
				_pending.remove_at(i)
		elif st == WebSocketPeer.STATE_CLOSED or float(p["t"]) > 15.0:
			ws.close()
			_pending.remove_at(i)
	# Koneksi aktif.
	for i in range(_conns.size() - 1, -1, -1):
		var c: Dictionary = _conns[i]
		var ws: WebSocketPeer = c["ws"]
		ws.poll()
		if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_on_disconnect(c)
			_conns.remove_at(i)
			continue
		if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
			continue
		for m in _read_ws(ws):
			_handle(c, m)
	# Broadcast snapshot.
	_snap_acc += delta
	if _snap_acc >= 1.0 / NetProto.SNAP_HZ:
		_snap_acc = 0.0
		for code in _rooms.keys():
			_broadcast(_rooms[code])


func _read_ws(ws: WebSocketPeer) -> Array:
	var out: Array = []
	while ws.get_available_packet_count() > 0:
		var pkt := ws.get_packet()
		if ws.was_string_packet():
			var m := NetProto.parse(pkt.get_string_from_utf8())
			if not m.is_empty():
				out.append(m)
	return out


func _send(ws: WebSocketPeer, msg_type: String, data: Dictionary = {}) -> void:
	if ws == null:
		return
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(NetProto.msg(msg_type, data))


func _conn_of(room: Room, pid: int) -> Dictionary:
	for c in _conns:
		var cc: Dictionary = c
		if cc["room"] == room and int(cc["pid"]) == pid:
			return cc
	return {}


# ---------- hello / room ----------

func _handle_hello(ws: WebSocketPeer, m: Dictionary) -> void:
	print("[server] hello diterima: %s" % JSON.stringify(m).left(120))
	if str(m.get("t", "")) != "hello":
		return
	var name := str(m.get("name", "")).strip_edges().left(16)
	var mode := str(m.get("mode", "join"))
	if name == "":
		_send(ws, "hello_err", {"msg": "Nama kosong."})
		ws.close()
		return
	if mode == "create":
		var code := NetProto.make_room_code()
		while _rooms.has(code):
			code = NetProto.make_room_code()
		var room := Room.new()
		room.code = code
		_rooms[code] = room
		_add_player(ws, room, name)
		print("[server] room %s dibuat oleh %s" % [code, name])
	else:
		var code := str(m.get("room", "")).strip_edges().to_upper()
		if not _rooms.has(code):
			_send(ws, "hello_err", {"msg": "Kode room tidak ditemukan."})
			ws.close()
			return
		var room: Room = _rooms[code]
		if room.started:
			# Reconnect? nickname cocok dengan yang disconnect < 90 dtk.
			for pid in room.players.keys():
				var p: ServerPlayer = room.players[pid]
				if p.player_name == name and p.disconnected and p.dc_left > 0.0:
					p.peer = ws
					p.disconnected = false
					p.dc_left = 0.0
					_conns.append({"ws": ws, "room": room, "pid": pid})
					_send(ws, "hello_ok", {"id": pid, "room": code,
						"host": room.host_id, "reconnected": true})
					_send_grid(room, p, "Reconnect berhasil!")
					_broadcast(room)
					print("[server] %s reconnect ke room %s" % [name, code])
					return
			_send(ws, "hello_err", {"msg": "Match sudah mulai."})
			ws.close()
			return
		_add_player(ws, room, name)


func _add_player(ws: WebSocketPeer, room: Room, pname: String) -> void:
	for pid in room.players.keys():
		var p: ServerPlayer = room.players[pid]
		if p.player_name == pname and not p.disconnected:
			_send(ws, "hello_err", {"msg": "Nama sudah dipakai di room ini."})
			ws.close()
			return
	if room.players.size() >= NetProto.MAX_PLAYERS:
		_send(ws, "hello_err", {"msg": "Room penuh (8 pemain)."})
		ws.close()
		return
	var pid: int = room.next_pid
	room.next_pid += 1
	var pl := ServerPlayer.new()
	pl.pid = pid
	pl.player_name = pname
	pl.peer = ws
	room.players[pid] = pl
	_players_node.add_child(pl)
	if room.host_id == 0:
		room.host_id = pid
	_conns.append({"ws": ws, "room": room, "pid": pid})
	_send(ws, "hello_ok", {"id": pid, "room": room.code, "host": room.host_id})
	_broadcast_lobby(room)
	print("[server] %s join room %s (pid %d)" % [pname, room.code, pid])


func _on_disconnect(c: Dictionary) -> void:
	var room: Room = c["room"]
	var pid: int = int(c["pid"])
	if not room.players.has(pid):
		return
	var p: ServerPlayer = room.players[pid]
	p.peer = null
	if not room.started:
		# Lobby: langsung keluarkan.
		room.players.erase(pid)
		p.queue_free()
		if room.players.is_empty():
			_rooms.erase(room.code)
			print("[server] room %s dihapus (kosong)" % room.code)
		else:
			if room.host_id == pid:
				room.host_id = int(room.players.keys()[0])
			_broadcast_lobby(room)
	else:
		# Match: masa tenggang reconnect 90 dtk — diam + kebal.
		p.disconnected = true
		p.dc_left = NetProto.RECONNECT_TIME
		p.input_vec = Vector2.ZERO
		_broadcast(room)
		print("[server] %s disconnect, tenggang 90 dtk" % p.player_name)


func _broadcast_lobby(room: Room) -> void:
	if room.started:
		return
	var list: Array = []
	for pid in room.players.keys():
		var p: ServerPlayer = room.players[pid]
		if not p.disconnected:
			list.append({"id": pid, "name": p.player_name})
	for c in _conns:
		var cc: Dictionary = c
		if cc["room"] == room:
			_send(cc["ws"], "lobby", {"players": list, "host": room.host_id,
				"code": room.code})


# ---------- pesan game ----------

func _handle(c: Dictionary, m: Dictionary) -> void:
	var room: Room = c["room"]
	var pid: int = int(c["pid"])
	if not room.players.has(pid):
		return
	var p: ServerPlayer = room.players[pid]
	var t := str(m.get("t", ""))
	match t:
		"start":
			_on_start(room, p)
		"input":
			var mv: Array = m.get("mv", [0, 0])
			var v := Vector2(float(mv[0]), float(mv[1]))
			p.input_vec = v.limit_length(1.0)
		"grid":
			_on_grid(room, p, m)
		"use_weapon":
			_on_weapon(room, p, str(m.get("w", "")))
		"push":
			_on_push(room, p)
		"interact_puzzle":
			var mid := int(m.get("machine", -1))
			if _can_use_puzzle(room, p, mid):
				_send(p.peer, "panel_ok", {"kind": "puzzle"})
		"puzzle_done":
			_on_puzzle_done(room, p, int(m.get("machine", -1)))
		"interact_exchange":
			if p.position.distance_to(Map3B.EXCHANGE_POS) < 220.0:
				_send(p.peer, "panel_ok", {"kind": "exchange"})
		"exchange_do":
			_on_exchange(room, p, m)
		"ping":
			_send(p.peer, "pong", {})


func _on_start(room: Room, p: ServerPlayer) -> void:
	if room.started:
		return
	if p.pid != room.host_id:
		return
	var connected := 0
	for pid in room.players.keys():
		if not (room.players[pid] as ServerPlayer).disconnected:
			connected += 1
	if connected < NetProto.MIN_PLAYERS:
		_send(p.peer, "toast", {"msg": "Butuh minimal 2 pemain untuk mulai."})
		return
	# Assign spawn slot acak.
	var slots: Array = NetProto.SPAWN_SLOTS.duplicate()
	slots.shuffle()
	var i := 0
	for pid in room.players.keys():
		var pl: ServerPlayer = room.players[pid]
		pl.spawn_slot = i % slots.size()
		pl.position = slots[pl.spawn_slot]
		pl.spawn_pos = pl.position
		pl.hp = pl.max_hp
		pl.ep = pl.max_ep
		pl.alive = true
		pl.facing = Vector2.RIGHT
		i += 1
	room.started = true
	room.tick = 0
	for c in _conns:
		var cc: Dictionary = c
		if cc["room"] == room:
			_send(cc["ws"], "start", {})
			var pl2: ServerPlayer = room.players[int(cc["pid"])]
			_send_grid(room, pl2, "")
	print("[server] room %s MULAI (%d pemain)" % [room.code, connected])


func _on_grid(room: Room, p: ServerPlayer, m: Dictionary) -> void:
	var cells: Array = m.get("cells", [])
	if not p.grid_is_permutation(cells):
		_send_grid(room, p, "")  # tolak: kembalikan grid otoritatif
		return
	p.inv.grid = cells.duplicate()
	p.recompute_words()


func _send_grid(room: Room, p: ServerPlayer, note: String, exchanged: bool = false) -> void:
	var c := _conn_of(room, p.pid)
	if c.is_empty():
		return
	_send(c["ws"], "grid", {"cells": p.inv.grid.duplicate(), "note": note,
		"ex": exchanged})


func _on_weapon(room: Room, p: ServerPlayer, w: String) -> void:
	if not room.started or not p.alive or p.disconnected:
		return
	match w:
		"SWORD":
			if not ("SWORD" in p.words):
				return
			if not p.spend_ep(NetProto.SWORD_EP_COST):
				_send(p.peer, "toast", {"msg": "EP tidak cukup!"})
				return
			p.clear_protection()
			_melee(room, p, NetProto.SWORD_DAMAGE, NetProto.MELEE_RANGE)
			room.events.append({"k": "sword", "id": p.pid})
		"PISTOL":
			if not ("PISTOL" in p.words):
				return
			if not p.spend_ep(NetProto.PISTOL_EP_COST):
				_send(p.peer, "toast", {"msg": "EP tidak cukup!"})
				return
			p.clear_protection()
			room.projs.append({"id": room.next_ent,
				"pos": p.position + p.facing * 40.0, "dir": p.facing,
				"traveled": 0.0, "shooter": p.pid})
			room.next_ent += 1
		"TRAP":
			if not ("TRAP" in p.words):
				return
			var owned := 0
			for t in room.traps:
				if int(t["owner"]) == p.pid:
					owned += 1
			if owned >= NetProto.TRAP_MAX:
				_send(p.peer, "toast", {"msg": "Trap maksimal!"})
				return
			if not p.spend_ep(NetProto.TRAP_EP_COST):
				_send(p.peer, "toast", {"msg": "EP tidak cukup!"})
				return
			p.clear_protection()
			room.traps.append({"id": room.next_ent, "owner": p.pid,
				"pos": p.position, "arm_left": NetProto.TRAP_ARM_TIME})
			room.next_ent += 1
			_send(p.peer, "toast", {"msg": "Trap dipasang!"})


func _melee(room: Room, attacker: ServerPlayer, dmg: int, radius: float) -> void:
	for pid in room.players.keys():
		var q: ServerPlayer = room.players[pid]
		if q == attacker or not q.alive or q.disconnected:
			continue
		var to: Vector2 = q.position - attacker.position
		if to.length() > radius:
			continue
		if attacker.facing.dot(to.normalized()) < 0.35:
			continue
		_damage(room, q, dmg, attacker.pid)


func _on_push(room: Room, p: ServerPlayer) -> void:
	if not room.started or not p.alive or p.disconnected:
		return
	var best: ServerPlayer = null
	var best_d := NetProto.PUSH_RANGE
	for pid in room.players.keys():
		var q: ServerPlayer = room.players[pid]
		if q == p or not q.alive or q.disconnected:
			continue
		var to: Vector2 = q.position - p.position
		var d := to.length()
		if d > NetProto.PUSH_RANGE or d < 1.0:
			continue
		if p.facing.dot(to.normalized()) < 0.3:
			continue
		if d < best_d:
			best_d = d
			best = q
	if best != null:
		p.clear_protection()
		best.apply_knockback(p.facing, NetProto.PUSH_FORCE)
		_send(p.peer, "toast", {"msg": "Dorong!"})


## Validasi 3b3: idx mesin valid, player di dalam area interaksi mesin tsb,
## dan cooldown per-mesin per-player sudah habis. Server authoritative (anti-cheat).
func _can_use_puzzle(room: Room, p: ServerPlayer, mid: int) -> bool:
	if not room.started or not p.alive or p.disconnected:
		return false
	if mid < 0 or mid >= Map3B.PUZZLE_INTERACT.size():
		return false
	var r: Rect2 = Map3B.PUZZLE_INTERACT[mid]
	# Toleransi 80px untuk network lag (posisi server bisa tertinggal dari client).
	if not r.grow(80).has_point(p.position):
		return false
	if float(p.puzzle_cds.get(mid, 0.0)) > 0.0:
		return false
	return true


func _on_puzzle_done(room: Room, p: ServerPlayer, mid: int) -> void:
	if not _can_use_puzzle(room, p, mid):
		# Beri tahu jika gagal karena cooldown (bukan karena posisi/cheat).
		var cd: float = float(p.puzzle_cds.get(mid, 0.0))
		if cd > 0.0:
			_send(p.peer, "toast", {"msg": "Puzzle cooldown: %ds" % maxi(int(ceil(cd)), 1)})
		return
	p.puzzle_cds[mid] = NetProto.PUZZLE_COOLDOWN
	var center: Vector2 = Map3B.PUZZLE_POS[mid]
	for i in 5:
		var letter := String.chr(randi_range(65, 90))
		var ang := randf() * TAU
		var dist := randf_range(NetProto.SCATTER_REWARD_MIN, NetProto.SCATTER_REWARD_MAX)
		_spawn_pickup(room, center + Vector2(cos(ang), sin(ang)) * dist, letter)
	_send(p.peer, "toast", {"msg": "Puzzle selesai! Pungut 5 huruf yang buyar!"})


func _on_exchange(room: Room, p: ServerPlayer, m: Dictionary) -> void:
	if not room.started or not p.alive or p.disconnected:
		_send(p.peer, "exchange_err", {"msg": "Tidak bisa tukar sekarang."})
		return
	var src := int(m.get("src", -1))
	var target := str(m.get("target", ""))
	var letter := str(m.get("letter", ""))
	var pay: Array = m.get("pay", [])
	if src < 0 or src >= SpellInventory.CELLS:
		return
	if not SpellExchange.is_valid_letter(target) or target == letter:
		return
	if p.inv.grid[src] == null or str(p.inv.grid[src]) != letter:
		_reject_exchange(room, p)
		return
	if pay.size() != SpellExchange.cost(letter, target):
		_reject_exchange(room, p)
		return
	for ci in pay:
		var idx := int(ci)
		if idx < 0 or idx >= SpellInventory.CELLS or idx == src:
			_reject_exchange(room, p)
			return
		if p.inv.grid[idx] == null:
			_reject_exchange(room, p)
			return
	SpellExchange.apply(p.inv, src, target, pay)
	p.recompute_words()
	_send_grid(room, p, "", true)
	_send(p.peer, "exchange_ok", {"msg": "Tukar: %s jadi %s!" % [letter, target]})


func _reject_exchange(room: Room, p: ServerPlayer) -> void:
	_send_grid(room, p, "")
	_send(p.peer, "exchange_err", {"msg": "Tukar gagal (validasi)."})


# ---------- simulasi ----------

func _physics_process(delta: float) -> void:
	for code in _rooms.keys():
		_sim_room(_rooms[code], delta)


func _sim_room(room: Room, delta: float) -> void:
	if not room.started:
		return
	# Pemain.
	for pid in room.players.keys():
		var p: ServerPlayer = room.players[pid]
		if p.disconnected:
			p.dc_left -= delta
			if p.dc_left <= 0.0:
				_timeout_player(room, p)
			continue
		p.simulate(delta)
		for mid in p.puzzle_cds.keys():
			var left: float = maxf(float(p.puzzle_cds[mid]) - delta, 0.0)
			if left <= 0.0:
				p.puzzle_cds.erase(mid)
			else:
				p.puzzle_cds[mid] = left
		# FIX: pemain yang mati SEBELUMNYA tidak pernah respawn di MP.
		if not p.alive and p.respawn_left <= 0.0:
			_respawn_player(room, p)
	# Proyektil.
	var space := get_world_2d().direct_space_state
	for i in range(room.projs.size() - 1, -1, -1):
		var j: Dictionary = room.projs[i]
		var step := 700.0 * delta
		var from: Vector2 = j["pos"]
		var to: Vector2 = from + (j["dir"] as Vector2) * step
		var q := PhysicsRayQueryParameters2D.create(from, to, 1)
		if not space.intersect_ray(q).is_empty():
			room.projs.remove_at(i)
			continue
		j["pos"] = to
		j["traveled"] = float(j["traveled"]) + step
		var hit := false
		for pid in room.players.keys():
			var pl: ServerPlayer = room.players[pid]
			if pid == int(j["shooter"]) or not pl.alive or pl.disconnected:
				continue
			if pl.position.distance_to(to) < 24.0:
				_damage(room, pl, NetProto.PISTOL_DAMAGE, int(j["shooter"]))
				hit = true
				break
		if hit or float(j["traveled"]) > 900.0:
			room.projs.remove_at(i)
	# Trap.
	for i in range(room.traps.size() - 1, -1, -1):
		var t: Dictionary = room.traps[i]
		t["arm_left"] = float(t["arm_left"]) - delta
		if float(t["arm_left"]) > 0.0:
			continue
		var boom := false
		for pid in room.players.keys():
			var pl: ServerPlayer = room.players[pid]
			if pid == int(t["owner"]) or not pl.alive or pl.disconnected:
				continue
			if pl.position.distance_to(t["pos"] as Vector2) < 34.0:
				_damage(room, pl, NetProto.TRAP_DAMAGE, int(t["owner"]))
				pl.apply_slow(NetProto.TRAP_SLOW_DURATION)
				room.events.append({"k": "trap", "id": pid})
				boom = true
				break
		if boom:
			room.traps.remove_at(i)
	# Pickup.
	for i in range(room.pickups.size() - 1, -1, -1):
		var u: Dictionary = room.pickups[i]
		var taken := false
		for pid in room.players.keys():
			var pl: ServerPlayer = room.players[pid]
			if not pl.alive or pl.disconnected:
				continue
			if pl.position.distance_to(u["pos"] as Vector2) < 30.0:
				var idx: int = pl.inv.grid.find(null)
				if idx != -1:
					pl.inv.grid[idx] = str(u["letter"])
					pl.recompute_words()
					_send_grid(room, pl, "Pungut: " + str(u["letter"]))
					taken = true
				break
		if taken:
			room.pickups.remove_at(i)


## Damage otoritatif. Return true jika target mati.
func _damage(room: Room, target: ServerPlayer, amount: int, attacker: int) -> bool:
	if target.take_damage(amount):
		room.events.append({"k": "die", "id": target.pid, "name": target.player_name})
		_drop_letters(room, target)
		return true
	room.events.append({"k": "dmg", "id": target.pid, "n": amount})
	return false


func _drop_letters(room: Room, p: ServerPlayer) -> void:
	for i in SpellInventory.CELLS:
		var v = p.inv.grid[i]
		if v == null:
			continue
		var ang := randf() * TAU
		var dist := randf_range(NetProto.SCATTER_DEATH_MIN, NetProto.SCATTER_DEATH_MAX)
		_spawn_pickup(room, p.position + Vector2(cos(ang), sin(ang)) * dist, str(v))
		p.inv.grid[i] = null
	p.recompute_words()
	_send_grid(room, p, "")


## Respawn di titik spawn tetap + proteksi 3 dtk (seperti solo).
func _respawn_player(room: Room, p: ServerPlayer) -> void:
	p.position = p.spawn_pos
	p.respawn_at(p.position)
	_send_grid(room, p, "")
	_broadcast(room)


func _spawn_pickup(room: Room, pos: Vector2, letter: String) -> void:
	# Containment 3b1: pickup tidak boleh spawn di dalam tembok (merah = absolut).
	room.pickups.append({"id": room.next_ent, "letter": letter,
		"pos": MapData.clamp_to_walkable(pos)})
	room.next_ent += 1


func _timeout_player(room: Room, p: ServerPlayer) -> void:
	# Lewat 90 dtk: huruf jatuh, karakter dihapus.
	_drop_letters(room, p)
	room.players.erase(p.pid)
	p.queue_free()
	for i in range(_conns.size() - 1, -1, -1):
		var c: Dictionary = _conns[i]
		if c["room"] == room and int(c["pid"]) == p.pid:
			_conns.remove_at(i)
	if room.players.is_empty():
		_rooms.erase(room.code)
		print("[server] room %s dihapus (kosong)" % room.code)
	else:
		if room.host_id == p.pid:
			var np := -1
			for pid in room.players.keys():
				var q: ServerPlayer = room.players[pid]
				if not q.disconnected and (np == -1 or pid < np):
					np = pid
			room.host_id = np
		_broadcast(room)


# ---------- snapshot ----------

func _broadcast(room: Room) -> void:
	if not room.started:
		_broadcast_lobby(room)
		return
	room.tick += 1
	for c in _conns:
		var cc: Dictionary = c
		if cc["room"] != room:
			continue
		var me: ServerPlayer = room.players.get(int(cc["pid"]))
		if me == null:
			continue
		_send(cc["ws"], "snap", _snap_for(room, me))
	room.events.clear()


func _player_snap(p: ServerPlayer, is_self: bool, room: Room) -> Dictionary:
	var d := p.snap_dict(is_self)
	var tc := 0
	for t in room.traps:
		if int(t["owner"]) == p.pid:
			tc += 1
	d["traps"] = tc
	return d


func _snap_for(room: Room, me: ServerPlayer) -> Dictionary:
	var ps: Array = []
	for pid in room.players.keys():
		var p: ServerPlayer = room.players[pid]
		if pid == me.pid:
			ps.append(_player_snap(p, true, room))
		elif p.position.distance_to(me.position) <= NetProto.VISION_RADIUS:
			ps.append(_player_snap(p, false, room))
	var pk: Array = []
	for u in room.pickups:
		var upos: Vector2 = u["pos"]
		if upos.distance_to(me.position) <= NetProto.VISION_RADIUS:
			pk.append({"id": u["id"], "L": str(u["letter"]),
				"x": upos.x, "y": upos.y})
	var tr: Array = []
	for t in room.traps:
		var tpos: Vector2 = t["pos"]
		var d := tpos.distance_to(me.position)
		if int(t["owner"]) == me.pid or d <= NetProto.TRAP_SEE_RADIUS:
			tr.append({"id": t["id"], "x": tpos.x, "y": tpos.y,
				"armed": float(t["arm_left"]) <= 0.0})
	var pr: Array = []
	for j in room.projs:
		var jpos: Vector2 = j["pos"]
		if jpos.distance_to(me.position) <= NetProto.VISION_RADIUS:
			var jd: Vector2 = j["dir"]
			pr.append({"id": j["id"], "x": jpos.x, "y": jpos.y,
				"dx": jd.x, "dy": jd.y})
	return {"tick": room.tick, "you": me.pid, "players": ps,
		"pickups": pk, "traps": tr, "projs": pr, "ev": room.events.duplicate()}
