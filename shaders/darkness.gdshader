shader_type canvas_item;
// Overlay kegelapan vision ala Among Us.
// Seluruh layar digelapkan kecuali lingkaran lembut di sekitar pemain lokal.
// Semua uniform di-update tiap frame dari scripts/darkness_overlay.gd dalam
// koordinat ternormalisasi (resolution-independent, aman untuk stretch mode
// canvas_items + expand karena tidak bergantung pada ukuran piksel absolut).

uniform vec2 u_hole_uv = vec2(0.5, 0.5); // posisi pemain dalam UV (0..1, kiri-atas = 0,0)
uniform float u_aspect = 1.77778; // lebar / tinggi viewport (koreksi lingkaran jadi elips di UV)
uniform float u_inner_h = 0.25; // radius terang-penuh, dalam satuan tinggi layar
uniform float u_outer_h = 0.65; // radius gelap-penuh, dalam satuan tinggi layar
uniform vec4 u_dark : source_color = vec4(0.02, 0.02, 0.06, 0.95); // warna kegelapan

void fragment() {
	vec2 d = (UV - u_hole_uv) * vec2(u_aspect, 1.0);
	float dist = length(d);
	float t = smoothstep(u_inner_h, u_outer_h, dist);
	COLOR = vec4(u_dark.rgb, u_dark.a * t);
}
