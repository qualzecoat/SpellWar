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


## Scan seluruh grid. Return {kata: {"dir": "h"/"v", "cells": Array[int]}}.
## Tiap kata maksimal tercatat sekali (cukup untuk aturan aktif/nonaktif Fase 1).
func scan_words() -> Dictionary:
	var found: Dictionary = {}
	var used_h: Dictionary = {}
	var used_v: Dictionary = {}
	for word in WordDB.WORDS.keys():
		# --- horizontal ---
		for r in SIZE:
			var line := _row_string(r)
			var start := 0
			while true:
				var at := line.find(word, start)
				if at == -1:
					break
				var cells: Array = []
				var ok := true
				for k in word.length():
					var ci := r * SIZE + at + k
					if used_h.has(ci):
						ok = false
						break
					cells.append(ci)
				if ok and not found.has(word):
					for ci in cells:
						used_h[ci] = true
					found[word] = {"dir": "h", "cells": cells}
				start = at + 1
		# --- vertikal ---
		for c in SIZE:
			var line := _col_string(c)
			var start := 0
			while true:
				var at := line.find(word, start)
				if at == -1:
					break
				var cells: Array = []
				var ok := true
				for k in word.length():
					var ci := (at + k) * SIZE + c
					if used_v.has(ci):
						ok = false
						break
					cells.append(ci)
				if ok and not found.has(word):
					for ci in cells:
						used_v[ci] = true
					found[word] = {"dir": "v", "cells": cells}
				start = at + 1
	return found
