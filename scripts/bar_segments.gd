class_name BarSegments
extends Control
## Overlay garis segmentasi di atas ProgressBar ala Honor of Kings:
## garis vertikal yang membagi bar jadi kolom-kolom sama besar
## (HP tiap 50, EP tiap 25), otomatis ketengah mengikuti max saat ini.
## Garis sedikit menonjol di atas & bawah bar agar jelas terlihat.
## FIX 2026-10-13 (revisi): sinkron rect paksa tiap frame (anchor saja
## terbukti tidak menutup bar dengan benar) + gaya HoK.

var step := 50.0
var max_value := 100.0
var protrude := 3.0  # garis menonjol di atas & bawah bar (px)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	# Sinkron paksa ke rect parent (ProgressBar) — jangan andalkan anchor saja.
	var p := get_parent() as Control
	if p != null:
		if position != Vector2.ZERO:
			position = Vector2.ZERO
		if size != p.size:
			size = p.size
			queue_redraw()


func set_params(p_step: float, p_max: float) -> void:
	step = p_step
	max_value = p_max
	queue_redraw()


func _draw() -> void:
	if max_value <= 0.0 or step <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return
	# Jumlah kolom dibulatkan: garis selalu membagi rata & otomatis ketengah.
	# Mis. max 100/step 50 -> 2 kolom -> 1 garis di tengah.
	var n := maxi(1, int(round(max_value / step)))
	for i in range(1, n):
		var x := size.x * float(i) / float(n)
		draw_line(Vector2(x, -protrude), Vector2(x, size.y + protrude),
			Color(0, 0, 0, 0.75), 3.0)
