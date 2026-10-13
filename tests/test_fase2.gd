extends SceneTree
## Uji logika Fase 2 secara headless: EP, damage/kematian, stat stacking,
## trap cost/trigger, drop huruf.
## Jalankan: godot --headless --path <project> -s res://tests/test_fase2.gd
## Exit code = jumlah kegagalan (0 = semua lolos).

var _passed := 0
var _failed := 0


func _check(ok: bool, name: String) -> void:
	if ok:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		printerr("FAIL: " + name)


func _new_player():
	var s: GDScript = load("res://scripts/player.gd")
	var p: CharacterBody2D = s.new()
	root.add_child(p)
	return p


func _new_inv():
	var s: GDScript = load("res://scripts/inventory.gd")
	return s.new()


func _init() -> void:
	# --- EP ---
	var p1 = _new_player()
	_check(p1.ep == 100 and p1.max_ep == 100, "EP awal 100/100")
	_check(p1.spend_ep(10) == true and p1.ep == 90, "spend_ep 10 berhasil, sisa 90")
	_check(p1.spend_ep(200) == false and p1.ep == 90, "spend_ep 200 gagal, EP tidak berubah")
	p1.add_ep_regen(2.0)
	_check(absf(p1.ep_regen - 7.0) < 0.001, "EP regen +2 -> 7/dtk")
	p1.set_max_ep(125)
	_check(p1.max_ep == 125, "EP max +25 -> 125")
	p1.set_max_ep(100)
	_check(p1.max_ep == 100, "EP max kembali 100")
	p1.queue_free()

	# --- Damage & kematian ---
	var p2 = _new_player()
	var died_flag := [false]
	p2.died.connect(func() -> void: died_flag[0] = true)
	p2.take_damage(25)
	_check(p2.hp == 75 and p2.alive, "damage 25 -> HP 75, masih hidup")
	p2.take_damage(50)
	_check(p2.hp == 25 and p2.alive and not died_flag[0], "damage 50 -> HP 25")
	p2.take_damage(50)
	_check(p2.hp == 0 and not p2.alive and died_flag[0], "HP 0 -> mati, died emit")
	p2.take_damage(10)
	_check(p2.hp == 0, "damage setelah mati tidak berefek")
	p2.queue_free()

	# --- Stat stacking HP ---
	var p3 = _new_player()
	p3.set_max_hp(p3.max_hp + 50)
	p3.set_max_hp(p3.max_hp + 50)
	_check(p3.max_hp == 200, "HP stack 2x -> max 200")
	p3.set_max_hp(p3.max_hp - 50)
	_check(p3.max_hp == 150, "HP pecah 1x -> max 150")
	p3.queue_free()

	# --- SP speed mult (ADITIF — FIX 2026-10-13 Fix 4) ---
	var p4 = _new_player()
	p4.speed_mult += 0.15
	p4.speed_mult += 0.15
	_check(absf(p4.speed_mult - 1.30) < 0.001, "SP stack 2x -> 1.30x (aditif 30%)")
	p4.speed_mult -= 0.15
	_check(absf(p4.speed_mult - 1.15) < 0.001, "SP pecah 1x -> 1.15x")
	p4.queue_free()

	# --- Slow ---
	var p5 = _new_player()
	p5.apply_slow(2.0)
	_check(p5._slow_time > 0.0, "slow aktif")
	p5.queue_free()

	# --- Trap cost melingkar (aturan Fase 1b, regression) ---
	var ex: GDScript = load("res://scripts/exchange.gd")
	_check(ex.cost("A", "C") == 2, "trap cost A->C = 2")
	_check(ex.cost("Z", "A") == 1, "trap cost Z->A = 1")
	_check(ex.cost("Z", "X") == 2, "trap cost Z->X = 2")

	# --- Drop huruf: semua cell terisi bisa dikosongkan ---
	var inv = _new_inv()
	inv.add_letters(["A", "B", "C", "D", "E"])
	var dropped := 0
	for i in 64:
		if inv.grid[i] != null:
			dropped += 1
			inv.grid[i] = null
	_check(dropped == 5 and inv.empty_count() == 64, "drop 5 huruf -> grid kosong")

	# --- heal clamp ---
	var p6 = _new_player()
	p6.take_damage(30)
	p6.heal(50)
	_check(p6.hp == 100, "heal di-clamp ke max_hp")
	p6.queue_free()

	# --- FIX 2026-10-12 (Fix 2): EP regen pakai akumulator float ---
	var p7 = _new_player()
	p7.ep = 90
	p7._ep_frac = 0.0
	p7._process(1.0)  # 5 EP/detik * 1 dtk
	_check(p7.ep == 95, "regen EP float: 90 + 5 = 95 (tidak terpotong int)")
	p7._process(0.1)  # +0.5 -> fraksi tersimpan, EP tetap 95
	_check(p7.ep == 95 and p7._ep_frac > 0.0, "fraksi 0.5 tersimpan, EP tetap 95")
	p7._process(0.1)  # +0.5 lagi -> genap 1.0 -> EP 96
	_check(p7.ep == 96, "akumulasi fraksi: 95 + 1 = 96")
	p7.queue_free()

	# --- FIX 2026-10-12 (Fix 3): trap max concurrent ---
	var trap_script: GDScript = load("res://scripts/trap.gd")
	_check(int(trap_script.MAX_CONCURRENT) == 3, "trap MAX_CONCURRENT = 3")

	# --- FIX 2026-10-12 (Fix 5): knockback dummy via velocity (bukan tween) ---
	var dummy_script: GDScript = load("res://scripts/dummy.gd")
	var d = dummy_script.new()
	root.add_child(d)
	d.apply_knockback(Vector2.RIGHT, 500.0)
	_check(d._knock_time > 0.0 and d._knockback == Vector2(500, 0),
		"knockback dummy tersimpan sebagai velocity (hormati collision)")
	d.queue_free()

	# --- FIX 2026-10-12: duplikat kata senjata -> hanya 1 yang aktif ---
	var words_script: GDScript = load("res://scripts/words.gd")
	var dup_matches: Array = [
		{"word": "TRAP", "dir": "h", "cells": [0, 1, 2, 3]},
		{"word": "TRAP", "dir": "v", "cells": [10, 18, 26, 34]},
		{"word": "HP", "dir": "h", "cells": [40, 41]},
		{"word": "HP", "dir": "v", "cells": [50, 58]},
		{"word": "SWORD", "dir": "h", "cells": [20, 21, 22, 23, 24]},
	]
	var filtered: Array = words_script.filter_weapon_first(dup_matches)
	var trap_n := 0
	var hp_n := 0
	var sword_n := 0
	for m in filtered:
		match str(m["word"]):
			"TRAP":
				trap_n += 1
			"HP":
				hp_n += 1
			"SWORD":
				sword_n += 1
	_check(trap_n == 1, "duplikat TRAP -> hanya 1 aktif")
	_check(hp_n == 2, "duplikat HP (stat) -> tetap 2 aktif")
	_check(sword_n == 1, "SWORD tunggal -> 1 aktif")
	_check(filtered.size() == 4, "total match aktif = 4")
	_check(str(filtered[0]["word"]) == "TRAP" and str(filtered[0]["dir"]) == "h",
		"match TRAP pertama (h) yang dipertahankan")

	# --- promosi duplikat: yang aktif pecah -> duplikat utuh naik jadi aktif ---
	var invw = _new_inv()
	for k in 4:
		invw.grid[k] = "TRAP".substr(k, 1)          # TRAP horizontal baris 0
	for k in 4:
		invw.grid[k * 8 + 6] = "TRAP".substr(k, 1)  # TRAP vertikal kolom 6
	var f1: Array = words_script.filter_weapon_first(invw.scan_words())
	_check(f1.size() == 1, "2x TRAP utuh -> filter jadi 1 aktif")
	invw.grid[0] = null  # pecahkan TRAP horizontal
	var f2: Array = words_script.filter_weapon_first(invw.scan_words())
	_check(f2.size() == 1 and str(f2[0]["dir"]) == "v",
		"TRAP horizontal pecah -> TRAP vertikal naik jadi aktif")

	# --- FIX 2026-10-13 (Fix 2): seleksi senjata STABIL antar-scan ---
	var dup2: Array = [
		{"word": "TRAP", "dir": "h", "cells": [0, 1, 2, 3]},
		{"word": "TRAP", "dir": "v", "cells": [10, 18, 26, 34]},
		{"word": "HP", "dir": "h", "cells": [40, 41]},
	]
	var r1: Dictionary = words_script.select_stable_weapons(dup2, {})
	_check((r1["selected"] as Array).size() == 2,
		"stabil: stat HP + 1 TRAP aktif = 2 selected")
	_check(str((r1["active_keys"] as Dictionary)["TRAP"]) == words_script.match_key(dup2[0]),
		"stabil: tanpa state, TRAP pertama jadi aktif")
	_check((r1["dup_words"] as Array).has("TRAP"),
		"stabil: TRAP kedua tercatat sebagai duplikat")
	# State aktif = TRAP vertikal; scan baru urutannya berubah -> tetap vertikal.
	var active := {"TRAP": words_script.match_key(dup2[1])}
	var r2: Dictionary = words_script.select_stable_weapons([dup2[1], dup2[0]], active)
	_check(str((r2["active_keys"] as Dictionary)["TRAP"]) == words_script.match_key(dup2[1]),
		"stabil: yang aktif dipertahankan walau urutan scan berubah")
	_check((r2["selected"] as Array).size() == 1,
		"stabil: hanya 1 TRAP di selected (duplikat tidak aktif)")
	# Yang aktif pecah -> duplikat yang masih utuh naik jadi aktif.
	var r3: Dictionary = words_script.select_stable_weapons([dup2[0]], active)
	_check(str((r3["active_keys"] as Dictionary)["TRAP"]) == words_script.match_key(dup2[0]),
		"stabil: yang aktif pecah -> duplikat naik jadi aktif")
	_check(not (r3["dup_words"] as Array).has("TRAP"),
		"stabil: tinggal 1 match -> bukan duplikat")
	# Kata hilang total -> state aktif dibersihkan.
	var r4: Dictionary = words_script.select_stable_weapons([], active)
	_check(not (r4["active_keys"] as Dictionary).has("TRAP"),
		"stabil: kata hilang -> state aktif dibersihkan")

	# --- FIX 2026-10-13 (Fix 5): trap arming 3 detik ---
	var t = trap_script.new()
	root.add_child(t)
	_check(t.armed == false, "trap baru: belum armed (masa arming 3 dtk)")
	var dd = dummy_script.new()
	root.add_child(dd)
	# NOTE: _ready() tidak jalan di konteks SceneTree-test headless
	# (di game asli jalan normal) -> tambahkan group manual.
	dd.add_to_group("damageable")
	var dhp: int = dd.hp
	t._on_body_entered(dd)  # diinjak saat arming -> tidak boleh meledak
	_check(t._triggered == false and dd.hp == dhp,
		"arming: diinjak -> TIDAK meledak, tidak ada damage")
	t._process(3.1)  # lewati masa arming
	_check(t.armed == true, "setelah 3 dtk: trap armed")
	t._on_body_entered(dd)  # diinjak setelah armed -> meledak
	_check(t._triggered == true and dd.hp == dhp - 30,
		"armed: diinjak -> meledak, damage 30")
	dd.queue_free()

	# --- FIX 2026-10-13 (Fix 6): overlay segmentasi bar ---
	var seg_script: GDScript = load("res://scripts/bar_segments.gd")
	var seg = seg_script.new()
	seg.set_params(50.0, 150.0)
	_check(seg.step == 50.0 and seg.max_value == 150.0,
		"BarSegments menyimpan step & max")
	seg.set_params(25.0, 100.0)
	_check(seg.step == 25.0 and seg.max_value == 100.0,
		"BarSegments update untuk EP (25/100)")
	seg.queue_free()

	# --- FIX 2026-10-13: spawn protection 3 dtk ---
	var p7 = _new_player()
	p7.respawn_at(Vector2(100, 100))
	_check(p7._protect_time > 0.0, "respawn -> proteksi aktif")
	_check(p7.alive and p7.hp == p7.max_hp, "respawn -> hidup & HP penuh")
	p7.take_damage(50)
	_check(p7.hp == p7.max_hp, "proteksi: damage 50 ditolak")
	p7.apply_knockback(Vector2.RIGHT, 500.0)
	_check(p7._knock_time <= 0.0, "proteksi: knockback ditolak")
	p7.clear_protection()
	_check(p7._protect_time <= 0.0, "clear_protection mematikan proteksi")
	p7.take_damage(50)
	_check(p7.hp == p7.max_hp - 50, "tanpa proteksi: damage masuk")
	p7.queue_free()

	# --- FIX 2026-10-13: respawn 5 dtk ---
	var game_script: GDScript = load("res://scripts/game.gd")
	_check(absf(float(game_script.RESPAWN_TIME) - 5.0) < 0.001,
		"RESPAWN_TIME = 5 dtk")

	# --- FIX 2026-10-13: SpellPickup.drop (dipakai scatter hadiah puzzle) ---
	# NOTE: _ready() tidak jalan di konteks SceneTree-test headless,
	# jadi cek properti yang tidak bergantung _ready (jumlah, huruf, tipe).
	var pickup_script: GDScript = load("res://scripts/pickup.gd")
	var par := Node2D.new()
	root.add_child(par)
	for i in 5:
		pickup_script.drop(par, Vector2(i * 40.0, 0.0), String.chr(65 + i))
	var letters_ok := par.get_child_count() == 5
	var idx := 0
	for c in par.get_children():
		if not (c is SpellPickup):
			letters_ok = false
		elif str(c.get("letter")) != String.chr(65 + idx):
			letters_ok = false
		idx += 1
	_check(letters_ok, "drop 5 pickup huruf A-E (scatter hadiah puzzle)")
	par.queue_free()

	print("Fase2: %d lolos, %d gagal" % [_passed, _failed])
	quit(_failed)
