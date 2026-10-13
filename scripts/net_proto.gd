class_name NetProto
extends RefCounted
## Protokol multiplayer SpellWar Fase 3 — konstanta bersama client & server.
## Transport: JSON text frame via WebSocket (wss://spellwar.aditiamh.my.id/ws).
##
## Alur: hello(create|join) -> lobby -> start -> snap loop.
## Reconnect: hello(join) dengan nickname yang sedang disconnect (< 90 dtk).

const WS_PATH := "/ws"
const SERVER_PORT := 8765
const SNAP_HZ := 15.0
const INPUT_HZ := 20.0

# Vision: pemain lain / pickup / proyektil hanya dikirim dalam radius ini.
const VISION_RADIUS := 420.0
# Trap non-pemilik hanya terlihat dalam radius ini (aturan desain).
const TRAP_SEE_RADIUS := 150.0

const MAX_PLAYERS := 8
const MIN_PLAYERS := 2
const RECONNECT_TIME := 90.0
const RESPAWN_TIME := 5.0
const PROTECT_TIME := 3.0

# 8 slot spawn — adaptasi map v1 (ruang ekstraksi + ruang puzzle + koridor).
# Semua titik walkable (di dalam ruangan, jauh dari dinding/mesin).
const SPAWN_SLOTS: Array = [
	Vector2(760, 460), Vector2(1240, 460),   # ekstraksi: sudut utara
	Vector2(760, 840), Vector2(1240, 840),   # ekstraksi: sudut selatan
	Vector2(860, -240), Vector2(1140, -240),  # puzzle: sudut utara
	Vector2(1000, 160), Vector2(1000, 340),  # koridor
]

# Kode room 6 karakter — tanpa huruf/angka ambigu (0/O, 1/I/L dibuang).
const CODE_CHARS := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const CODE_LEN := 6


static func make_room_code() -> String:
	var code := ""
	for i in CODE_LEN:
		code += CODE_CHARS[randi() % CODE_CHARS.length()]
	return code


## Bangun pesan JSON. data digabung dengan {"t": type}.
static func msg(msg_type: String, data: Dictionary = {}) -> String:
	var d := data.duplicate()
	d["t"] = msg_type
	return JSON.stringify(d)


## Parse pesan JSON. Return {} jika gagal.
static func parse(text: String) -> Dictionary:
	var res = JSON.parse_string(text)
	if res is Dictionary and (res as Dictionary).has("t"):
		return res
	return {}
