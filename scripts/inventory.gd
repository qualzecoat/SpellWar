class_name SpellInventory
extends RefCounted
## Model inventory grid 8x8 + deteksi kata ala TTS (teka-teki silang).
## - 1 huruf menempati 1 cell.
## - Kata bisa vertikal maupun horizontal.
## - 1 huruf boleh ikut 1 kata vertikal + 1 kata horizontal sekaligus (sharing).

const SIZE := 8
const CELLS := 64

var grid: Array = []  # 64 elemen: null atau String 1 huruf


func _init() -> void:
	grid.resize(CELLS)
	grid.fill(null)


func empty_count() -> int:
	var n := 0
	for cell in grid:
		if cell == null:
			n += 1
	return n


## Tambah huruf ke cell kosong pertama. Return daftar index yang terisi.
func add_letters(letters: Array) -> Array:
	var placed: Array = []
	for letter in letters:
		var idx := grid.find(null)
		if idx == -1:
			break
		grid[idx] = str(letter)
		placed.append(idx)
	return placed


## Pindah/tukar huruf antar cell.
func move_letter(from_idx: int, to_idx: int) -> void:
	if from_idx == to_idx:
		return
	if from_idx < 0 or from_idx >= CELLS:
		return
	if to_idx < 0 or to_idx >= CELLS:
		return
	var tmp = grid[to_idx]
	grid[to_idx] = grid[from_idx]
	grid[from_idx] = tmp


func _row_string(row: int) -> String:
	var s := ""
	for c in SIZE:
		var v = grid[row * SIZE + c]
		s += v if v != null else "."
	return s


func _col_string(col: int) -> String:
	var s := ""
	for r in SIZE:
		var v = grid[r * SIZE + col]
		s += v if v != null else "."
	return s


## Hitung jumlah tiap huruf di grid. Return {huruf: jumlah}.
func letter_counts() -> Dictionary:
	var counts: Dictionary = {}
	for v in grid:
		if v != null:
			var k := str(v)
			counts[k] = int(counts.get(k, 0)) + 1
	return counts


## Apakah kata bisa dibentuk dari huruf yang ada (berdasar jumlah huruf)?
## Aproksimasi untuk hint; deteksi pasti tetap via scan_words().
static func can_form(word: String, counts: Dictionary) -> bool:
	var need: Dictionary = {}
	for k in word.length():
		var c := word.substr(k, 1)
		need[c] = int(need.get(c, 0)) + 1
	for c in need.keys():
		if int(counts.get(c, 0)) < int(need[c]):
			return false
	return true
## Tiap kata maksimal tercatat sekali (cukup untuk aturan aktif/nonaktif Fase 1).
func scan_words() -> Dictionary:
	var found: Dictionary = {}
	var used_h: Dictionary = {}
	var used_v: Dictionary = {}
	for word in WordDB.WORDS.keys():
		var w: String = word
		var wlen: int = w.length()
		# --- horizontal ---
		for r in SIZE:
			var line := _row_string(r)
			var start := 0
			while true:
				var at := line.find(w, start)
				if at == -1:
					break
				var cells: Array = []
				var ok := true
				for k in wlen:
					var ci := r * SIZE + at + k
					if used_h.has(ci):
						ok = false
						break
					cells.append(ci)
				if ok and not found.has(w):
					for ci in cells:
						used_h[ci] = true
					found[w] = {"dir": "h", "cells": cells}
				start = at + 1
		# --- vertikal ---
		for c in SIZE:
			var line := _col_string(c)
			var start := 0
			while true:
				var at := line.find(w, start)
				if at == -1:
					break
				var cells: Array = []
				var ok := true
				for k in wlen:
					var ci := (at + k) * SIZE + c
					if used_v.has(ci):
						ok = false
						break
					cells.append(ci)
				if ok and not found.has(w):
					for ci in cells:
						used_v[ci] = true
					found[w] = {"dir": "v", "cells": cells}
				start = at + 1
	return found
