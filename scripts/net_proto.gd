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
# Cooldown minigame puzzle per pemain (desain): cegah farming satu konsol.
const PUZZLE_COOLDOWN := 30.0

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


# ===== ATURAN GAMEPLAY (satu rumah) =====
# Refactor 2026-10-14: angka-angka ini sebelumnya duplikat di game.gd / player.gd /
# server_player.gd / mp_server.gd / projectile.gd / trap.gd -> drift antar mode
# (mis. respawn tak jalan di MP). Kini satu sumber: NetProto.
# JANGAN ubah nilainya tanpa keputusan desain (catat di DECISIONS.md).
const BASE_SPEED := 220.0
const BASE_MAX_HP := 100
const BASE_MAX_EP := 100
const BASE_EP_REGEN := 5.0
# Efek kata (stat).
const WORD_HP_MAX_BONUS := 50
const WORD_HP_HEAL := 50
const WORD_EP_MAX_BONUS := 25
const WORD_EP_REGEN_BONUS := 2.0
const WORD_SP_BONUS := 0.15
# Biaya EP senjata.
const SWORD_EP_COST := 8
const PISTOL_EP_COST := 10
const TRAP_EP_COST := 15
# Damage & jangkauan.
const SWORD_DAMAGE := 25
const PISTOL_DAMAGE := 50
const TRAP_DAMAGE := 30
const MELEE_RANGE := 100.0
# Dorong (action button).
const PUSH_RANGE := 110.0
const PUSH_FORCE := 500.0
# Trap.
const TRAP_MAX := 3
const TRAP_ARM_TIME := 3.0
const TRAP_SLOW_DURATION := 2.0
# Huruf buyar: hadiah puzzle & drop kematian (radius dari titik asal).
const SCATTER_REWARD_MIN := 90.0
const SCATTER_REWARD_MAX := 150.0
const SCATTER_DEATH_MIN := 60.0
const SCATTER_DEATH_MAX := 150.0


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


## FIX 2026-10-13: kapan client MP boleh mengirim input gerak — diblokir
## saat mati / panel mesin tukar / minigame terbuka, tapi TIDAK saat
## inventory (drawer) saja yang terbuka (desain: karakter TETAP BISA GERAK
## saat inventory terbuka, hanya action yang mati).
static func movement_blocked(dead: bool, exchange_open: bool,
		minigame_visible: bool) -> bool:
	return dead or exchange_open or minigame_visible
