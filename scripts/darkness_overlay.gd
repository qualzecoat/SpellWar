class_name DarknessOverlay
extends CanvasLayer
## Overlay kegelapan vision ala Among Us untuk client multiplayer (Fase 3).
##
## CanvasLayer full-rect + shader canvas_item — seluruh layar gelap kecuali
## lingkaran lembut di posisi screen pemain lokal.
##
## Perhitungan posisi lubang memakai KAMERA (bukan canvas_transform):
## canvas_transform memetakan ke ruang visible_rect logis, sedangkan kode lama
## membaginya dengan ukuran window OS — satuannya tercampur sehingga di HP
## (aspect lebar + expand) lubang bergeser dari pemain. Formula kamera memakai
## satuan konsisten: world_view = visible_rect.size / zoom (satuan dunia yang
## terlihat), lalu hole_uv = 0.5 + (pemain - tengah_kamera) / world_view.
## Radius dikirim dalam px dunia (180/420) dan dihitung di shader.

const SHADER_PATH := "res://shaders/darkness.gdshader"
const INNER_WORLD := 180.0 # px dunia: terang penuh di dalam radius ini
const OUTER_WORLD := 420.0 # px dunia: gelap penuh di luar radius ini (= NetProto.VISION_RADIUS)

var _target: Node2D = null
var _mat: ShaderMaterial
var _rect: ColorRect


func _ready() -> void:
	# Di atas dunia (default), di bawah HUD (HUD layer=10).
	layer = 2
	var sh: Shader = load(SHADER_PATH)
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("u_inner", INNER_WORLD)
	_mat.set_shader_parameter("u_outer", OUTER_WORLD)
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)


func setup(target: Node2D) -> void:
	_target = target


## Hitungan murni (tanpa tree) agar bisa diuji headless.
## cam_center: posisi dunia di tengah layar (Camera2D.get_screen_center_position()).
## zoom: Camera2D.zoom. visible_size: Viewport.get_visible_rect().size.
## world_pos: posisi dunia pemain. Hasil hole_uv dalam 0..1.
static func compute_params(cam_center: Vector2, zoom: Vector2, visible_size: Vector2, world_pos: Vector2) -> Dictionary:
	var hole_uv := Vector2(0.5, 0.5)
	var aspect := 16.0 / 9.0
	var view_h_world := 648.0
	if visible_size.x > 0.0 and visible_size.y > 0.0 and zoom.x > 0.0 and zoom.y > 0.0:
		var world_view := visible_size / zoom
		hole_uv = Vector2(0.5, 0.5) + (world_pos - cam_center) / world_view
		aspect = visible_size.x / visible_size.y
		view_h_world = world_view.y
	return {
		"hole_uv": hole_uv,
		"aspect": aspect,
		"view_h_world": view_h_world,
	}


func _process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var vp := get_viewport()
	if vp == null or _mat == null:
		return
	var prm: Dictionary
	var cam := vp.get_camera_2d()
	if cam != null:
		prm = compute_params(cam.get_screen_center_position(), cam.zoom, vp.get_visible_rect().size, _target.global_position)
	else:
		# Fallback: anggap pemain di tengah layar.
		var vs := vp.get_visible_rect().size
		prm = compute_params(_target.global_position, Vector2.ONE, vs, _target.global_position)
	_mat.set_shader_parameter("u_hole_uv", prm["hole_uv"])
	_mat.set_shader_parameter("u_aspect", prm["aspect"])
	_mat.set_shader_parameter("u_view_h_world", prm["view_h_world"])
