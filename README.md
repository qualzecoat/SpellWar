# SpellWar

Game 2D top-down multiplayer ala Among Us. Kumpulkan huruf alfabet dari minigame,
susun menjadi kata untuk mendapatkan senjata/upgrade stat, dan jadilah yang pertama
mengekstrak kata kunci di ruang utama untuk memenangkan match.

Dokumen desain lengkap: lihat `game-design-doc.md` di workspace (bukan di repo ini).

## Versi Godot

**4.7.2-stable** — WAJIB sama persis di semua mesin (PC dev, VPS build, VPS server).
Jangan buka project ini dengan versi lain.

Download:
- Windows: https://godotengine.org/download/windows/ (pilih 4.7.2 stable, 64-bit)
- Linux/macOS: https://godotengine.org/download/

## Cara buka di Godot (PC)

1. Install Godot **4.7.2-stable** (lihat link di atas).
2. Clone repo ini: `git clone https://github.com/qualzecoat/SpellWar.git`
3. Di Godot: **Import** → pilih folder hasil clone → **Import & Edit**.
4. Tekan **F5** (atau tombol Play) untuk menjalankan scene utama.

## Struktur folder

```
scenes/    Scene Godot (.tscn). Entry point: scenes/main.tscn
scripts/   GDScript (.gd)
assets/    Aset visual placeholder (SVG). Aset final menyusul.
server/    (Fase 3) konfigurasi & script dedicated server
```

## Status

Fase 0: project awal — 1 scene, 1 karakter placeholder yang bisa digerakkan
(WASD/panah), kamera mengikuti pemain.
