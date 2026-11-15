-- =====================================================================
-- CMMschedule · tetapkan peran untuk akun
-- Langkah: buat dulu 2 user di Supabase → Authentication → Users → Add user
-- (centang "Auto Confirm User"), lalu ganti email di bawah bila perlu dan jalankan.
-- =====================================================================

insert into public.profiles (id, email, name, title, role)
select id, email, 'พี่ชมพู่', 'เจ้าหน้าที่จัดตารางสอน', 'admin'
from auth.users where email = 'admin@cmmschedule.demo'
on conflict (id) do update set role = excluded.role, name = excluded.name, title = excluded.title, email = excluded.email;

insert into public.profiles (id, email, name, title, role)
select id, email, 'พี่เมก', 'เจ้าหน้าที่ดูแลห้องเรียน', 'room_officer'
from auth.users where email = 'mek@cmmschedule.demo'
on conflict (id) do update set role = excluded.role, name = excluded.name, title = excluded.title, email = excluded.email;

-- Cek hasilnya:
select email, name, role from public.profiles;
