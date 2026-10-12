# Dokumen Desain Game — v1

> **Status:** Konsep, disusun 2026-10-12 dari diskusi desain. Coding belum dimulai.
> **Judul game:** belum ditentukan.
> Dokumen ini acuan bersama untuk manusia (Qualze) dan AI (Muse). Kalau ada yang berubah, update file ini.

---

## 1. Gambaran Umum

Game 2D top-down multiplayer ala Among Us. Pemain bergerak di map yang gelap,
menyelesaikan minigame untuk mengumpulkan huruf alfabet, menyusun huruf menjadi
kata untuk mendapatkan senjata/upgrade stat, dan berlomba menjadi yang pertama
mengekstrak **kata kunci** di ruang utama untuk memenangkan match.

- **Tujuan match:** BUKAN saling membunuh. Tujuannya mengumpulkan huruf untuk
  kata kunci. Senjata hanya alat untuk **menghambat progres pemain lain**.

## 2. Platform & Arsitektur Teknis

| Aspek | Keputusan |
|---|---|
| Engine | Godot (2D), satu codebase |
| Client | Browser (export HTML5) + Android (export APK) |
| Server | Dedicated server Godot (headless) di VPS Sirius, jalan 24/7 |
| Jaringan | Server authoritative (anti-cheat); client browser & Android main bareng di room yang sama |
| Kolaborasi | Repo GitHub dishare; versi Godot di PC user = versi di VPS (diberitahu saat project mulai) |
| Aset | Placeholder oleh Muse (gambar 2D, SFX retro via kode). Aset final oleh user |

**Batasan aset yang disepakati:** tidak bisa diandalkan untuk sprite sheet animasi
yang konsisten antar-frame, pixel art pixel-perfect/tileset mulus, dan musik latar
(musik pakai sumber royalty-free).

## 3. Pembagian Kerja

- **User (Qualze):** desain game, sketsa map/UI, kirim aset final, playtest di HP.
- **Muse:** semua coding (game logic, server, deploy), aset placeholder, integrasi aset user.

## 4. Gameplay Inti

### 4.1 Movement & Kamera
- Gerakan direplika persis Among Us: 8 arah (WASD/panah di PC, joystick virtual di HP),
  kecepatan konstan, karakter tidak memutar badan (hanya flip kiri-kanan).
- Kamera: Camera2D mengikuti pemain.
- Arah hadap = arah gerak terakhir (dipakai untuk arah serangan).

### 4.2 Map & Vision
- Map gelap persis Among Us: lingkaran pandang terbatas di sekitar karakter, area lain gelap.
- Pemain lain terlihat hanya jika masuk radius pandang. Tidak ada posisi global/minimap.
- Layout: 1 ruang besar di tengah (ruang ekstraksi) + ruangan-ruangan kecil (puzzle)
  dihubungkan koridor. Detail di bagian 13.

## 5. Minigame & Hadiah Huruf

- Setiap ruangan kecil punya 1 spot minigame (puzzle sederhana ala task Among Us:
  sambung kabel, tekan urutan, geser kartu, dll. — varian placeholder dulu).
- Selesai minigame → hadiah **5 huruf alfabet random A-Z**.
- **Cooldown:** tiap spot cooldown **30 detik PER PLAYER** setelah diselesaikan
  (bukan global). Pemain harus pindah ke spot lain. Spot yang cooldown tampil
  redup + timer di layar pemain tersebut.

## 6. Inventory & Sistem Kata

### 6.1 Grid inventory
- Setiap pemain punya inventory grid **8x8**. 1 huruf = 1 cell.
- Huruf bisa di-drag untuk diatur ulang (mouse & sentuh).
- Aturan susun ala TTS (teka-teki silang): kata bisa vertikal maupun horizontal,
  dan **1 huruf boleh dipakai 2 kali** — ikut 1 kata vertikal + 1 kata horizontal
  sekaligus (sharing).

### 6.2 Aturan kata (inti dari game ini)
1. Kata valid yang tersusun → efeknya (senjata/stat) langsung aktif.
2. Huruf **tidak habis terpakai** — tetap di grid.
3. Efek **nempel selama katanya utuh**. Begitu satu huruf digeser hingga kata pecah,
   efeknya hilang seketika:
   - Senjata dicabut dari pemain.
   - Trap yang sudah dipasang ikut hilang dari map.
   - Bonus stat ikut turun.
4. **Senjata tidak stack:** 1 jenis 1 per pemain. Bikin kata PISTOL kedua = tidak ada efek.
5. **Stat BOLEH stack** berkali-kali (2 kata HP = +100 max HP, dst).
6. Kata yang terbentuk di-highlight di grid + muncul di daftar kata aktif.

### 6.3 Daftar kata & efek

**Senjata:**

| Kata | Efek | Biaya EP |
|---|---|---|
| PISTOL (6 huruf) | Menembak proyektil ke arah hadap, damage 50 | 10 / tembakan |
| SWORD (5 huruf) | Tebasan melee ke arah hadap, damage 25 | 8 / ayunan |
| TRAP (4 huruf) | Maks 3 jebakan aktif bersamaan, pasang di posisi kaki | 15 / jebakan |
**Stat:**

| Kata | Efek |
|---|---|
| HP | +50 max HP (+50 heal saat terbentuk; saat pecah, max turun & HP di-clamp) |
| EP | +25 max EP, +2 regen/detik |
| SP | +15% kecepatan jalan per stack (multiplikatif); indikator "SP +x%" di HUD + efek jejak gerak saat aktif |

Catatan desain: PISTOL sengaja 6 huruf agar butuh minimal 2x minigame.

**Aturan trap (revisi 2026-10-12, dari feedback playtest):**
- Tap tombol TRAP → trap LANGSUNG terpasang di posisi kaki pemain
  (TIDAK ada mode pasang/preview lagi).
- Jumlah = MAKSIMAL trap aktif bersamaan (**3**), BUKAN amunisi/sisa.
  Pasang saat sudah 3 aktif → ditolak + toast "Trap maksimal!".
  Trap meledak → slot kembali, bisa pasang lagi. Tombol tampil "TRAP (n/3)".
- Trap terpicu saat diinjak pemain **lain** (pemilik kebal). Efek: **30 damage +
  slow 50% selama 2 detik**. Hilang setelah terpicu sekali.
- **Pemilik SELALU melihat trapnya penuh.** (Aturan "non-pemilik hanya dalam
  radius kecil" berlaku per-viewer dan diimplementasikan saat multiplayer —
  tiap client me-render pandangannya sendiri.)
- Kata TRAP pecah → semua trap terpasang ikut hilang dari map.

### 6.4 Mesin Tukar Huruf
Karena huruf dari minigame random A-Z, huruf yang dibutuhkan bisa sulit didapat.
Solusinya: mesin khusus di map (Fase 1b: 1 mesin di ruang ekstraksi).

- Interaksi via ACTION/E saat dekat mesin → inventory terbuka otomatis +
  panel mesin di sisi kiri (pola standar, lihat 8.5).
- Pilih 1 huruf sumber (drag dari inventory ke slot sumber).
- Pilih huruf target (grid A–Z; huruf yang sama dengan sumber tidak bisa dipilih).
- **Biaya = jarak MELINGKAR alfabet**: d = min(|a−b|, 26−|a−b|), dengan A=0 … Z=25.
  Contoh: A→C = 2, Z→A = 1, Z→X = 2, A→Z = 1, M→Z = 13.
- Bayar biaya dengan huruf apa saja (drag ke slot pembayaran, sejumlah biaya).
- Tombol TUKAR aktif hanya jika: slot sumber terisi + target dipilih +
  semua slot pembayaran terisi.
- Saat TUKAR ditekan: huruf sumber **BERUBAH** menjadi huruf target
  (tetap di cell-nya, tidak hangus); huruf pembayaran **hangus**.
- Batal/tutup panel: semua huruf di slot kembali ke inventory (reserved).
- Deteksi kata + highlight + efek berjalan **live** setiap ada perubahan grid,
  di semua konteks panel (inventory biasa, panel mesin, panel ekstraksi nanti).

Contoh: punya A butuh C → drag A ke slot sumber, pilih target C (biaya 2) →
drag 2 huruf apa saja ke pembayaran → TUKAR → A berubah jadi C, 2 huruf bayar hangus.

## 7. Angka-Angka Dasar

| Parameter | Nilai (sementara) |
|---|---|
| HP default | 100 |
| EP max default | 100, regen 5/detik |
| Kecepatan jalan dasar | 220 px/detik |
| Damage pedang | 25 |
| Damage pistol | 50 |
| Respawn | 30 detik di titik spawn |

## 8. HUD & UI

### 8.1 Layout HUD (sesuai sketsa user)
- Kiri atas: bar HP, bar EP.
- Kanan atas: tombol INVENTORY.
- Kiri bawah: analog joystick.
- Kanan: tombol senjata (SWORD/TRAP/PISTOL, muncul hanya jika katanya terbentuk)
  + ACTION BUTTON.

### 8.2 Inventory drawer
- Panel geser dari kanan (animasi), tombol BACK untuk menutup.
- Panel kiri: daftar kata aktif + **daftar semua kata beserta efeknya** (scroll;
  kata yang bisa dibentuk dari huruf saat ini di-highlight kuning,
  kata aktif hijau) — ini pengganti tutorial.
- Saat inventory terbuka: karakter **tetap bisa digerakkan, tapi tidak bisa action**
  (tombol senjata & interact disembunyikan; joystick tetap jalan).
- **Kamera bergeser** sehingga karakter berada di tengah area layar yang TIDAK
  tertutup drawer (offset kamera = setengah lebar drawer), bukan tengah layar penuh.
- Semua efek kata berlaku live.

### 8.3 Senjata (tanpa sistem equip terpisah)
Tiap tombol senjata = tombol pakai langsung:
- **SWORD:** tap → tebas ke arah hadap.
- **PISTOL:** tap → tembak ke arah hadap.
- **TRAP:** tap → langsung terpasang di posisi kaki. Tampil "TRAP (n/3)"
  = jumlah aktif / maksimal.
- EP kurang → tombol goyang + bar EP kedip.

### 8.4 ACTION BUTTON
- Kontekstual: berinteraksi dengan objek interaktif di dekat pemain
  (tombol menyala saat ada objek dalam jangkauan, redup saat tidak ada).
- Jika tidak ada objek: **mendorong pemain lain** — target terdekat dalam
  110 px ke arah hadap terdorong (knockback). Selalu tampil (mode dorong).

### 8.5 Pola Standar UI Mesin (berlaku untuk semua mesin)
Interaksi dengan mesin (tukar huruf, ekstraksi, dan sejenisnya) selalu:
1. Membuka inventory secara otomatis.
2. Menampilkan panel mesin di **sisi kiri** layar (inventory drawer di kanan).
3. Semua transfer huruf via **drag-and-drop** dari/ke inventory.
4. Huruf di slot mesin bersifat *reserved*: batal/tutup → kembali ke inventory.

## 9. Multiplayer & Tujuan Match

- Setiap match, server me-random **kata kunci: 2 kata** (sama untuk semua pemain → balapan).
- Bank kata: bahasa Inggris (konsisten dengan PISTOL/SWORD/TRAP), ~40 kata,
  total panjang target ~10–14 huruf. Contoh: DARK MATTER, CODE BREAKER,
  NIGHT GUARD, POWER CORE.
- Kata kunci **terlihat semua pemain sejak match mulai** (HUD + panel inventory).
- Huruf dari minigame bersifat dual-purpose: bisa dipakai untuk kata
  senjata/stat, atau disimpan untuk kata kunci.

## 10. Ekstraksi & Kemenangan

1. Pemain yang hurufnya sudah cukup (hitung jumlah, **tidak perlu disusun** di grid)
   pergi ke ruang utama.
2. Action di objek ekstraksi (mesin) → UI ekstraksi terbuka di samping drawer inventory.
3. Drag huruf yang dibutuhkan dari inventory ke slot kata kunci.
   Slot hanya menerima huruf yang benar (salah → kembali ke inventory).
4. Semua slot penuh → **menang, match selesai**.
5. Selama ekstraksi: pemain bisa gerak tapi tidak bisa action; mesin menyala +
   bersuara ke sekitar (pemain lain tahu dan bisa datang mengganggu).
6. Huruf di slot bersifat "dipinjam": UI ditutup/batal → huruf kembali ke inventory.

## 11. Kematian & Respawn

- HP habis → mati → respawn **30 detik** di titik spawn.
- **Semua huruf di inventory jatuh** di lokasi kematian, bisa dipungut pemain lain.
- (Kondisi menang/kalah selain ekstraksi: belum didefinisikan.)

## 12. Map — Konsep v1

File: `map-konsep-v1.png` (satu folder dengan dokumen ini).

- Simetris untuk 4 pemain: 4 titik spawn di ujung map (atas/bawah/kiri/kanan).
- Tiap spawn bersebelahan dengan 1 ruang puzzle (A–D) → rute farming awal tanpa rebutan.
- Ruang ekstraksi besar di tengah, mesin di pusat, 4 pintu koridor.
- Koridor = titik rawan (ambush, pasang trap).
- Opsional: 2 ruang puzzle kontes (E & F, garis putus-putus) untuk memancing
  pertemuan antar pemain di mid-game.
- Alur main: spawn → puzzle sebelah → koridor → tengah.

## 13. Hal yang Belum Diputuskan (Parked)

- Kondisi menang/kalah selain ekstraksi kata kunci.
- Variasi minigame final per ruangan.
- Bank kata kunci final (~40 kata).
- Judul game.
- Jumlah pemain final (asumsi sementara: 4).
- Balancing angka-angka (semua masih placeholder, tuning via playtest).

## 14. Alat Testing (Fase 2, non-fitur)

Khusus fase testing solo, **akan dimatikan/dihapus sebelum rilis**:

- **Boneka latihan (training dummy):** di sudut ruang ekstraksi (diam) + 1 patroli
  mondar-mandir di koridor (untuk ngetes trap). Punya HP bar, bisa ditembak/ditebas
  (angka damage muncul), mati → hidup lagi setelah 5 detik.
- **Panel debug** (tombol "DBG" di HUD): lukai diri 50 (tes mati/drop/respawn),
  beri huruf pilihan A–Z (tes kata cepat), spawn dummy di depan pemain.

## 15. Langkah Berikutnya

1. User: kirim koreksi/gambar tambahan jika ada (map sudah OK sementara).
2. Muse: setup project Godot + repo GitHub, bangun prototipe playable pertama
   (movement + 1 ruangan + 1 minigame + inventory dasar).
3. User: playtest di HP, feedback feel movement & UI.
