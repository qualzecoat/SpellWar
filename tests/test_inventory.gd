extends SceneTree
## Uji logika inventory & deteksi kata secara headless.
## Jalankan: godot --headless --path <project> -s res://tests/test_inventory.gd
## Exit code = jumlah kegagalan (0 = semua lolos).
## Sengaja untyped agar tidak bergantung pada cache global class.

var _passed := 0
var _failed := 0
var _InventoryScript: GDScript


func _check(ok: bool, name: String) -> void:
	if ok:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		printerr("FAIL: " + name)


func _fill(inv, word: String, r: int, c0: int, horiz: bool) -> void:
	for k in word.length():
		var idx: int = r * 8 + c0 + k if horiz else (r + k) * 8 + c0
		inv.grid[idx] = word.substr(k, 1)


## Helper untuk API scan_words() baru (Array of {word, dir, cells}).
func _words_of(matches: Array) -> Array:
	var out: Array = []
	for m in matches:
		out.append(str(m["word"]))
	return out


func _dir_of(matches: Array, word: String) -> String:
	for m in matches:
		if str(m["word"]) == word:
			return str(m["dir"])
	return ""


func _count_of(matches: Array, word: String) -> int:
	var n := 0
	for m in matches:
		if str(m["word"]) == word:
			n += 1
	return n


func _init() -> void:
	_InventoryScript = load("res://scripts/inventory.gd")

	# 1. SWORD horizontal terdeteksi
	var inv1 = _InventoryScript.new()
	_fill(inv1, "SWORD", 2, 1, true)
	_check(_words_of(inv1.scan_words()).has("SWORD"), "SWORD horizontal terdeteksi")

	# 2. HP vertikal terdeteksi + arah benar
	var inv2 = _InventoryScript.new()
	_fill(inv2, "HP", 0, 5, false)
	var f2: Array = inv2.scan_words()
	_check(_words_of(f2).has("HP") and _dir_of(f2, "HP") == "v", "HP vertikal terdeteksi")

	# 3. Dua kata sekaligus (tanpa overlap) terdeteksi
	var inv3 = _InventoryScript.new()
	_fill(inv3, "SWORD", 2, 1, true)
	_fill(inv3, "HP", 5, 0, true)
	var f3: Array = inv3.scan_words()
	_check(_words_of(f3).has("SWORD") and _words_of(f3).has("HP"), "SWORD + HP bersamaan terdeteksi")

	# 4. Kata pecah (satu huruf digeser) -> tidak terdeteksi
	var inv4 = _InventoryScript.new()
	_fill(inv4, "SWORD", 2, 1, true)
	inv4.move_letter(2 * 8 + 3, 7 * 8 + 7)
	_check(not _words_of(inv4.scan_words()).has("SWORD"), "SWORD pecah tidak terdeteksi")

	# 5. add_letters mengisi cell kosong pertama
	var inv5 = _InventoryScript.new()
	var placed: Array = inv5.add_letters(["A", "B", "C", "D", "E"])
	_check(placed == [0, 1, 2, 3, 4], "add_letters isi cell 0-4")
	_check(inv5.empty_count() == 59, "empty_count 59 setelah 5 huruf")

	# 6. move_letter menukar isi cell
	var inv6 = _InventoryScript.new()
	inv6.grid[10] = "X"
	inv6.move_letter(10, 20)
	_check(inv6.grid[20] == "X" and inv6.grid[10] == null, "move_letter pindah huruf")

	# 7. Huruf acak tidak membentuk kata valid
	var inv7 = _InventoryScript.new()
	_fill(inv7, "QXZ", 0, 0, true)
	_check(inv7.scan_words().is_empty(), "huruf acak bukan kata")

	# 8. FIX 2026-10-12 (Fix 4): kata yang sama BOLEH tercatat berkali-kali (stacking)
	var inv8 = _InventoryScript.new()
	_fill(inv8, "SP", 0, 0, true)
	_fill(inv8, "SP", 2, 0, true)
	_check(_count_of(inv8.scan_words(), "SP") == 2, "SP ganda tercatat 2x (stacking)")

	print("=== hasil: ", _passed, " lolos, ", _failed, " gagal ===")
	quit(_failed)
