-- =====================================================================
-- GeoLearn - 07: ganti 8 bimbel dummy Yogyakarta (id 9-16) dengan bimbel nyata
-- Nama, alamat, dan nomor telepon bersumber dari data publik (direktori yang memuat data
-- Google Maps). PERIKSA lagi di Google Maps sebelum dipakai: direktori bisa saja usang.
-- Program, harga, jadwal, kuota, jam buka, dan ulasan lama TIDAK diubah (tetap data contoh).
-- Pendaftaran/favorit/ulasan yang sudah ada tetap aman karena id bimbel tidak berubah.
-- Jalankan di Supabase: SQL Editor > New query > tempel > Run. Aman dijalankan ulang.
-- =====================================================================

-- 1. Kolom penanda data nyata + ID tempat Google Maps (aman jika sudah ada dari langkah sebelumnya).
alter table public.bimbel add column if not exists gmaps_place_id text;
alter table public.bimbel add column if not exists data_nyata boolean not null default false;

-- 2. Fungsi detail ikut mengirim gmaps_place_id dan data_nyata ke aplikasi.
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
    'gmaps_place_id', b.gmaps_place_id, 'data_nyata', b.data_nyata,
    'jumlah_review', (select count(*) from review r where r.bimbel_id = b.id),
    'jarak_km', case when p_lat is not null and p_lng is not null
                     then round(jarak_km(p_lat, p_lng, b.latitude::float8, b.longitude::float8)::numeric, 1) end,
    'is_favorit', exists (select 1 from favorit f where f.user_id = u.id and f.bimbel_id = b.id),
    'program', program_dengan_jadwal(b.id));
end $$;

-- 3. Ganti data. lat/lng sengaja null: isi dari Google Maps (klik kanan pada pin > salin koordinat),
--    lalu jalankan ulang. Selama null, koordinat lama dipertahankan (pin dan jarak belum akurat).
with baru (id, nama, alamat, kota, lat, lng, kontak) as (
  values
    (9, 'Ganesha Operation Kotabaru', 'Jl. Yos Sudarso No.27, Kotabaru, Gondokusuman, Kota Yogyakarta 55224', 'Yogyakarta', null::numeric, null::numeric, '0811-2386-294'),
    (10, 'Ganesha Operation Taman Siswa', 'Jl. Taman Siswa No.141, Wirogunan, Kec. Mergangsan, Kota Yogyakarta', 'Yogyakarta', null::numeric, null::numeric, '0811-2386-290'),
    (11, 'Neutron Yogyakarta', 'Jl. Prof. Dr. Sardjito No.25, Terban, Gondokusuman, Kota Yogyakarta', 'Yogyakarta', null::numeric, null::numeric, '0274-554360'),
    (12, 'Brain Academy Wirobrajan', 'Jl. HOS Cokroaminoto No.77, Pakuncen, Wirobrajan, Kota Yogyakarta', 'Yogyakarta', null::numeric, null::numeric, '0821-3483-3481'),
    (13, 'Bimbel YEC x MASTERPRIMA Jogja', 'Jl. Poncowolo No.15, Ketanggungan, Wirobrajan, Kota Yogyakarta 55252', 'Yogyakarta', null::numeric, null::numeric, '0878-3929-7479'),
    (14, 'Bimbel Les Privat Provision Jogja', 'Jl. Ring Road Utara, Gg. Narodo Gandok No.33b, Candok, Condongcatur, Kec. Depok, Kabupaten Sleman', 'Yogyakarta', null::numeric, null::numeric, '0857-9037-7353'),
    (15, 'Primagama Sleman', 'Jl. Solo No.36, Karangploso, Maguwoharjo, Kec. Depok, Kabupaten Sleman', 'Yogyakarta', null::numeric, null::numeric, '0274-898101'),
    (16, 'Faheema Bimbel', 'Jl. Langensari, Demangan, Gondokusuman, Kota Yogyakarta 55221', 'Yogyakarta', null::numeric, null::numeric, '0896-0415-3130')
),
perbarui_program as (
  -- nama bimbel lama yang tertulis di deskripsi program ikut diganti
  update public.program pr
  set deskripsi = replace(pr.deskripsi, b.nama, n.nama)
  from public.bimbel b join baru n on n.id = b.id
  where pr.bimbel_id = b.id and b.nama <> n.nama
  returning pr.id
)
update public.bimbel b
set nama = n.nama, alamat = n.alamat, kota = n.kota,
    latitude = coalesce(n.lat, b.latitude), longitude = coalesce(n.lng, b.longitude),
    kontak = n.kontak, deskripsi = null, data_nyata = true
from baru n
where b.id = n.id;

-- Cek hasil:
select id, nama, kota, kontak, alamat, latitude, longitude, data_nyata from public.bimbel where id between 9 and 16 order by id;
