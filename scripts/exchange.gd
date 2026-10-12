class_name SpellExchange
extends RefCounted
## Logika Mesin Tukar Huruf (murni, bisa diuji headless).
## Biaya = JARAK MELINGKAR alfabet: d = min(|a-b|, 26-|a-b|), dengan A=0..Z=25.
## Contoh: A->C = 2, Z->A = 1, Z->X = 2, A->Z = 1, M->Z = 13.

const MAX_COST := 13


static func letter_index(letter: String) -> int:
	return letter.unicode_at(0) - 65


static func is_valid_letter(letter: String) -> bool:
	if letter.length() != 1:
		return false
	var i := letter_index(letter)
	return i >= 0 and i <= 25


static func cost(from_letter: String, to_letter: String) -> int:
	var d: int = absi(letter_index(from_letter) - letter_index(to_letter))
	return mini(d, 26 - d)


## Terapkan penukaran pada model inventory:
## - cell sumber BERUBAH menjadi huruf target (tidak hangus),
## - cell pembayaran dikosongkan (hangus).
static func apply(inventory: SpellInventory, source_idx: int, target: String, payment_idxs: Array) -> void:
	inventory.grid[source_idx] = target
	for idx in payment_idxs:
		inventory.grid[int(idx)] = null
