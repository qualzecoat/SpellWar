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

const DESCRIPTIONS: Dictionary = {
	"PISTOL": "Pistol: tembak proyektil (dmg 50, 10 EP)",
	"SWORD": "Pedang: tebas ke arah hadap (dmg 25, 8 EP)",
	"TRAP": "Jebakan x3: pasang di mana saja (15 EP)",
	"HP": "+50 max HP & heal 50 (bisa stack)",
	"EP": "+25 max EP & +2 regen/dtk (bisa stack)",
	"SP": "+15% kecepatan jalan (bisa stack)",
}
