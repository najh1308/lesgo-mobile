-- =====================================================================
-- GeoLearn - revisi: gambar profil online untuk setiap bimbel.
-- Jalankan sekali di Supabase: SQL Editor > New query > tempel > Run.
--
-- Kolom bimbel.foto sudah ada di skema. File ini membuat fungsi API ikut
-- mengirim kolom tersebut ke aplikasi. Isi kolom foto dengan URL gambar
-- (https://...). Jika kosong, aplikasi memakai logo bawaan.
-- =====================================================================

create or replace function public.api_bimbel_list(
  p_token text, p_lat float8 default null, p_lng float8 default null, p_q text default null,
  p_jenjang text default null, p_mapel text default null, p_mode text default null,
  p_harga_max int default null, p_rating_min numeric default null, p_radius float8 default null,
  p_sort text default null, p_per_page int default 20)
returns jsonb language plpgsql security definer set search_path = public, extensions, internal as $$
declare
  u users := user_dari_token(p_token);
  v_lokasi boolean := p_lat is not null and p_lng is not null;
  v_sort text := coalesce(p_sort, case when p_lat is not null and p_lng is not null then 'terdekat' else 'rating' end);
  v_q text := case when nullif(trim(p_q), '') is null then null else '%' || trim(p_q) || '%' end;
  v_limit int := least(50, greatest(1, coalesce(p_per_page, 20)));
  v_items jsonb;
begin
  with dasar as (
    select b.id, b.nama, b.alamat, b.kota, b.latitude, b.longitude, b.rating_avg, b.foto,
           min(p.harga_idr) as harga_mulai,
           array_agg(distinct p.jenjang order by p.jenjang) as jenjang,
           mapel_bimbel(b.id) as mapel,
           array_agg(distinct p.mode order by p.mode) as mode,
           case when v_lokasi then jarak_km(p_lat, p_lng, b.latitude::float8, b.longitude::float8) end as jarak,
           exists (select 1 from favorit f where f.bimbel_id = b.id and f.user_id = u.id) as is_favorit
    from bimbel b join program p on p.bimbel_id = b.id
    where (v_q is null or b.nama ilike v_q or b.kota ilike v_q or b.alamat ilike v_q
           or p.mapel ilike v_q or p.nama_program ilike v_q)
      and (p_jenjang is null or p.jenjang = upper(p_jenjang))
      and (p_mapel is null or p.mapel ilike '%' || p_mapel || '%')
      and (p_mode is null or p.mode = lower(p_mode))
      and (p_harga_max is null or p.harga_idr <= p_harga_max)
      and (p_rating_min is null or b.rating_avg >= p_rating_min)
    group by b.id
  ), terurut as (
    select *, row_number() over (order by
        case when v_sort = 'termurah' then harga_mulai end asc,
        case when v_sort = 'rating' then rating_avg end desc,
        case when v_sort not in ('termurah', 'rating') then jarak end asc,
        nama asc) as urutan
    from dasar
    where p_radius is null or not v_lokasi or jarak <= p_radius
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', id, 'nama', nama, 'alamat', alamat, 'kota', kota,
      'latitude', latitude, 'longitude', longitude, 'rating_avg', rating_avg,
      'harga_mulai', harga_mulai, 'jenjang', to_jsonb(jenjang), 'mapel', mapel, 'mode', to_jsonb(mode),
      'jarak_km', round(jarak::numeric, 1), 'is_favorit', is_favorit, 'foto', foto) order by urutan), '[]'::jsonb)
  into v_items from terurut where urutan <= v_limit;
  return jsonb_build_object('items', v_items, 'per_page', v_limit);
end $$;

create or replace function public.api_bimbel_detail(p_token text, p_id bigint, p_lat float8 default null, p_lng float8 default null)
returns jsonb language plpgsql security definer set search_path = public, extensions, internal as $$
declare
  u users := user_dari_token(p_token);
  b bimbel;
begin
  select * into b from bimbel where id = p_id;
  if not found then perform gagal(404, 'Bimbel tidak ditemukan'); end if;
  return jsonb_build_object(
    'id', b.id, 'nama', b.nama, 'alamat', b.alamat, 'kota', b.kota,
    'latitude', b.latitude, 'longitude', b.longitude, 'deskripsi', b.deskripsi,
    'kontak', b.kontak, 'jam_buka', b.jam_buka, 'rating_avg', b.rating_avg, 'foto', b.foto,
    'jumlah_review', (select count(*) from review r where r.bimbel_id = b.id),
    'jarak_km', case when p_lat is not null and p_lng is not null
                     then round(jarak_km(p_lat, p_lng, b.latitude::float8, b.longitude::float8)::numeric, 1) end,
    'is_favorit', exists (select 1 from favorit f where f.user_id = u.id and f.bimbel_id = b.id),
    'program', program_dengan_jadwal(b.id));
end $$;

create or replace function public.api_favorit_list(p_token text)
returns jsonb language plpgsql security definer set search_path = public, extensions, internal as $$
declare u users := user_dari_token(p_token);
begin
  return (
    select coalesce(jsonb_agg(x.j order by x.waktu desc), '[]'::jsonb) from (
      select max(f.created_at) as waktu, jsonb_build_object(
          'id', b.id, 'nama', b.nama, 'alamat', b.alamat, 'kota', b.kota,
          'latitude', b.latitude, 'longitude', b.longitude, 'rating_avg', b.rating_avg,
          'harga_mulai', min(p.harga_idr),
          'jenjang', to_jsonb(array_agg(distinct p.jenjang order by p.jenjang)),
          'mapel', mapel_bimbel(b.id), 'foto', b.foto,
          'is_favorit', true) as j
      from favorit f join bimbel b on b.id = f.bimbel_id join program p on p.bimbel_id = b.id
      where f.user_id = u.id
      group by b.id) x);
end $$;

-- ---------------------------------------------------------------------
-- Cara mengisi gambar (contoh). Ganti URL dengan link gambar milikmu,
-- misalnya Public URL dari Supabase Storage (bucket publik "bimbel").
-- ---------------------------------------------------------------------
-- update public.bimbel set foto = 'https://<project>.supabase.co/storage/v1/object/public/bimbel/1.jpg' where id = 1;
-- update public.bimbel set foto = null where id = 1;   -- kembali ke logo bawaan

select id, nama, foto from public.bimbel order by id;
