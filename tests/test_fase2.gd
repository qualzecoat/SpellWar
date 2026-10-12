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

	# --- SP speed mult ---
	var p4 = _new_player()
	p4.speed_mult *= 1.15
	p4.speed_mult *= 1.15
	_check(absf(p4.speed_mult - 1.3225) < 0.001, "SP stack 2x -> 1.3225x")
	p4.speed_mult /= 1.15
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

	print("Fase2: %d lolos, %d gagal" % [_passed, _failed])
	quit(_failed)
