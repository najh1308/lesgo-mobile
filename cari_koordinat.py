#!/usr/bin/env python3
"""
cari_koordinat.py - mencari koordinat (lat, lng) 8 bimbel dari alamatnya lewat Nominatim
(OpenStreetMap, gratis tanpa API key), lalu menulis 07b_koordinat.sql.

Jalankan SETELAH 07_ganti_8_bimbel_jogja.sql:
  1) isi EMAIL di bawah (aturan penggunaan Nominatim)
  2) python cari_koordinat.py
  3) periksa tabel di layar, lalu jalankan isi 07b_koordinat.sql di Supabase SQL Editor
Titik dari OSM bisa meleset puluhan meter; kalau ada yang janggal, ganti manual dengan koordinat
dari Google Maps (klik kanan pada pin > salin koordinat).
Hanya memakai pustaka standar Python 3.8+.
"""
import json
import re
import sys
import time
import urllib.parse
import urllib.request

EMAIL = 'syarifahrifa06@gmail.com'

DATA = [  # (id bimbel, nama, alamat)
    (9, 'Ganesha Operation Kotabaru', 'Jl. Yos Sudarso No.27, Kotabaru, Gondokusuman, Yogyakarta'),
    (10, 'Ganesha Operation Taman Siswa', 'Jl. Taman Siswa No.141, Wirogunan, Mergangsan, Yogyakarta'),
    (11, 'Neutron Yogyakarta', 'Jl. Prof. Dr. Sardjito No.25, Terban, Gondokusuman, Yogyakarta'),
    (12, 'Brain Academy Wirobrajan', 'Jl. HOS Cokroaminoto No.77, Pakuncen, Wirobrajan, Yogyakarta'),
    (13, 'Bimbel YEC x MASTERPRIMA Jogja', 'Jl. Poncowolo No.15, Ketanggungan, Wirobrajan, Yogyakarta'),
    (14, 'Bimbel Les Privat Provision Jogja', 'Jl. Ring Road Utara, Gg. Narodo Gandok No.33b, Candok, Yogyakarta'),
    (15, 'Primagama Sleman', 'Jl. Solo No.36, Karangploso, Maguwoharjo, Sleman'),
    (16, 'Faheema Bimbel', 'Jl. Langensari, Demangan, Gondokusuman, Yogyakarta'),
]
BATAS = (-8.3, -7.4, 110.0, 110.7)  # lat min, lat maks, lng min, lng maks (wilayah DIY)


def cari(q):
    url = 'https://nominatim.openstreetmap.org/search?' + urllib.parse.urlencode(
        {'q': q, 'format': 'jsonv2', 'limit': 1, 'countrycodes': 'id'})
    req = urllib.request.Request(url, headers={'User-Agent': f'GeoLearn-ProyekKuliah/1.0 ({EMAIL})'})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode('utf-8'))


def main():
    if 'ISI_EMAIL' in EMAIL:
        sys.exit('Isi EMAIL di bagian atas skrip dulu (aturan penggunaan Nominatim).')
    baris, sql = [], ['-- Koordinat bimbel (dari OpenStreetMap/Nominatim). Periksa sebelum menjalankan.']
    for i, nama, alamat in DATA:
        kandidat = [alamat, re.sub(r'\s*No\.?\s*\S+', '', alamat), f'{nama}, Yogyakarta']
        hasil = None
        for q in kandidat:
            time.sleep(1.1)  # kebijakan Nominatim: maksimal 1 permintaan per detik
            try:
                r = cari(q)
            except Exception as e:  # noqa
                print(f'  ! gagal mencari "{q}": {e}')
                continue
            if r:
                lat, lng = float(r[0]['lat']), float(r[0]['lon'])
                if BATAS[0] <= lat <= BATAS[1] and BATAS[2] <= lng <= BATAS[3]:
                    hasil = (lat, lng, q, r[0].get('display_name', ''))
                    break
        if hasil:
            lat, lng, q, dn = hasil
            sql.append(f'update public.bimbel set latitude = {lat:.7f}, longitude = {lng:.7f} where id = {i};  -- {nama}')
            baris.append((i, nama, f'{lat:.6f}', f'{lng:.6f}', 'alamat lengkap' if q == kandidat[0] else 'perkiraan', dn[:60]))
        else:
            sql.append(f'-- id {i} ({nama}): koordinat tidak ditemukan, isi manual dari Google Maps')
            baris.append((i, nama, '-', '-', 'GAGAL', ''))
    print('\nid | nama | lat | lng | ketepatan | hasil OSM')
    for b in baris:
        print(' | '.join(str(x) for x in b))
    with open('07b_koordinat.sql', 'w', encoding='utf-8') as f:
        f.write('\n'.join(sql) + '\n')
    print('\nDitulis ke 07b_koordinat.sql. Buka Google Maps, cari tiap nama bimbel, dan cocokkan titiknya.')


if __name__ == '__main__':
    main()
