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
