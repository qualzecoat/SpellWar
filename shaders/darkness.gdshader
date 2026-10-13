shader_type canvas_item;
// Overlay kegelapan vision ala Among Us.
// Seluruh layar digelapkan kecuali lingkaran lembut di sekitar pemain lokal.
// u_hole_uv: posisi pemain dalam UV (0..1). Jarak dihitung dalam px dunia
// (koreksi aspect dulu, lalu kali tinggi dunia yang terlihat) agar radius
// lingkaran konsisten di semua aspect ratio & resolusi.

uniform vec2 u_hole_uv = vec2(0.5, 0.5);
uniform float u_aspect = 1.77778; // lebar / tinggi viewport
uniform float u_view_h_world = 648.0; // tinggi dunia yang terlihat (px dunia)
uniform float u_inner = 180.0; // radius terang-penuh (px dunia)
uniform float u_outer = 420.0; // radius gelap-penuh (px dunia)
uniform vec4 u_dark : source_color = vec4(0.02, 0.02, 0.06, 0.95); // warna kegelapan

void fragment() {
	vec2 auv = vec2(UV.x * u_aspect, UV.y);
	vec2 ah = vec2(u_hole_uv.x * u_aspect, u_hole_uv.y);
	float d = distance(auv, ah) * u_view_h_world;
	float t = smoothstep(u_inner, u_outer, d);
	COLOR = vec4(u_dark.rgb, u_dark.a * t);
}
