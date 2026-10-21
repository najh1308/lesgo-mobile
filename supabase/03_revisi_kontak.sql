-- =====================================================================
-- GeoLearn - revisi: nomor kontak bimbel memakai nomor HP (format 08...).
-- Jalankan sekali di Supabase: SQL Editor > New query > tempel > Run.
-- Nomor ini fiktif untuk keperluan demo.
-- =====================================================================

update public.bimbel set kontak = '0812-5550-0101' where id = 1;
update public.bimbel set kontak = '0812-5550-0102' where id = 2;
update public.bimbel set kontak = '0812-5550-0103' where id = 3;
update public.bimbel set kontak = '0812-5550-0104' where id = 4;
update public.bimbel set kontak = '0812-5550-0105' where id = 5;
update public.bimbel set kontak = '0812-5550-0106' where id = 6;
update public.bimbel set kontak = '0812-5550-0107' where id = 7;
update public.bimbel set kontak = '0812-5550-0108' where id = 8;
update public.bimbel set kontak = '0813-5550-0201' where id = 9;
update public.bimbel set kontak = '0813-5550-0202' where id = 10;
update public.bimbel set kontak = '0813-5550-0203' where id = 11;
update public.bimbel set kontak = '0813-5550-0204' where id = 12;
update public.bimbel set kontak = '0813-5550-0205' where id = 13;
update public.bimbel set kontak = '0813-5550-0206' where id = 14;
update public.bimbel set kontak = '0813-5550-0207' where id = 15;
update public.bimbel set kontak = '0813-5550-0208' where id = 16;

-- Cek hasil:
select id, nama, kontak from public.bimbel order by id;
