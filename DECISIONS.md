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
- Tracing offline `tools/trace_map.py`: threshold putih 150 (jaga konektivitas),
  komponen putih terbesar = map (kotak legenda kiri-atas otomatis ter-exclude),
  isi hanya lubang kecil (cat mesin/angka); blok merah besar = tembok interior.
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
