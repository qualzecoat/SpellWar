class_name DarknessOverlay
extends CanvasLayer
## Overlay kegelapan vision ala Among Us untuk client multiplayer (Fase 3).
##
## Menggantikan implementasi lama (Sprite2D radial 512px yang ditempel di posisi
## pemain) yang hanya menggelapkan KOTAK di tengah layar. Pendekatan baru:
## CanvasLayer full-rect + shader canvas_item — seluruh layar gelap kecuali
## lingkaran lembut di posisi screen pemain lokal. Resolution-independent di
## bawah stretch canvas_items + expand: posisi lubang & radius dihitung dalam
## koordinat ternormalisasi tiap frame (termasuk camera smoothing & offset
## geser kamera saat inventory terbuka).

const SHADER_PATH := "res://shaders/darkness.gdshader"
const INNER_WORLD := 180.0 # px dunia: terang penuh di dalam radius ini
const OUTER_WORLD := 420.0 # px dunia: gelap penuh di luar radius ini (= NetProto.VISION_RADIUS)

var _target: Node2D = null
var _mat: ShaderMaterial
var _rect: ColorRect


func _ready() -> void:
	# Di atas dunia (default), di bawah HUD (HUD layer=10, lihat scenes/hud.tscn).
	layer = 2
	var sh: Shader = load(SHADER_PATH)
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)


func setup(target: Node2D) -> void:
	_target = target


## Hitungan murni (tanpa tree) agar bisa diuji headless.
## xform: transform canvas->viewport (piksel viewport), sudah termasuk kamera,
## smoothing, offset, dan stretch scale. win_size: ukuran window piksel aktual.
static func compute_params(xform: Transform2D, win_size: Vector2, world_pos: Vector2) -> Dictionary:
	var hole_uv := Vector2(0.5, 0.5)
	var aspect := 16.0 / 9.0
	var inner_h := 0.0
	var outer_h := 0.0
	var ppw := absf(xform.get_scale().x) # piksel viewport per px dunia
	if win_size.x > 0.0 and win_size.y > 0.0 and ppw > 0.0:
		var hole_px: Vector2 = xform * world_pos
		hole_uv = hole_px / win_size
		aspect = win_size.x / win_size.y
		inner_h = INNER_WORLD * ppw / win_size.y
		outer_h = OUTER_WORLD * ppw / win_size.y
	return {
		"hole_uv": hole_uv,
		"aspect": aspect,
		"inner_h": inner_h,
		"outer_h": outer_h,
	}


func _process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var vp := get_viewport()
	if vp == null or _mat == null:
		return
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or win.y <= 0.0:
		win = vp.get_visible_rect().size
	var prm := compute_params(vp.get_canvas_transform(), win, _target.global_position)
	_mat.set_shader_parameter("u_hole_uv", prm["hole_uv"])
	_mat.set_shader_parameter("u_aspect", prm["aspect"])
	_mat.set_shader_parameter("u_inner_h", prm["inner_h"])
	_mat.set_shader_parameter("u_outer_h", prm["outer_h"])
