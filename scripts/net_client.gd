extends Node
## Autoload "Net" — koneksi WebSocket client ke dedicated server.
## Dipakai menu.gd (lobby) dan mp_game.gd (match). Persist antar scene.

signal connected_to_server
signal conn_failed(reason: String)
signal server_disconnected
signal lobby_updated(players: Array, host_id: int, code: String)
signal hello_ok(room_code: String, player_id: int, is_host: bool, reconnected: bool)
signal hello_error(msg: String)
signal match_started
signal snapshot(data: Dictionary)
signal grid_sync(cells: Array, note: String, exchanged: bool)
signal toast_msg(msg: String)
signal panel_ok(kind: String)
signal exchange_result(ok: bool, msg: String)

const WS_URL := "wss://spellwar.aditiamh.my.id/ws"

var nickname := ""
var room_code := ""
var player_id := 0
var is_host := false
var state := "idle"  # idle | connecting | lobby | playing
var last_error := ""  # pesan untuk menu setelah disconnect

var _ws: WebSocketPeer = null
var _input_acc := 0.0
var _last_mv := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func connect_room(p_nickname: String, mode: String, code: String = "") -> void:
	disconnect_now()
	nickname = p_nickname
	_ws = WebSocketPeer.new()
	state = "connecting"
	var err := _ws.connect_to_url(WS_URL)
	if err != OK:
		state = "idle"
		conn_failed.emit("Gagal konek: %s" % err)
		return
	# hello dikirim setelah handshake OPEN (di _process).
	_pending_hello = {"name": p_nickname, "mode": mode, "room": code}


var _pending_hello: Dictionary = {}


func disconnect_now() -> void:
	if _ws != null:
		_ws.close()
		_ws = null
	state = "idle"
	_pending_hello = {}


func _process(delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if state == "connecting":
			state = "lobby"
			_send("hello", _pending_hello)
			connected_to_server.emit()
		while _ws.get_available_packet_count() > 0:
			var pkt := _ws.get_packet()
			if _ws.was_string_packet():
				_dispatch(NetProto.parse(pkt.get_string_from_utf8()))
	elif st == WebSocketPeer.STATE_CLOSED:
		if state == "lobby" or state == "playing":
			server_disconnected.emit()
		_ws = null
		state = "idle"


func _send(msg_type: String, data: Dictionary = {}) -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(NetProto.msg(msg_type, data))


func _dispatch(m: Dictionary) -> void:
	match str(m.get("t", "")):
		"hello_ok":
			player_id = int(m.get("id", 0))
			room_code = str(m.get("room", ""))
			is_host = int(m.get("host", 0)) == player_id
			state = "lobby"
			hello_ok.emit(room_code, player_id, is_host,
				bool(m.get("reconnected", false)))
		"hello_err":
			state = "idle"
			hello_error.emit(str(m.get("msg", "Gagal join.")))
		"lobby":
			is_host = int(m.get("host", 0)) == player_id
			lobby_updated.emit(m.get("players", []),
				int(m.get("host", 0)), str(m.get("code", "")))
		"start":
			state = "playing"
			match_started.emit()
		"snap":
			snapshot.emit(m)
		"grid":
			grid_sync.emit(m.get("cells", []), str(m.get("note", "")),
				bool(m.get("ex", false)))
		"toast":
			toast_msg.emit(str(m.get("msg", "")))
		"pong":
			pass
		"panel_ok":
			panel_ok.emit(str(m.get("kind", "")))
		"exchange_ok":
			exchange_result.emit(true, str(m.get("msg", "")))
		"exchange_err":
			exchange_result.emit(false, str(m.get("msg", "")))


# ---------- API untuk mp_game.gd ----------

func send_input(mv: Vector2, delta: float) -> void:
	if state != "playing":
		return
	_input_acc += delta
	var changed := mv.distance_to(_last_mv) > 0.01
	if _input_acc >= 1.0 / NetProto.INPUT_HZ or (changed and _input_acc > 0.03):
		_input_acc = 0.0
		_last_mv = mv
		_send("input", {"mv": [mv.x, mv.y]})


func send_grid(cells: Array) -> void:
	_send("grid", {"cells": cells})


func send_weapon(w: String) -> void:
	_send("use_weapon", {"w": w})


func send_push() -> void:
	_send("push", {})


func send_interact_puzzle(machine_idx: int) -> void:
	_send("interact_puzzle", {"machine": machine_idx})


func send_puzzle_done(machine_idx: int) -> void:
	_send("puzzle_done", {"machine": machine_idx})


func send_interact_exchange() -> void:
	_send("interact_exchange", {})


func send_exchange(src: int, target: String, letter: String, pay: Array) -> void:
	_send("exchange_do", {"src": src, "target": target,
		"letter": letter, "pay": pay})


func send_start() -> void:
	_send("start", {})


func send_ping() -> void:
	_send("ping", {})
