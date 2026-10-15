# DECISIONS.md — Log Keputusan SpellWar

> Log keputusan desain & teknis bertanggal.
> **WAJIB diupdate setiap ada keputusan baru** (tambahkan di bagian paling bawah).
> Keputusan user bersifat final; yang tercatat di sini tidak diungkit ulang kecuali
> user meminta.

## 2026-10-12 — Fondasi proyek

- Project: game 2D top-down ala Among Us, Godot; server di VPS Sirius; client browser
  HTML5 + APK Android dari satu codebase; share via repo GitHub; versi Godot disamakan
  (4.7.2-stable). Pembagian kerja: user = desain + aset; Muse = coding + aset placeholder.
- Movement persis Among Us; map = 1 ruangan besar pusat + ruangan kecil + koridor.
- Pool huruf hadiah: P,H,E,S,I,T,O,L,W,D,T,R,A. Inventory grid 8x8 per pemain, drag atur.
- Kata & efek: PISTOL (proyektil), SWORD (melee), TRAP (3 jebakan), HP (+health),
  EP (+regen), SP (+speed). Grid ala TTS: 1 huruf boleh ikut 1 kata vertikal + 1 horizontal.
- Angka: HP 100 (kata HP → +50 max & heal 50; pecah → max turun, HP di-clamp);
  EP max 100 regen 5/dtk (tembak 10 / pedang 8 / trap 15; kata EP → +25 max & +2 regen/dtk);
  SP 220 px/dtk (kata SP → +15%); sword dmg 25, pistol dmg 50.
- Senjata TIDAK stack (1 jenis 1 per pemain); stat BOLEH stack.
- Tanpa sistem equip terpisah — tombol senjata = pakai langsung. Arah hadap = arah gerak
  terakhir. Tombol senjata muncul hanya jika kata terbentuk.
- UI/HUD: bar HP/EP kiri atas, INVENTORY kanan atas, analog kiri bawah, tombol senjata +
  ACTION BUTTON kanan. Inventory = drawer dari kanan (animasi); terbuka → tetap bisa gerak,
  tidak bisa action, kamera geser kiri; efek kata live.
- ACTION BUTTON = interaksi objek di map; jika tidak ada → dorong pemain lain.
- TRAP: mode pasang, preview mengikuti karakter, tap lagi untuk pasang (15 EP),
  sisa jatah tampil di tombol.
- Multiplayer CONFIRMED. Tujuan BUKAN saling bunuh: race kumpulkan huruf untuk kata kunci
  random 2 kata (~10-14 huruf, sama untuk semua pemain). Senjata = menghambat progres lawan.
  Map gelap ala Among Us (vision terbatas; pemain lain terlihat hanya dalam radius pandang).
- Kata kunci: user serahkan ke Muse — bank kata Inggris, random 2 kata/match
  (contoh: DARK MATTER, CODE BREAKER, NIGHT GUARD, POWER CORE).
- Mati → semua huruf jatuh di lokasi, bisa dipungut pemain lain.
- Ekstraksi: ruang utama → action di mesin → UI ekstraksi di samping inventory → drag huruf
  ke slot kata kunci (slot hanya terima huruf benar; salah = balik); penuh = menang.
  Keyword terlihat semua pemain sejak match mulai. Saat ekstraksi: bisa gerak, tidak bisa
  action, mesin beri sinyal visual/suara ke sekitar. Huruf di slot = reserved;
  batal/tutup UI = kembali ke inventory.
- Map konsep v1 (simetris 4 pemain: 4 spawn N/S/E/W + ruang puzzle A-D + ekstraksi besar
  di tengah + koridor; E/F opsional garis putus-putus) — CONFIRMED, digambar Muse.
- Minigame cooldown 30 dtk PER PLAYER (bukan global) → paksa pindah spot.
- Daftar kata senjata+stat+efek tampil DI DALAM panel inventory (scroll, di bawah daftar
  kata aktif); kata yang bisa dibentuk dari huruf saat ini di-highlight. Tutorial: parkir.
- Mesin tukar huruf: biaya = jarak alfabet MELINGKAR `d=min(|a-b|,26-|a-b|)`
  (A→C=2, Z→A=1, Z→X=2); huruf sumber BERUBAH jadi target (tidak hangus); huruf bayar
  hangus; huruf sama tidak bisa.
- Pola UI standar semua mesin: interaksi → inventory terbuka otomatis + panel mesin di kiri,
  semua transfer huruf via drag-and-drop; batal = huruf kembali.

## 2026-10-13 — Perubahan desain pra-Fase 3 & Fase 3

- Huruf hadiah puzzle buyar di tanah & dipungut (radius 90–150px sekitar konsol);
  bisa dicuri pemain lain (disengaja).
- Respawn 30 dtk → 5 dtk (hukuman mati = kehilangan huruf, bukan countdown).
- Spawn protection 3 dtk: fixed spawn + karakter berkedip, kebal damage, proteksi hilang
  saat menyerang (anti spawn-camping). Random spawn DIPARKIR sebagai opsi cadangan.
- Fase 3: alur nickname → menu [Main Sendiri / Buat Room / Join Room]; kode room
  6 karakter; pembuat room pencet MULAI manual; 2–8 pemain/room (8 titik spawn).
- Reconnect 90 dtk: disconnect → karakter diam + kebal; join nama sama → lanjut state utuh;
  lewat 90 dtk → huruf jatuh, karakter dihapus. Tidak memberatkan server.
- Panel debug MATI otomatis saat multiplayer; mode Main Sendiri = solo debug (Fase 2).
- Protokol: WebSocket wss (bukan ENet).
- Keyboard HP: custom in-game (bug engine Godot #99602 — keyboard OS/Gboard tidak bisa
  dipakai di web export). Layout ala PS4: angka di atas, huruf kecil qwerty, shift toggle,
  spasi lebar, simbol; kode room uppercase+digit valid. Menu geser ke atas saat keyboard
  terbuka (bukan resize layar — tidak bisa secara teknis).
- Vision: overlay full-screen berbasis shader, lubang lingkaran lembut ~420px mengikuti
  pemain; HUD di atasnya. Gotcha: parser .tscn Godot 4.7 me-skip properti tepat setelah
  baris komentar `#`.

## 2026-10-14 — Audit solo→MP, kunci Fase 3, buka Fase 3b

- Audit menyeluruh: semua fitur solo harus ada di mode multiplayer ("mode survival"),
  kecuali yang disengaja tidak dimasukkan (panel debug, training dummy).
- Temuan & fix: (1) respawn TIDAK PERNAH jalan di MP (server tidak memanggil respawn_at
  → mati selamanya) → diperbaiki + spawn protection via respawn_at; (2) cooldown puzzle
  30 dtk/player ternyata belum ada di SOLO maupun MP → ditambahkan di keduanya
  (server enforce + solo); (3) visual ayunan pedang tidak ada di MP → event server;
  (4) tukar huruf: server reject grid saat huruf di slot → client clear slot tiap
  grid_sync; fix "reserved" slot-aware grid sync; (5) mati tidak menutup panel mesin
  di MP → diperbaiki.
- Pelajaran operasional: dedicated server HARUS di-rebuild + container di-restart setiap
  ada perubahan script server (deploy web saja tidak cukup — server jalan kode kadaluarsa
  13 jam tanpa error jelas).
- Fase 3 DIKUNCI (test 2 device asli oleh user lolos, "aman"). Bug kecil ditunda —
  user mau map baru (Fase 3b) dulu untuk mengetesnya.
- Fase 3b DIBUKA: map baru sesuai desain user (file 200 MB → kirim versi kompres:
  overview + crop per area + label teks; atau via Google Drive folder `SpellWar`).
- PROJECT.md + DECISIONS.md dibuat di repo; WAJIB selalu diupdate (instruksi user).

## 2026-10-14 — Refactor fondasi: ClientGameBase (sebelum Fase 3b)

- Latar: bug-bug MP (respawn tak jalan, wiring tukar huruf hilang, tombol E mati,
  gerak mati saat inventory terbuka) semuanya berasal dari `game.gd` & `mp_game.gd`
  sebagai dua orkestrator paralel yang harus di-porting manual. User (non-coder)
  dengan tepat menduga akar masalahnya: fitur tidak dikukuhkan di satu tempat.
- Solusi: `scripts/client_game_base.gd` (`class_name ClientGameBase`, extends Node2D) —
  seluruh alur client yang identik pindah ke sini: `_unhandled_input` (E/Esc),
  open/close inventory + geser kamera, open/close minigame + cooldown,
  open/close exchange, `_refresh_interact`, seleksi kata stabil. Subclass hanya berisi
  yang spesifik mode via hook: `_set_local_input`, `_on_minigame_success`,
  `_sync_after_exchange`, `_do_interact`, `_do_weapon`, `_refresh_weapons`,
  `_on_exchange_confirmed`.
- `game.gd` kini hanya: simulasi lokal, efek kata, combat lokal, dummy, panel debug.
- `mp_game.gd` kini hanya: netcode, snapshot, visual remote/pickup/trap/proyektil,
  darkness, proximity.
- Sentralisasi aturan ke `net_proto.gd` (satu rumah, nilai TIDAK diubah): BASE_*,
  efek kata (HP/EP/SP), biaya EP senjata, damage, MELEE_RANGE, PUSH_*,
  TRAP_* (max/arm/slow), SCATTER_* (reward/death). `player.gd`, `server_player.gd`,
  `projectile.gd`, `trap.gd`, `mp_server.gd`, `game.gd` kini merujuk ke sana.
- Spawn & posisi mesin: SUDAH tersentralisasi sebelum refactor (`map.gd` untuk solo,
  `NetProto.SPAWN_SLOTS` untuk MP) — tidak diubah.
- Batasan: perilaku harus identik (Fase 2 & 3 dikunci) — refactor murni, tanpa fitur baru.
## 2026-10-15 — Fase 3b1: geometri map baru (desain user)

- Sumber: `petunjuk-area-map.png` (legenda warna) — merah = tembok absolut,
  putih = walkable. Aset hand-drawn hanya sketsa; redraw di Godot (optimize).
- Tracing offline `tools/trace_map.py`: klasifikasi dibalik — TEMBOK = piksel
  merah-dominan SAJA `(r>150)&(g<120)&(b<120)` (sample tembok aktual median
  (229,79,66); pink spawn & kuning ekstraksi 0px terdeteksi tembok); selain itu =
  walkable. Overlay desain (kotak hijau/biru/kuning/pink/cyan mesin/spawn/zona
  interaksi) menjadi LANTAI BERSIH di 3b1 (mesin dapat collision sendiri di
  3b3/3b4). Kotak legenda kiri-atas tetap ter-exclude (komponen terpisah).
  Fix 2026-10-15: sebelumnya walkable = putih-ish sehingga overlay berwarna
  ke-trace sebagai blob tembok di atas lantai.
- Skala: 1 kotak grid desain (~50px) = 64px game; sel trace 10px desain (12.8px game).
  Ukuran map: 4454.4 x 3699.2 px (69.6 x 57.8 grid).
- Verifikasi: flood fill 100% reachable; badan player (disk r=22px) 100% reachable;
  tidak ada ruangan terisolasi.
- Collision: greedy rectangle merge → 254 rect dinding (StaticBody2D),
  visual 268 rect lantai (flat, gaya placeholder).
- Containment (keputusan user): `MapData.is_walkable/clamp_to_walkable/
  random_walkable_near` — scatter huruf (reward puzzle & death drop, solo & server)
  tidak pernah mendarat di dalam tembok. Knockback/dorong aman via fisika
  (move_and_slide + collision dinding, client & server).
- 3b1 = geometri SAJA: tanpa mesin/spawn/interaksi. Konstanta mesin jadi sentinel
  di luar map (validasi jarak selalu gagal aman). Spawn sementara 1 titik
  (MP: 8 offset kecil) — spawn resmi + random di 3b2.
- Server di-rebuild + restart (script server/shared berubah: map.gd, map_data.gd,
  mp_server.gd, net_proto.gd).

## 2026-10-15 — Map 3b1 jadi scene editable (user edit sendiri)

- User tidak puas dengan hasil trace map 3b1 → mau turun tangan edit di Godot PC.
- Keputusan: map diubah dari data hasil-generate menjadi `scenes/map_3b.tscn`
  sebagai SINGLE SOURCE OF TRUTH yang editable: `Walls` = StaticBody2D berisi
  CollisionShape2D per wall rect (`Wall_001`.., nama stabil), `Floor` = Node2D
  berisi Polygon2D per floor rect, `Background` seukuran map. Script
  `scripts/map_3b.gd` (`class_name Map3B`) hanya berisi konstanta sementara 3b1.
- Walkability: pendekatan (a) exporter — `tools/export_map_data.py` membaca wall
  rect dari .tscn → rasterisasi grid → regenerasi `scripts/map_data_gen.gd`
  (`WALL_RECTS`, `WALK_MASK_B64`). Alasan: deterministik, testable headless,
  dipakai server tanpa butuh physics space. Round-trip terverifikasi identik
  (mask 0 sel beda vs trace lama).
- `main.tscn`, `mp_main.tscn`, `server_main.tscn` instance `map_3b.tscn` sebagai
  node `Map` (server BUTUH collision fisik: `server_player.gd` pakai
  `move_and_slide`). `scripts/map.gd` dihapus; `assets/map_walk.png` (rusak)
  dihapus; `tools/trace_map.py` disimpan sebagai riwayat.
- Aturan: edit scene → `python3 tools/export_map_data.py` → commit/push →
  deploy web + rebuild server. `map_data_gen.gd` JANGAN diedit manual.

## 2026-10-16 — Deploy map 3b1 versi edit user (live)

- User ambil alih map: edit `scenes/map_3b.tscn` sendiri di Godot PC — Background
  diganti texture gambar hand-drawn (`assets/PNG/Aset Map Utama Compresed.png`,
  64MB, 16200x14280); tembok di-rebuild 281 -> 141 rect besar selaras gambar;
  floor hampir semua dihapus (lantai = gambar itu sendiri).
- Keputusan user (konfirmasi 2026-10-16): (1) gambar hand-drawn = VISUAL FINAL
  map (bukan sekadar sketsa); (2) pilar-pilar kecil di ruangan = posisi mesin
  (untuk 3b3/3b4) — untuk sekarang wall biasa; (3) oke deploy.
- Temuan saat verifikasi & perbaikan:
  - PNG belum di-commit user -> .tscn referensi file hilang -> game gagal load.
    Pelajaran: bila scene referensi aset baru, pastikan aset ikut ke-commit.
  - TEMP_SPAWN lama (2003.2,1747.2) ketiban Wall_022 -> pindah ke (4150,3900)
    ruang tengah (+ 8 slot MP r=96 & titik dummy, semua dicek walkable).
  - Exporter diperkuat: parse format .tscn baru (atribut `unique_id`, id
    sub_resource gaya baru); clip grid walkability ke bounds texture Background
    (void di luar map = tidak walkable); flood-fill dari SPAWN_POS — kantong
    terisolasi (margin kertas kosong di tepi texture, ~4rb sel) otomatis jadi
    tembok di mask. Flood fill 100% by construction; scatter tak akan mendarat
    di kantong mati.
  - Map user ~8460x7488 px (2x lipat versi trace); .pck web ~64MB (texture).
- Test: map 11/11, inventory 9/9, exchange 17/17, fase2 54/54, fase3 94/94;
  boot solo+MP+server 200 frame bersih; --import exit 0; --check-only bersih.
- Deploy: web + rebuild server (`map_data_gen.gd` dipakai server). Live OK
  (200 + COOP/COEP + no-store; Caddy tidak diubah).

## 2026-10-16 — Fix pilar mesin: zona interaksi harus walkable (3b1)

- Laporan user: area kotak abu-abu dengan 2 panah (zona interaksi mesin) ke-block,
  harusnya bisa dilewati player.
- Diagnosis: 12 dari 16 pilar mesin yang user gambar di `scenes/map_3b.tscn`
  ketinggian (~120x131) sampai menutupi kotak zona interaksi di bawah icon mesin.
- Fix (di working copy, diverifikasi visual + walkability): 12 pilar dikecilkan
  jadi ~125x116 dan diposisikan ulang agar MENUTUPI icon mesin tapi TIDAK
  menutupi kotak abu-abu zona interaksi. Verifikasi: 14/14 zona interaksi di
  sekitar pilar walkable di mask baru; icon mesin tetap tertutup pilar.
- Aturan desain (konfirmasi user): zona interaksi mesin = area yang BISA
  dilewati player (bukan tembok). Berlaku untuk 3b3/3b4 saat mesin ditempatkan.
- Deploy: exporter -> 141 wall rect, flood fill 100%; test map 11/11, inventory
  9/9, exchange 17/17, fase2 54/54, fase3 94/94; boot solo+MP+server bersih;
  web + rebuild server; live OK (200 + COOP/COEP + no-store; Caddy tidak diubah).

## 2026-10-16 — Spec area interaksi dikunci + tembok mesin ekstraksi (3b1)

- Spec dari user (gambar anotasi): (a) mesin minigame = 1 area interaksi
  walkable (kotak abu-abu 2 panah); (b) mesin ekstraksi (mahkota, tengah map)
  = badan mesin TEMBOK + 4 area interaksi walkable (atas/bawah/kiri/kanan).
  Berlaku untuk 3b3/3b4.
- Implementasi: Wall_161 baru 240x240 di tengah mahkota (4262, 3774)
  (shape `RectangleShape2D_extract`); pilar mesin asli di (5507, 4572) tetap
  sebagai wall. Total 142 wall rect.
- Temuan: 2 slot spawn MP sementara + titik spawn lama ketiban wall mesin
  ekstraksi baru -> TEMP_SPAWN digeser ke (3900, 4100) (+ 8 slot MP r=96 &
  titik dummy/patrol, semua dicek walkable). Spawn resmi + random = 3b2.
- Pelajaran: exporter (`tools/export_map_data.py`) HANYA membaca node
  CollisionShape2D dengan `parent="Walls"` — node ber-parent lain (mis.
  `parent="."`) diabaikan diam-diam. Pastikan parent benar sebelum export.
- Test: map 13/13 (termasuk regression: badan ekstraksi = tembok, 4 zona
  walkable), inventory 9/9, exchange 17/17, fase2 54/54, fase3 94/94;
  boot solo+MP+server 200 frame bersih; --import exit 0; --check-only bersih.
- Deploy: web + rebuild server (`map_3b.gd`/`map_data_gen.gd` dipakai server).
  Live OK (200 + COOP/COEP + no-store; Caddy tidak diubah).
