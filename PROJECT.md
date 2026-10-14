# PROJECT.md — SpellWar

> **File konteks proyek. WAJIB dibaca penuh sebelum mengerjakan apapun di repo ini.**
> **WAJIB diupdate setiap ada keputusan desain, perubahan arsitektur, atau pelajaran operasional baru.**
> Lihat juga: `DECISIONS.md` (log keputusan bertanggal), `README.md` (cara buka & build),
> `game-design-doc.md` + `phases-goals.md` (dokumen user-facing, di luar repo).

## 1. Apa itu SpellWar

Game 2D top-down multiplayer ala Among Us (Godot). Pemain mengumpulkan huruf dari
minigame ala "task Among Us", menyusun kata untuk mendapatkan senjata/upgrade stat,
dan (Fase 4+) berlomba mengekstrak kata kunci untuk memenangkan match. Senjata dipakai
untuk menghambat progres lawan, bukan untuk saling bunuh sebagai tujuan utama.

- **Repo:** https://github.com/qualzecoat/SpellWar
- **Live (web):** https://spellwar.aditiamh.my.id
- **Server:** dedicated Godot di Docker `spellwar-server` (VPS Sirius,
  `/opt/sirius/compose/spellwar/`), port internal 8765, diakses via
  `wss://spellwar.aditiamh.my.id/ws` (Caddy reverse proxy, `handle /ws*`).
- **Godot 4.7.2-stable — WAJIB sama persis di semua mesin** (PC dev user, VPS build,
  VPS server). Jangan buka project dengan versi lain.

## 2. Arsitektur

- **Client:** export Web (HTML5) dari satu codebase; rencana APK Android dari codebase
  yang sama (Fase 5).
- **Server:** authoritative penuh — posisi, damage, huruf, kata, cooldown diputuskan
  server. Client tidak dipercaya.
- **Protokol:** WebSocket (`wss`), bukan ENet.
- Scene: `scenes/main.tscn` (solo), `scenes/mp_main.tscn` (multiplayer),
  `scenes/menu.tscn`, `scenes/server_main.tscn` (dedicated server).
- Script penting: `scripts/client_game_base.gd` (**lapisan alur game bersama** —
  `game.gd` & `mp_game.gd` mewarisinya; seluruh flow client yang identik tinggal di sini),
  `scripts/game.gd` (solo: simulasi lokal + dummy + debug),
  `scripts/mp_game.gd` (client MP: netcode + visual),
  `scripts/mp_server.gd` + `scripts/server_player.gd` (server),
  `scripts/net_proto.gd` (konstanta, pesan, **dan aturan gameplay satu rumah**),
  `scripts/inventory_ui.gd`, `scripts/exchange*.gd`, `scripts/words.gd`,
  `scripts/darkness_overlay.gd` + `shaders/darkness.gdshader` (vision),
  `scripts/touch_keyboard.gd` (keyboard HP).
- **Map (Fase 3b1+)**: `scenes/map_3b.tscn` = SINGLE SOURCE OF TRUTH (editable di
  editor Godot: node `Wall_001`.. di bawah `Walls`, `Floor_001`.. di bawah `Floor`).
  Script: `scripts/map_3b.gd` (`class_name Map3B`, hanya konstanta sementara 3b1).
  Data turunan walkability: `scripts/map_data_gen.gd` — DITURUNKAN via
  `tools/export_map_data.py` dari .tscn (JANGAN edit manual). Logika walkability:
  `scripts/map_data.gd` (`is_walkable`, `clamp_to_walkable`, `random_walkable_near` —
  dipakai scatter agar huruf tidak buyar di dalam tembok). Solo, client MP, dan server
  memakai scene & data yang sama.

## 3. Status fase

| Fase | Status |
|---|---|
| 0 — Setup & fondasi | ✅ Dikunci 2026-10-12 |
| 1 — Prototipe solo | ✅ Dikunci 2026-10-12 |
| 1b — Mesin tukar huruf | ✅ Dikunci 2026-10-12 |
| 2 — Combat & sistem kata | ✅ Dikunci 2026-10-13 |
| 3 — Multiplayer | ✅ Dikunci 2026-10-14 (test 2 device asli lolos) |
| 3b — Map baru (desain user) | 🟡 Dibuka 2026-10-14 |
| 4 — Match loop lengkap (kata kunci, ekstraksi, menang) | ⬜ Rencana |
| 5 — Rilis ke tester (APK) | ⬜ Rencana |

## 4. Sistem inti (ringkas)

- **Gerak:** 8 arah ala Among Us, WASD + joystick analog; kecepatan dasar 220 px/dtk.
- **Inventory:** grid 8x8 drag-drop (mouse + sentuh); drawer geser dari kanan; karakter
  tetap bisa gerak saat terbuka (tidak bisa action); kamera geser kiri.
- **Kata:** deteksi ala TTS (1 huruf boleh ikut 1 kata vertikal + 1 horizontal).
  Kata: PISTOL, SWORD, TRAP, HP, EP, SP. Senjata tidak stack; stat boleh stack.
- **EP:** max 100, regen 5/dtk; biaya tembak 10 / pedang 8 / trap 15.
- **Senjata:** SWORD melee (dmg 25), PISTOL proyektil (dmg 50),
  TRAP (3 jebakan, 30 dmg + slow 2 dtk, arm 3 dtk).
- **Minigame:** sambung kabel → hadiah 5 huruf buyar di tanah (radius 90–150px),
  bisa dipungut & dicuri pemain lain; cooldown 30 dtk per pemain.
- **Tukar huruf:** biaya = jarak alfabet melingkar `d=min(|a-b|,26-|a-b|)`; huruf sumber
  BERUBAH jadi target (tidak hangus); huruf bayar hangus.
- **Mati:** semua huruf jatuh di lokasi; respawn 5 dtk di titik spawn; proteksi spawn
  3 dtk (kedip, kebal, hilang saat menyerang).
- **Multiplayer:** 2–8 pemain/room, kode room 6 karakter, mulai manual oleh pembuat room,
  reconnect 90 dtk, vision gelap 420px (lubang lingkaran lembut ikut pemain),
  nickname unik per room.
- **Sengaja TIDAK ada di MP:** panel debug, training dummy (anti-cheat).

## 5. Gotcha operasional (baca sebelum build/deploy!)

1. **Parser .tscn Godot 4.7 me-skip properti tepat setelah baris komentar `#`.**
   Jangan taruh `#` tepat di atas assignment properti di file `.tscn`.
2. **Server HARUS di-rebuild setiap ada perubahan script server/shared:** export preset
   `LinuxServer` → `.pck` baru → `docker compose build && up -d` di
   `/opt/sirius/compose/spellwar/`. Deploy web SAJA tidak cukup — server akan jalan
   dengan kode kadaluarsa tanpa error yang jelas.
3. **Caddy jangan diubah/direstore** tanpa backup + `caddy validate` + restart service
   (file di-bind-mount; `sed -i` mengganti inode → butuh restart).
4. **Keyboard HP adalah keyboard custom di dalam game** (`scripts/touch_keyboard.gd`) —
   keyboard OS tidak bisa dipakai di web export Godot (bug engine #99602). Anchors
   TouchKeyboard harus di-set SEBELUM `add_child` (di `_ready()` tidak memberi ukuran).
5. Build: Godot headless `/opt/sirius/godot/4.7.2/`; build dir `/tmp/spellwar-fase1`
   (reuse; rsync dengan `--exclude=.godot` agar class cache tidak terhapus).
6. **Alur edit map (Fase 3b+)**: user edit `scenes/map_3b.tscn` di Godot PC →
   jalankan `python3 tools/export_map_data.py` dari root repo (regenerasi
   `scripts/map_data_gen.gd` dari wall rect scene) → commit + push → deploy web +
   **rebuild server** (data dipakai server). JANGAN edit `map_data_gen.gd` manual.
   JANGAN taruh baris komentar `#` tepat di atas assignment properti di file `.tscn`
   (lihat gotcha no. 1).
6. Push ke GitHub via `push_files` (incremental, ~130KB/call).
7. SSH VPS: `~/workspace/vps-ssh.sh` (via Tailscale).

## 6. Aturan workflow

- Tiap fase dikunci user (persetujuan eksplisit) sebelum lanjut ke fase berikut.
- Desain ambigu → **jawab dulu, jangan langsung implementasi**.
- Bug dilaporkan user (bernomor + screenshot) → perbaiki + regression test
  (`tests/test_inventory.gd`, `tests/test_exchange.gd`, `tests/test_fase2.gd`,
  `tests/test_fase3.gd` — semua harus lolos).
- **PROJECT.md dan DECISIONS.md WAJIB diupdate** setiap ada keputusan/perubahan
  (instruksi user 2026-10-14).
- Dokumen user-facing: markdown saja (`.md`), di
  `~/workspace/your_files/game-2d-among-us/` (tampil di Library).
- File besar (desain map, aset): Google Drive folder `SpellWar` (sudah terkoneksi).
- Instruksi untuk user: Windows-cmd-ready atau via browser.
