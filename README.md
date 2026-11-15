# CMMschedule — Vercel + Supabase

Sistem penjadwalan kelas dan ruangan untuk program CMM (KMUTT).
Frontend statis (HTML/CSS/JS) di Vercel, database + login + update live di Supabase,
dan satu fungsi server Vercel untuk mengirim email ke dosen.

```
index.html, style.css, app.js   → tampilan + logika penjadwalan (jalan di browser)
api/config.js                   → memberi URL Supabase + public key ke browser
api/send-email.js               → kirim email jadwal ke dosen (khusus Admin)
supabase/schema.sql             → tabel, aturan akses, fungsi save_doc, realtime
supabase/accounts.sql           → menetapkan peran Admin / petugas ruangan
```

## Langkah deploy (± 15 menit)

### 1. Supabase (database + login)
1. Buka https://supabase.com → **New project** (pilih region Singapore). Simpan password database.
2. Menu **SQL Editor** → **New query** → tempel isi `supabase/schema.sql` → **Run**.
3. Menu **Authentication → Users → Add user → Create new user**, buat 2 akun dan centang **Auto Confirm User**:
   - `admin@cmmschedule.demo` (พี่ชมพู่ · เจ้าหน้าที่จัดตารางสอน)
   - `mek@cmmschedule.demo` (พี่เมก · เจ้าหน้าที่ดูแลห้องเรียน)
   Boleh pakai email lain, asal email di `accounts.sql` diganti juga.
4. **SQL Editor** → tempel isi `supabase/accounts.sql` → **Run**. Hasilnya harus menampilkan 2 baris dengan role `admin` dan `room_officer`.
5. **Project Settings → API**: salin **Project URL** dan **anon public key**.

### 2. GitHub
1. Buat repository baru, misalnya `cmmschedule`.
2. Upload semua file di folder ini (termasuk folder `api` dan `supabase`), lalu commit.

### 3. Vercel (hosting)
1. Buka https://vercel.com → **Add New → Project** → pilih repo `cmmschedule` → **Import**.
2. Framework Preset: **Other**. Build Command dan Output Directory dikosongkan.
3. **Environment Variables**, isi:
   - `SUPABASE_URL` = Project URL dari langkah 1.5
   - `SUPABASE_ANON_KEY` = anon public key dari langkah 1.5
4. **Deploy**. Setelah selesai, buka alamat `https://cmmschedule-xxxx.vercel.app`.

### 4. Pertama kali dipakai
1. Login sebagai Admin → muncul layar "ระบบยังไม่มีข้อมูล" → klik **ตั้งค่าข้อมูลสาธิต** untuk mengisi data contoh (15 mata kuliah semester 2 kurikulum CMM 2564, 7 ruangan, 6 dosen).
2. Buka di komputer lain dan login sebagai พี่เมก: perubahan dari Admin muncul otomatis.

### 5. (Opsional) Email sungguhan ke dosen
1. Daftar di https://resend.com → **API Keys → Create**.
2. Di Vercel tambahkan:
   - `RESEND_API_KEY` = key dari Resend
   - `MAIL_FROM` = `CMMschedule <onboarding@resend.dev>`
3. **Redeploy**. Tombol "ส่งอีเมล" di halaman เผยแพร่ akan mengirim email sungguhan + PDF jadwal tiap dosen.

Catatan: tanpa domain sendiri, Resend hanya bisa mengirim ke email pemilik akun Resend.
Untuk demo, isi email dosen dengan email kalian sendiri di menu เงื่อนไขการสอน → อาจารย์.
Untuk mengirim ke email siapa pun, verifikasi domain di Resend lalu ganti `MAIL_FROM`.
Tanpa langkah 5, pengiriman email tetap berjalan dalam mode simulasi.

## Cara kerjanya
- **Login**: Supabase Auth (email + password). Peran diambil dari tabel `profiles`.
- **Data**: tabel `docs`, satu baris per dokumen (`app/rooms`, `terms/2-2569`, …).
- **Simpan aman**: semua penulisan lewat fungsi `save_doc`, yang menolak versi lama.
  Kalau dua orang mengedit bersamaan, perubahan diterapkan ulang di atas data terbaru,
  jadi tidak ada lagi perubahan yang "balik sendiri".
- **Hak akses (dicek di database)**: petugas ruangan tidak bisa mengubah semester, kondisi umum,
  atau mempublikasikan jadwal. Pengunjung tanpa login hanya bisa membaca jadwal yang sudah dipublikasikan.
- **Update live**: Supabase Realtime mengirim perubahan ke semua browser yang terbuka.
- **Tanpa server**: buka `index.html` langsung dari komputer → aplikasi berjalan dalam mode offline
  (data tersimpan di browser saja).

## Batasan paket gratis
- Supabase menjeda project yang tidak dipakai 7 hari. Buka dashboard Supabase untuk mengaktifkan lagi,
  sebaiknya sehari sebelum presentasi.
- Vercel Hobby: untuk penggunaan non-komersial (proyek kuliah boleh).
