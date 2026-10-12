class_name WordDB
extends RefCounted
## Daftar kata valid. Struktur generik — tambah entri baru untuk kata Fase 2+
## (PISTOL, TRAP, EP, SP). kind: "weapon" | "stat".

const WORDS: Dictionary = {
	"SWORD": {"kind": "weapon"},
	"HP": {"kind": "stat"},
}

const DESCRIPTIONS: Dictionary = {
	"SWORD": "Pedang: tebas ke arah hadap",
	"HP": "+50 max HP & heal 50",
}
