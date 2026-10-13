extends SceneTree
## Uji logika Fase 3 (multiplayer) secara headless — tanpa networking.
## Jalankan: godot --headless --path <project> -s res://tests/test_fase3.gd
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


func _fill(inv, word: String, r: int, c0: int) -> void:
	for k in word.length():
		inv.grid[r * 8 + c0 + k] = word.substr(k, 1)


func _kb_texts(kb) -> Array:
	var out := []
	for row in kb._rows_box.get_children():
		for b in row.get_children():
			if b is Button:
				out.append(b.text)
	return out


func _init() -> void:
	# --- NetProto: kode room ---
	var seen := {}
	var ok_chars := true
	for i in 20:
		var code: String = NetProto.make_room_code()
		if code.length() != NetProto.CODE_LEN:
			ok_chars = false
		for ch in code:
			if not NetProto.CODE_CHARS.contains(ch):
				ok_chars = false
		seen[code] = true
	_check(ok_chars, "make_room_code: 6 karakter dari CODE_CHARS")
	_check(seen.size() == 20, "make_room_code: 20 kode unik")

	# --- NetProto: msg/parse roundtrip ---
	var m: Dictionary = NetProto.parse(NetProto.msg("input", {"mv": [1.0, 0.0]}))
	_check(str(m.get("t")) == "input" and (m.get("mv") as Array)[0] == 1.0,
		"msg/parse roundtrip input")
	_check(NetProto.parse("bukan json").is_empty(), "parse abaikan string invalid")
	_check(NetProto.parse('{"x":1}').is_empty(), "parse abaikan tanpa field t")

	# --- NetProto: konstanta ---
	_check(NetProto.SPAWN_SLOTS.size() == 8, "8 titik spawn")
	var in_map := true
	for s in NetProto.SPAWN_SLOTS:
		var v: Vector2 = s
		# Dalam bounding box map v1 (x 700-1300, y -300-900).
		if v.x < 700 or v.x > 1300 or v.y < -300 or v.y > 900:
			in_map = false
	_check(in_map, "semua spawn slot di dalam map v1")
	_check(NetProto.RECONNECT_TIME == 90.0, "reconnect 90 detik")
	_check(NetProto.MIN_PLAYERS == 2 and NetProto.MAX_PLAYERS == 8, "min 2 / max 8 pemain")

	# --- ServerPlayer: efek kata ---
	# NOTE: _ready() dipanggil manual — di mode -s, _init berjalan sinkron
	# sebelum tree sempat memicu _ready.
	var p := ServerPlayer.new()
	p._ready()
	_fill(p.inv, "SWORD", 0, 0)
	var ev: Array = p.recompute_words()
	_check("SWORD" in p.words, "recompute: SWORD aktif")
	_fill(p.inv, "HP", 2, 0)
	p.recompute_words()
	_check(p.max_hp == 150 and p.hp == 150, "efek HP: max+50 & heal (server)")
	# Hapus kata HP -> efek hilang, HP di-clamp.
	p.inv.grid[2 * 8 + 0] = null
	p.inv.grid[2 * 8 + 1] = null
	p.recompute_words()
	_check(p.max_hp == 100 and p.hp == 100, "lepas HP: max kembali & clamp (server)")
	_fill(p.inv, "SP", 4, 0)
	_fill(p.inv, "SP", 5, 0)
	p.recompute_words()
	_check(absf(p.speed_mult - 1.30) < 0.001, "SP stack aditif 2x (server)")

	# --- ServerPlayer: damage & protection ---
	p.protect_left = 3.0
	_check(not p.take_damage(50), "spawn protection kebal damage")
	p.clear_protection()
	_check(not p.take_damage(30) and p.hp == 70, "damage 30 masuk")
	_check(p.take_damage(70) and not p.alive, "mati saat HP 0")
	_check(absf(p.respawn_left - NetProto.RESPAWN_TIME) < 0.01, "respawn timer 5 dtk")

	# --- ServerPlayer: validasi grid (anti duplikasi huruf) ---
	var q := ServerPlayer.new()
	q._ready()
	q.inv.grid[0] = "A"
	q.inv.grid[1] = "B"
	var perm := q.inv.grid.duplicate()
	# Tukar posisi A dan B: tetap permutasi valid.
	perm[0] = "B"
	perm[1] = "A"
	_check(q.grid_is_permutation(perm), "grid permutasi (tukar posisi) valid")
	var dup := q.inv.grid.duplicate()
	dup[1] = "A"  # duplikat A, B hilang
	_check(not q.grid_is_permutation(dup), "grid duplikat huruf ditolak")
	_check(not q.grid_is_permutation([null]), "grid ukuran salah ditolak")
	var bad := q.inv.grid.duplicate()
	bad[0] = "AB"
	_check(not q.grid_is_permutation(bad), "grid huruf 2 karakter ditolak")

	# --- TouchKeyboard: layout PS4, filter charset, shift toggle ---
	var kb1 := TouchKeyboard.new()
	kb1._ready()
	var box1 := [""]
	var opened1 := [false]
	kb1.opened.connect(func() -> void: opened1[0] = true)
	kb1.open_for(func() -> String: return box1[0], func(v: String) -> void: box1[0] = v,
		12, "NICKNAME", "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 '-.,-_")
	var t1 := _kb_texts(kb1)
	_check(opened1[0], "keyboard emit opened saat open_for")
	_check("⇧" in t1, "tombol shift tampil utk nickname")
	_check("q" in t1 and not ("Q" in t1), "huruf kecil default utk nickname")
	_check("Space" in t1, "tombol Space tampil utk nickname")
	_check("." in t1 and "-" in t1 and "_" in t1, "simbol tampil utk nickname")
	_check("1" in t1 and "0" in t1, "baris angka tampil utk nickname")
	_check(kb1.panel_height() > 0.0, "panel_height positif")
	kb1._toggle_shift()
	# Catatan: _rebuild_keys memakai queue_free; di headless tanpa frame,
	# tombol lama belum terhapus dari tree, jadi verifikasi via logika.
	_check(kb1._shift, "shift flag aktif setelah toggle")
	_check(kb1._disp_char("q") == "Q", "_disp_char uppercase saat shift aktif")
	kb1._toggle_shift()
	_check(not kb1._shift and kb1._disp_char("q") == "q", "shift toggle kembali ke lowercase")
	# Rebuild fresh dengan shift aktif -> tombol uppercase.
	var kb3 := TouchKeyboard.new()
	kb3._ready()
	kb3._charset = "abcdefghijklmnopqrstuvwxyz"
	kb3._shift = true
	kb3._rebuild_keys()
	var t3 := _kb_texts(kb3)
	_check("A" in t3 and "Z" in t3 and not ("a" in t3) and not ("z" in t3), "rebuild shift -> semua uppercase")
	kb3.queue_free()
	kb1._press("Q")
	kb1._press(" ")
	_check(box1[0] == "Q ", "ketik Q + spasi")
	kb1._backspace()
	_check(box1[0] == "Q", "backspace hapus spasi")
	kb1.close()
	_check(not kb1.is_open(), "keyboard tertutup")

	var kb2 := TouchKeyboard.new()
	kb2._ready()
	var box2 := [""]
	kb2.open_for(func() -> String: return box2[0], func(v: String) -> void: box2[0] = v,
		6, "KODE ROOM", NetProto.CODE_CHARS)
	var t2 := _kb_texts(kb2)
	_check(not ("⇧" in t2), "tanpa shift utk kode room")
	_check(not ("Space" in t2), "tanpa Space utk kode room")
	_check("Q" in t2 and not ("q" in t2), "uppercase otomatis utk kode room")
	_check(not ("I" in t2) and not ("O" in t2) and not ("0" in t2) and not ("1" in t2), "I/O/0/1 diskip utk kode room")
	_check(not ("." in t2) and not ("-" in t2), "simbol diskip utk kode room")
	_check(kb2._disp_char("q") == "Q", "_disp_char q->Q utk kode room")
	_check(kb2._disp_char("z") == "Z", "_disp_char z->Z utk kode room")
	_check(kb2._disp_char("1") == "", "_disp_char 1 diskip utk kode room")
	kb1.queue_free()
	kb2.queue_free()

	p.queue_free()
	q.queue_free()
	print("test_fase3: %d lolos, %d gagal" % [_passed, _failed])
	quit(_failed)