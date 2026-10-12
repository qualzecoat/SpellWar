extends SceneTree
## Uji logika Mesin Tukar Huruf secara headless.
## Jalankan: godot --headless --path <project> -s res://tests/test_exchange.gd
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


func _init() -> void:
	var Exchange = load("res://scripts/exchange.gd")
	var InvScript = load("res://scripts/inventory.gd")

	# --- biaya jarak melingkar ---
	_check(Exchange.cost("A", "C") == 2, "biaya A->C = 2")
	_check(Exchange.cost("Z", "A") == 1, "biaya Z->A = 1 (melingkar)")
	_check(Exchange.cost("Z", "X") == 2, "biaya Z->X = 2 (melingkar mundur)")
	_check(Exchange.cost("A", "Z") == 1, "biaya A->Z = 1 (melingkar)")
	_check(Exchange.cost("M", "Z") == 13, "biaya M->Z = 13 (maks)")
	_check(Exchange.cost("A", "A") == 0, "biaya A->A = 0")
	_check(Exchange.cost("C", "A") == 2, "biaya simetris C->A = 2")
	_check(Exchange.cost("N", "A") == 13, "biaya N->A = 13 (maks)")

	# --- apply: sumber BERUBAH (tidak hangus), pembayaran hangus ---
	var inv = InvScript.new()
	inv.grid[5] = "A"    # sumber
	inv.grid[10] = "Q"   # bayar 1
	inv.grid[11] = "W"   # bayar 2
	inv.grid[20] = "S"   # tidak tersentuh
	Exchange.apply(inv, 5, "C", [10, 11])
	_check(inv.grid[5] == "C", "sumber A berubah jadi C (tetap di cell)")
	_check(inv.grid[10] == null and inv.grid[11] == null, "huruf bayar hangus")
	_check(inv.grid[20] == "S", "cell lain tidak tersentuh")

	# --- apply jarak 1: Z->A bayar 1 huruf ---
	var inv2 = InvScript.new()
	inv2.grid[0] = "Z"
	inv2.grid[1] = "K"
	Exchange.apply(inv2, 0, "A", [1])
	_check(inv2.grid[0] == "A" and inv2.grid[1] == null, "Z->A: sumber jadi A, 1 bayar hangus")

	# --- simulasi batal: huruf "di tangan" kembali via add_letters ---
	var inv3 = InvScript.new()
	inv3.grid[3] = "A"
	inv3.grid[7] = "B"
	var held: Array = ["A", "B"]
	inv3.grid[3] = null
	inv3.grid[7] = null
	var placed: Array = inv3.add_letters(held)
	_check(placed.size() == 2, "batal: 2 huruf kembali ke inventory")
	var back: Array = []
	for i in placed:
		back.append(inv3.grid[i])
	back.sort()
	_check(back == ["A", "B"], "batal: huruf yang kembali benar")

	# --- validasi huruf ---
	_check(Exchange.is_valid_letter("A") and Exchange.is_valid_letter("Z"), "A/Z valid")
	_check(not Exchange.is_valid_letter("a"), "huruf kecil tidak valid")
	_check(not Exchange.is_valid_letter("AB"), "2 huruf tidak valid")

	print("=== hasil: ", _passed, " lolos, ", _failed, " gagal ===")
	quit(_failed)
