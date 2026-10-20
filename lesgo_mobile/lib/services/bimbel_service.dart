import 'dart:convert';

import '../core/api_client.dart';
import '../core/local_db.dart';
import '../models/models.dart';

class BimbelService {
  static List<Bimbel> _parse(List raw) =>
      raw.map((e) => Bimbel.fromJson(Map<String, dynamic>.from(e))).toList();

  /// Daftar bimbel dengan filter. Jika [cacheKey] diisi, hasil disimpan ke
  /// database lokal dan dipakai saat tidak ada internet.
  static Future<List<Bimbel>> list({
    double? lat,
    double? lng,
    String? q,
    String? jenjang,
    String? mapel,
    String? mode,
    int? hargaMax,
    double? ratingMin,
    double? radius,
    String? sort,
    int perPage = 30,
    String? cacheKey,
  }) async {
    final query = <String, String>{
      if (lat != null) 'lat': '$lat',
      if (lng != null) 'lng': '$lng',
      if (q != null && q.isNotEmpty) 'q': q,
      if (jenjang != null) 'jenjang': jenjang,
      if (mapel != null) 'mapel': mapel,
      if (mode != null) 'mode': mode,
      if (hargaMax != null) 'harga_max': '$hargaMax',
      if (ratingMin != null) 'rating_min': '$ratingMin',
      if (radius != null) 'radius': '$radius',
      if (sort != null) 'sort': sort,
      'per_page': '$perPage',
    };
    try {
      final data = await ApiClient.get('/bimbel', query: query);
      final items = data['items'] as List;
      if (cacheKey != null) await LocalDb.putCache(cacheKey, jsonEncode(items));
      return _parse(items);
    } on ApiException catch (e) {
      if (e.isNetwork && cacheKey != null) {
        final cache = await LocalDb.getCache(cacheKey);
        if (cache != null) return _parse(jsonDecode(cache) as List);
      }
      rethrow;
    }
  }

  static Future<BimbelDetail> detail(int id, {double? lat, double? lng}) async {
    final data = await ApiClient.get('/bimbel/$id', query: {
      if (lat != null) 'lat': '$lat',
      if (lng != null) 'lng': '$lng',
    });
    return BimbelDetail.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<List<Review>> reviews(int id) async {
    final data = await ApiClient.get('/bimbel/$id/review') as List;
    return data.map((e) => Review.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<void> tambahReview(int id, int rating, String komentar) async {
    await ApiClient.post('/bimbel/$id/review', body: {'rating': rating, 'komentar': komentar});
  }

  static Future<List<Bimbel>> favorit() async {
    final data = await ApiClient.get('/favorit') as List;
    return _parse(data);
  }

  static Future<void> setFavorit(int id, bool aktif) async {
    if (aktif) {
      await ApiClient.post('/favorit/$id');
    } else {
      await ApiClient.delete('/favorit/$id');
    }
  }
}
