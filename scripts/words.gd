class_name WordDB
extends RefCounted
## Daftar kata valid Fase 2 (lengkap). kind: "weapon" | "stat".

const WORDS: Dictionary = {
	"PISTOL": {"kind": "weapon"},
	"SWORD": {"kind": "weapon"},
	"TRAP": {"kind": "weapon"},
	"HP": {"kind": "stat"},
	"EP": {"kind": "stat"},
	"SP": {"kind": "stat"},
}

## Filter match kata: senjata TIDAK stack — hanya match PERTAMA tiap kata
## weapon yang dipertahankan (di-highlight + memberi efek); duplikat
## berikutnya dibuang. Jika match yang aktif pecah, duplikat yang masih
## utuh otomatis naik menjadi aktif karena scan selalu mengambil yang
## pertama ditemukan. Stat BOLEH stack (semua match dipertahankan).
## Dipakai oleh game.rescan_words(). matches: Array of {word, dir, cells}.
static func filter_weapon_first(matches: Array) -> Array:
	var seen_weapon: Dictionary = {}
	var out: Array = []
	for m in matches:
		var w := str(m["word"])
		if str(WORDS[w]["kind"]) == "weapon":
			if seen_weapon.has(w):
				continue
			seen_weapon[w] = true
		out.append(m)
	return out


## Key unik sebuah match (untuk tracking stabilitas antar-scan):
## "KATA@sel1,sel2,..." dengan sel terurut.
static func match_key(m: Dictionary) -> String:
	var cells: Array = (m["cells"] as Array).duplicate()
	cells.sort()
	var parts := PackedStringArray()
	for c in cells:
		parts.append(str(c))
	return "%s@%s" % [str(m["word"]), ",".join(parts)]


## FIX 2026-10-13 (Fix 2): seleksi STABIL kata senjata antar pemindaian.
## - Match senjata yang sedang aktif (active_keys: word -> key) DIPERTAHANKAN
##   selama masih ada di hasil scan — TIDAK berpindah ke duplikat yang baru
##   tersusun (mencegah kata aktif mati/nyala tak sengaja).
## - Jika tidak ada yang aktif / yang aktif pecah -> match pertama jadi aktif.
## - Stat selalu dipertahankan semua (boleh stack).
## Return {"selected": Array, "active_keys": Dictionary,
##         "all_keys": Dictionary, "dup_words": Array}:
## - selected: match stat + 1 match aktif per kata weapon (highlight & efek).
## - active_keys: word -> key aktif baru (disimpan game untuk scan berikut).
## - all_keys: word -> Array key SEMUA match scan ini (deteksi duplikat baru).
## - dup_words: kata weapon yang punya >1 match (kandidat toast "sudah aktif").
static func select_stable_weapons(matches: Array, active_keys: Dictionary) -> Dictionary:
	var groups: Dictionary = {}
	var selected: Array = []
	for m in matches:
		var w := str(m["word"])
		if str(WORDS[w]["kind"]) == "weapon":
			if not groups.has(w):
				groups[w] = []
			(groups[w] as Array).append(m)
		else:
			selected.append(m)
	var new_active: Dictionary = {}
	var all_keys: Dictionary = {}
	var dup_words: Array = []
	for w in groups.keys():
		var ms: Array = groups[w]
		var keys: Array = []
		for m in ms:
			keys.append(match_key(m))
		all_keys[w] = keys
		var prev_key := str(active_keys.get(w, ""))
		var chosen: Dictionary = {}
		if prev_key != "":
			for m in ms:
				if match_key(m) == prev_key:
					chosen = m
					break
		if chosen.is_empty():
			chosen = ms[0]
		selected.append(chosen)
		new_active[w] = match_key(chosen)
		if ms.size() > 1:
			dup_words.append(w)
	return {"selected": selected, "active_keys": new_active,
		"all_keys": all_keys, "dup_words": dup_words}


const DESCRIPTIONS: Dictionary = {
	"PISTOL": "Pistol: tembak proyektil (dmg 50, 10 EP)",
	"SWORD": "Pedang: tebas ke arah hadap (dmg 25, 8 EP)",
	"TRAP": "Jebakan x3: pasang di mana saja (15 EP)",
	"HP": "+50 max HP & heal 50 (bisa stack)",
	"EP": "+25 max EP & +2 regen/dtk (bisa stack)",
	"SP": "+15% kecepatan jalan (bisa stack)",
}
