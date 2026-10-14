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
	var walk_ok := true
	for s in NetProto.SPAWN_SLOTS:
		var v: Vector2 = s
		# 3b1: semua slot harus walkable di map baru (bukan bbox map v1).
		if not MapData.is_walkable(v):
			walk_ok = false
	_check(walk_ok, "semua spawn slot walkable (map 3b1)")
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

	# --- DarknessOverlay: formula berbasis kamera (fix lubang geser di HP) ---
	var dsh: Shader = load("res://shaders/darkness.gdshader")
	_check(dsh != null, "shader darkness.gdshader ter-load")
	_check(dsh != null and dsh.get_code().contains("smoothstep"), "shader memakai smoothstep")
	_check(dsh != null and dsh.get_code().contains("u_hole_uv"), "shader punya uniform u_hole_uv")
	_check(dsh != null and dsh.get_code().contains("u_view_h_world"), "shader punya uniform u_view_h_world")
	var ov := DarknessOverlay.new()
	ov._ready()
	_check(ov.layer == 2, "darkness layer=2 (di atas dunia, di bawah HUD layer=10)")
	_check(ov._rect != null and ov._rect.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"darkness full-rect & tidak makan input")
	_check(ov._mat != null and ov._mat.shader == dsh, "material memakai shader darkness")
	# Simulasi HP user: aspect lebar 2.17 (visible 1404x648 setelah expand),
	# kamera tepat di pemain -> lubang harus tepat di tengah (0.5, 0.5).
	var vis := Vector2(1404.0, 648.0)
	var zm := Vector2.ONE
	var cam := Vector2(100.0, 50.0)
	var prm: Dictionary = DarknessOverlay.compute_params(cam, zm, vis, cam)
	_check((prm["hole_uv"] as Vector2).distance_to(Vector2(0.5, 0.5)) < 0.0001,
		"lubang di tengah saat kamera di pemain (aspect lebar 2.17)")
	_check(absf(float(prm["aspect"]) - vis.x / vis.y) < 0.0001, "aspect = lebar/tinggi visible")
	_check(absf(float(prm["view_h_world"]) - 648.0) < 0.0001,
		"view_h_world = tinggi dunia yang terlihat")
	# Kamera bergeser +200px dunia di x (mis. offset geser inventory) ->
	# lubang bergeser kiri sebesar 200/1404 dalam UV.
	var prm2: Dictionary = DarknessOverlay.compute_params(cam + Vector2(200, 0), zm, vis, cam)
	var hole2: Vector2 = prm2["hole_uv"]
	_check(absf(hole2.x - (0.5 - 200.0 / 1404.0)) < 0.0001 and absf(hole2.y - 0.5) < 0.0001,
		"lubang mengikuti pergeseran kamera")
	# Zoom 2x -> world_view mengecil setengah; offset 100px dunia = 100/702 UV.
	var prm3: Dictionary = DarknessOverlay.compute_params(cam + Vector2(100, 0), Vector2(2, 2), vis, cam)
	var hole3: Vector2 = prm3["hole_uv"]
	_check(absf(hole3.x - (0.5 - 100.0 / 702.0)) < 0.0001, "formula memperhitungkan zoom kamera")
	_check(absf(float(prm3["view_h_world"]) - 324.0) < 0.0001, "view_h_world mengecil saat zoom")
	# Guard: visible nol -> fallback aman, tidak NaN.
	var prm4: Dictionary = DarknessOverlay.compute_params(cam, zm, Vector2.ZERO, cam)
	var hole4: Vector2 = prm4["hole_uv"]
	_check(hole4.distance_to(Vector2(0.5, 0.5)) < 0.0001, "fallback aman saat visible nol")
	# Radius dikirim dalam px dunia via uniform (180/420).
	_check(absf(float(ov._mat.get_shader_parameter("u_inner")) - 180.0) < 0.001,
		"u_inner=180px dunia")
	_check(absf(float(ov._mat.get_shader_parameter("u_outer")) - 420.0) < 0.001,
		"u_outer=420px dunia")
	ov.queue_free()

	# --- HUD layer: regresi bug komentar-tscn (layer=10 di-skip parser) ---
	var hud_scn: PackedScene = load("res://scenes/hud.tscn")
	var hud_inst := hud_scn.instantiate()
	_check(hud_inst.layer == 10, "HUD layer=10 (di atas darkness layer=2)")
	hud_inst.queue_free()

	# --- Bug 2026-10-13 (1): drop huruf ke slot sumber mesin tukar ---
	var ex = load("res://scripts/exchange_ui.gd").new()
	ex._ready()
	ex.open_panel()
	# Ukuran manual untuk tombol sumber (tanpa layout tree).
	ex._source_btn.position = Vector2(20, 200)
	ex._source_btn.size = Vector2(60, 60)
	var mp_src: Vector2 = ex._source_btn.get_global_rect().get_center()
	_check(ex.try_drop_slot(mp_src, "K", 5, "inv"), "drop huruf ke slot sumber diterima")
	_check(str(ex._source.get("letter", "")) == "K" and int(ex._source.get("origin", -1)) == 5,
		"huruf + origin tersimpan di slot sumber")
	_check(not ex.try_drop_slot(mp_src, "Z", 6, "inv"), "drop ke slot sumber terisi ditolak")
	ex.queue_free()

	# --- Bug 2026-10-13 (2): gerak tetap boleh saat inventory saja terbuka ---
	_check(not NetProto.movement_blocked(false, false, false),
		"gerak BOLEH saat hanya inventory terbuka")
	_check(NetProto.movement_blocked(true, false, false), "gerak diblokir saat mati")
	_check(NetProto.movement_blocked(false, true, false), "gerak diblokir saat mesin tukar terbuka")
	_check(NetProto.movement_blocked(false, false, true), "gerak diblokir saat minigame terbuka")
	_check(NetProto.movement_blocked(false, true, true), "gerak diblokir saat exchange+minigame")

	# --- Bug 2026-10-14: tukar huruf MP — huruf reserved di slot ---
	# Invariant: origin huruf reserved selalu null di grid lokal; grid yang
	# dikirim ke server = grid lokal + reserved -> selalu permutasi valid.
	var mock := _MockGame.new()
	mock.inventory.grid[5] = "A"
	mock.inventory.grid[7] = "M"
	mock.inventory.grid[9] = "N"
	var ex2 = load("res://scripts/exchange_ui.gd").new()
	ex2._ready()
	ex2.game = mock
	ex2._source = {"letter": "A", "origin": 5}
	ex2._payments[0] = {"letter": "M", "origin": 7}
	ex2._payments[1] = {"letter": "N", "origin": 9}
	mock.inventory.grid[5] = null
	mock.inventory.grid[7] = null
	mock.inventory.grid[9] = null
	var rs: Array = ex2.get_reserved()
	_check(rs.size() == 3, "get_reserved: 3 huruf (sumber+2 bayar)")
	var view: Array = SpellInventory.reserved_grid_view(mock.inventory.grid, rs)
	_check(str(view[5]) == "A" and str(view[7]) == "M" and str(view[9]) == "N",
		"reserved_grid_view: huruf kembali ke origin")
	# Server menerima merged grid sebagai permutasi valid (tidak reject).
	var srv_grid: Array = []
	srv_grid.resize(SpellInventory.CELLS)
	srv_grid.fill(null)
	srv_grid[5] = "A"
	srv_grid[7] = "M"
	srv_grid[9] = "N"
	var spx := ServerPlayer.new()
	spx._ready()
	spx.inv.grid = srv_grid
	_check(spx.grid_is_permutation(view), "server: merged grid = permutasi valid")
	# Reserved kosong -> view identik dengan grid.
	var view2: Array = SpellInventory.reserved_grid_view(mock.inventory.grid, [])
	_check(view2 == mock.inventory.grid, "reserved_grid_view kosong = grid asli")
	# Origin di luar jangkauan / sudah terisi -> diabaikan (tidak corrupt).
	var bad_view: Array = SpellInventory.reserved_grid_view(
		mock.inventory.grid, [{"letter": "X", "origin": 999}])
	_check(bad_view[5] == null, "reserved origin invalid diabaikan")
	# Ganti target A->C (biaya 2) lalu A->B (biaya 1): kelebihan bayar N@9
	# kembali KE ORIGINNYA, bukan add_letters.
	ex2._target = "C"
	ex2._after_change()
	ex2._target = "B"
	ex2._after_change()
	_check(str(mock.inventory.grid[9]) == "N", "kelebihan bayar kembali ke origin")
	_check((ex2._payments[1] as Dictionary).is_empty(), "slot bayar berlebih dikosongkan")
	ex2.queue_free()
	spx.queue_free()

	# --- Swap slot->cell: huruf tergusur pakai origin LAMA ---
	var iu = load("res://scripts/inventory_ui.gd").new()
	iu._ready()
	var mock2 := _MockGame.new()
	mock2.inventory.grid[10] = "B"
	iu.game = mock2
	var ex3 = load("res://scripts/exchange_ui.gd").new()
	ex3._ready()
	ex3.game = mock2
	ex3._source = {"letter": "A", "origin": 5}
	iu.exchange = ex3
	iu._dragging = true
	iu._drag_payload = {"kind": "source", "slot": -1, "origin": 5, "letter": "A"}
	var mpos: Vector2 = iu.get_global_mouse_position()
	iu._cells[10].position = mpos - Vector2(28, 28)
	iu._cells[10].size = Vector2(56, 56)
	iu._finish_drag()
	_check(str(mock2.inventory.grid[10]) == "A", "swap: huruf slot pindah ke cell")
	var s3: Dictionary = ex3._source
	_check(str(s3.get("letter", "")) == "B" and int(s3.get("origin", -1)) == 5,
		"swap: huruf tergusur ke slot dengan origin LAMA (lubang)")
	ex3.queue_free()
	iu.queue_free()

	# --- Server: respawn, cooldown puzzle, event sword, exchange ---
	var MpSrv = load("res://scripts/mp_server.gd")
	var srv = MpSrv.new()
	var room = MpSrv.Room.new()
	room.started = true
	var p3 := ServerPlayer.new()
	p3._ready()
	p3.pid = 1
	p3.spawn_pos = Vector2(760, 460)
	p3.alive = false
	p3.hp = 0
	p3.respawn_left = 0.0
	srv._respawn_player(room, p3)
	_check(p3.alive, "respawn: hidup kembali (bug: dulu mati selamanya)")
	_check(p3.hp == p3.max_hp and p3.ep == p3.max_ep, "respawn: HP/EP penuh")
	_check(p3.protect_left > 0.0, "respawn: proteksi 3 dtk aktif")
	_check(p3.position == Vector2(760, 460), "respawn: di titik spawn tetap")
	p3.alive = true
	# 3b1: belum ada mesin puzzle — pakai sentinel PUZZLE_POS agar validasi
	# jarak lolos; yang diuji: cooldown + scatter containment (walkable).
	p3.position = Map3B.PUZZLE_POS
	srv._on_puzzle_done(room, p3)
	_check(absf(p3.puzzle_cd - NetProto.PUZZLE_COOLDOWN) < 0.001,
		"puzzle_done: cooldown 30 dtk diset")
	_check(room.pickups.size() == 5, "puzzle_done: 5 huruf buyar")
	var pk_walk := true
	for u in room.pickups:
		if not MapData.is_walkable(u["pos"]):
			pk_walk = false
	_check(pk_walk, "puzzle_done: semua pickup walkable (containment 3b1)")
	srv._on_puzzle_done(room, p3)
	_check(room.pickups.size() == 5, "puzzle_done saat cooldown: ditolak")
	p3.words = ["SWORD"]
	p3.ep = 100
	srv._on_weapon(room, p3, "SWORD")
	var has_sword := false
	for e in room.events:
		if str((e as Dictionary).get("k", "")) == "sword":
			has_sword = true
	_check(has_sword, "event sword dikirim ke semua client")
	_check(p3.ep == 92, "sword: biaya 8 EP")
	var p4 := ServerPlayer.new()
	p4._ready()
	p4.pid = 2
	p4.alive = true
	p4.inv.grid[5] = "A"
	p4.inv.grid[7] = "M"
	p4.inv.grid[9] = "N"
	srv._on_exchange(room, p4, {"src": 5, "target": "C", "letter": "A", "pay": [7, 9]})
	_check(str(p4.inv.grid[5]) == "C" and p4.inv.grid[7] == null and p4.inv.grid[9] == null,
		"exchange server: sumber jadi target, bayar hangus")
	p4.inv.grid[5] = "Z"
	srv._on_exchange(room, p4, {"src": 5, "target": "C", "letter": "A", "pay": [7, 9]})
	_check(str(p4.inv.grid[5]) == "Z", "exchange: validasi gagal -> grid tidak berubah")
	p3.queue_free()
	p4.queue_free()

	# --- Bug 2026-10-14: refresh inventory setelah tukar berhasil (MP) ---
	# Alur: drop huruf ke slot -> confirm -> server tukar -> grid_sync(ex=true)
	# -> grid lokal = hasil tukar, slot bersih, UI grid ter-refresh.
	# (Regresi: dulu server tidak kirim flag ex -> client ambil cabang else ->
	#  lubang reserved dipertahankan -> huruf hasil tukar tidak tampil.)
	var mock3 := _MockGame.new()
	mock3.inventory.grid[5] = "T"
	mock3.inventory.grid[8] = "O"
	var iu3 = load("res://scripts/inventory_ui.gd").new()
	iu3._ready()
	iu3.game = mock3
	var ex4 = load("res://scripts/exchange_ui.gd").new()
	ex4._ready()
	ex4.game = mock3
	# Simulasi drop: T (origin 5) ke slot sumber, O (origin 8) ke pembayaran.
	ex4._source = {"letter": "T", "origin": 5}
	ex4._payments[0] = {"letter": "O", "origin": 8}
	mock3.inventory.grid[5] = null
	mock3.inventory.grid[8] = null
	# Simulasi grid hasil tukar dari server: T->U (biaya 1), O hangus.
	var srv_cells: Array = mock3.inventory.grid.duplicate()
	srv_cells[5] = "U"
	# Persis seperti cabang exchanged di mp_game._on_grid_sync:
	ex4.apply_server_result(mock3.inventory, srv_cells)
	iu3.refresh(mock3.inventory, [])
	_check(str(mock3.inventory.grid[5]) == "U", "exchanged: grid lokal = hasil tukar (U)")
	_check(mock3.inventory.grid[8] == null, "exchanged: huruf bayar hangus")
	_check(ex4._source.is_empty() and (ex4._payments[0] as Dictionary).is_empty(),
		"exchanged: slot sumber & bayar dibersihkan")
	_check(iu3._cells[5].text == "U", "exchanged: UI grid ter-refresh (U tampil)")
	_check(iu3._cells[8].text == "", "exchanged: UI cell bayar kosong")
	iu3.queue_free()
	ex4.queue_free()

	p.queue_free()
	q.queue_free()
	print("test_fase3: %d lolos, %d gagal" % [_passed, _failed])
	quit(_failed)


## Mock game untuk test exchange: punya inventory + on_inventory_changed().
class _MockGame extends RefCounted:
	var inventory: SpellInventory
	var changed := 0

	func _init() -> void:
		inventory = SpellInventory.new()

	func on_inventory_changed() -> void:
		changed += 1