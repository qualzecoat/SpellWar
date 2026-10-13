class_name ServerPlayer
extends CharacterBody2D
## Simulasi pemain otoritatif di dedicated server (tanpa visual/input lokal).
## Server menjalankan move_and_slide + EP/HP/efek kata; client hanya
## mengirim input dan me-render snapshot.

const BASE_SPEED := 220.0
const BASE_MAX_HP := 100
const BASE_MAX_EP := 100
const BASE_EP_REGEN := 5.0

var pid := 0
var player_name := ""
var peer: WebSocketPeer = null   # null saat disconnect (reconnect 90 dtk)
var spawn_slot := 0
var spawn_pos := Vector2.ZERO   # titik spawn tetap (dipakai respawn)
var puzzle_cd := 0.0            # cooldown minigame per pemain (desain: 30 dtk)

var inv: SpellInventory           # grid otoritatif 8x8
var input_vec := Vector2.ZERO
var facing := Vector2.RIGHT

var hp := BASE_MAX_HP
var max_hp := BASE_MAX_HP
var ep := BASE_MAX_EP
var max_ep := BASE_MAX_EP
var ep_regen := BASE_EP_REGEN
var speed_mult := 1.0

var alive := true
var respawn_left := 0.0
var protect_left := 0.0
var slow_left := 0.0
var disconnected := false
var dc_left := 0.0

var words: Array = []            # kata aktif (Array of String), untuk snapshot
var _word_counts: Dictionary = {}
var _weapon_keys: Dictionary = {}  # stabilitas senjata antar-scan

var _ep_frac := 0.0
var _knockback := Vector2.ZERO
var _knock_left := 0.0


func _ready() -> void:
	inv = SpellInventory.new()
	collision_layer = 2
	collision_mask = 1  # hanya dinding (pemain lain tidak bertabrakan)
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	cs.shape = circle
	add_child(cs)


static func snap4(v: Vector2) -> Vector2:
	if absf(v.x) >= absf(v.y):
		return Vector2(signf(v.x), 0.0)
	return Vector2(0.0, signf(v.y))


## Satu tick simulasi. Dipanggil server tiap physics frame.
func simulate(delta: float) -> void:
	if disconnected:
		return
	if not alive:
		respawn_left -= delta
		return
	# EP regen (akumulator float — sama seperti client).
	if ep < max_ep:
		_ep_frac += ep_regen * delta
		var gain := int(_ep_frac)
		if gain > 0:
			_ep_frac -= gain
			ep = mini(ep + gain, max_ep)
	else:
		_ep_frac = 0.0
	if slow_left > 0.0:
		slow_left -= delta
	if protect_left > 0.0:
		protect_left = maxf(protect_left - delta, 0.0)
	var spd := BASE_SPEED * speed_mult
	if slow_left > 0.0:
		spd *= 0.5
	velocity = input_vec * spd
	if _knock_left > 0.0:
		_knock_left -= delta
		velocity += _knockback
	move_and_slide()
	if input_vec.length() > 0.1:
		facing = snap4(input_vec)


## Return true jika pemain mati akibat damage ini.
func take_damage(amount: int) -> bool:
	if not alive or disconnected:
		return false
	if protect_left > 0.0:
		return false  # spawn protection
	hp = maxi(hp - amount, 0)
	if hp <= 0:
		alive = false
		respawn_left = NetProto.RESPAWN_TIME
		return true
	return false


func apply_slow(duration: float) -> void:
	slow_left = maxf(slow_left, duration)


func apply_knockback(direction: Vector2, force: float, duration: float = 0.18) -> void:
	if not alive or disconnected or protect_left > 0.0:
		return
	_knockback = direction.normalized() * force
	_knock_left = duration


func clear_protection() -> void:
	protect_left = 0.0


func spend_ep(cost: int) -> bool:
	if ep < cost:
		return false
	ep -= cost
	return true


func respawn_at(pos: Vector2) -> void:
	position = pos
	alive = true
	slow_left = 0.0
	_knock_left = 0.0
	velocity = Vector2.ZERO
	input_vec = Vector2.ZERO
	protect_left = NetProto.PROTECT_TIME
	hp = max_hp
	ep = max_ep


## Hitung ulang kata dari grid (mirror logika game.gd rescan_words,
## tanpa HUD). Return events: ["+%s" % w / "-%s" % w].
func recompute_words() -> Array:
	var res: Dictionary = WordDB.select_stable_weapons(
		inv.scan_words(), _weapon_keys)
	var matches: Array = res["selected"]
	_weapon_keys = res["active_keys"]
	var counts: Dictionary = {}
	for m in matches:
		var w := str(m["word"])
		counts[w] = int(counts.get(w, 0)) + 1
	var events: Array = []
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
				events.append("+" + w)
		elif after < before:
			for i in range(before - after):
				_remove_word_effect(w)
				events.append("-" + w)
	_word_counts = counts
	words = counts.keys()
	return events


func _apply_word_effect(word: String) -> void:
	match word:
		"HP":
			max_hp += 50
			hp = mini(hp + 50, max_hp)
		"EP":
			max_ep += 25
			ep_regen += 2.0
		"SP":
			speed_mult += 0.15
		# Senjata (SWORD/PISTOL/TRAP): hanya tercatat di `words` untuk validasi.


func _remove_word_effect(word: String) -> void:
	match word:
		"HP":
			max_hp = maxi(max_hp - 50, 1)
			hp = mini(hp, max_hp)
		"EP":
			max_ep = maxi(max_ep - 25, 1)
			ep = mini(ep, max_ep)
			ep_regen = maxf(ep_regen - 2.0, 0.0)
		"SP":
			speed_mult = maxf(speed_mult - 0.15, 0.1)


## Validasi grid dari client: harus permutasi dari grid server
## (mencegah duplikasi huruf — "validasi wajar").
func grid_is_permutation(cells: Array) -> bool:
	if cells.size() != SpellInventory.CELLS:
		return false
	var a: Dictionary = {}
	var b: Dictionary = {}
	for v in inv.grid:
		if v != null:
			var k := str(v)
			a[k] = int(a.get(k, 0)) + 1
	for v in cells:
		if v != null:
			if not (v is String) or (v as String).length() != 1:
				return false
			var k := str(v)
			b[k] = int(b.get(k, 0)) + 1
	return a == b


## Snapshot dict pemain ini (untuk broadcast).
func snap_dict(is_self: bool) -> Dictionary:
	return {
		"id": pid, "name": player_name,
		"x": position.x, "y": position.y,
		"fx": facing.x, "fy": facing.y,
		"hp": hp, "max_hp": max_hp, "ep": ep, "max_ep": max_ep,
		"sp": int(_word_counts.get("SP", 0)),
		"words": words.duplicate(),
		"alive": alive, "prot": protect_left > 0.0, "dc": disconnected,
		"resp": maxi(int(ceil(respawn_left)), 0) if not alive else 0,
		"traps": 0,  # diisi server (jumlah trap aktif milik pemain)
	}
