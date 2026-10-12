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


const DESCRIPTIONS: Dictionary = {
	"PISTOL": "Pistol: tembak proyektil (dmg 50, 10 EP)",
	"SWORD": "Pedang: tebas ke arah hadap (dmg 25, 8 EP)",
	"TRAP": "Jebakan x3: pasang di mana saja (15 EP)",
	"HP": "+50 max HP & heal 50 (bisa stack)",
	"EP": "+25 max EP & +2 regen/dtk (bisa stack)",
	"SP": "+15% kecepatan jalan (bisa stack)",
}
