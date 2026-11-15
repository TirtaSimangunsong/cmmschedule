-- =====================================================================
-- CMMschedule · Supabase setup (jalankan sekali di SQL Editor)
-- Membuat: tabel profiles + docs, aturan akses (RLS), fungsi save_doc
-- dengan pengecekan versi, dan mengaktifkan update live (Realtime).
-- =====================================================================

-- 1) Peran pengguna: 'admin' (เจ้าหน้าที่จัดตารางสอน) atau 'room_officer' (เจ้าหน้าที่ดูแลห้องเรียน)
create table if not exists public.profiles (
  id    uuid primary key references auth.users(id) on delete cascade,
  email text,
  name  text,
  title text,
  role  text not null check (role in ('admin', 'room_officer'))
);

-- 2) Data aplikasi, disimpan per "dokumen" (path), misalnya:
--    app/terms, app/rooms, app/teachers, app/globals, app/notifs,
--    terms/2-2569, courses/2-2569, public/2-2569 (snapshot yang dipublikasikan)
create table if not exists public.docs (
  path       text primary key,
  data       jsonb not null,
  version    bigint not null default 1,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

-- 3) Helper: peran pengguna yang sedang login
create or replace function public.my_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid()
$$;

-- 4) Aturan akses (Row Level Security)
alter table public.profiles enable row level security;
alter table public.docs enable row level security;

drop policy if exists "read own profile" on public.profiles;
create policy "read own profile" on public.profiles
  for select to authenticated using (id = auth.uid());

-- Pengunjung tanpa login hanya boleh membaca daftar semester, kondisi umum,
-- dan jadwal yang sudah dipublikasikan.
drop policy if exists "public read" on public.docs;
create policy "public read" on public.docs
  for select to anon, authenticated
  using (path in ('app/terms', 'app/globals') or path like 'public/%');

-- Staf (punya baris di profiles) boleh membaca semua data.
drop policy if exists "staff read" on public.docs;
create policy "staff read" on public.docs
  for select to authenticated using (public.my_role() is not null);

-- Tidak ada policy insert/update/delete: semua penulisan WAJIB lewat save_doc.

-- 5) Simpan dokumen dengan pengecekan versi + aturan peran
create or replace function public.save_doc(p_path text, p_data jsonb, p_expected bigint default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_role text;
  v_cur  public.docs%rowtype;
  v_old_status text;
  v_new_status text;
begin
  select role into v_role from public.profiles where id = auth.uid();
  if v_role is null then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  select * into v_cur from public.docs where path = p_path for update;

  -- Petugas ruangan: tidak boleh mengubah daftar semester, kondisi umum, atau publikasi,
  -- dan hanya boleh mengubah status jadwal menjadi 'returned' atau 'confirmed'.
  if v_role = 'room_officer' then
    if p_path in ('app/terms', 'app/globals') or p_path like 'public/%' then
      raise exception 'forbidden_path' using errcode = '42501';
    end if;
    if p_path like 'terms/%' then
      v_old_status := coalesce(v_cur.data->>'status', '');
      v_new_status := coalesce(p_data->>'status', '');
      if v_new_status <> v_old_status and v_new_status not in ('returned', 'confirmed') then
        raise exception 'forbidden_status' using errcode = '42501';
      end if;
    end if;
  end if;

  if found then
    if p_expected is not null and v_cur.version <> p_expected then
      return jsonb_build_object('ok', false, 'conflict', true, 'version', v_cur.version, 'data', v_cur.data);
    end if;
    update public.docs
       set data = p_data, version = v_cur.version + 1, updated_at = now(), updated_by = auth.uid()
     where path = p_path;
    return jsonb_build_object('ok', true, 'version', v_cur.version + 1);
  else
    insert into public.docs (path, data, version, updated_by) values (p_path, p_data, 1, auth.uid());
    return jsonb_build_object('ok', true, 'version', 1);
  end if;
end;
$$;

revoke all on function public.save_doc(text, jsonb, bigint) from public, anon;
grant execute on function public.save_doc(text, jsonb, bigint) to authenticated;

-- 6) Update live: kirim perubahan tabel docs ke browser yang sedang membuka aplikasi
do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'docs') then
    alter publication supabase_realtime add table public.docs;
  end if;
end $$;
