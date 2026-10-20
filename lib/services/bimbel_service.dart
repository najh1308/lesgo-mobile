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
    final params = <String, dynamic>{
      if (lat != null) 'p_lat': lat,
      if (lng != null) 'p_lng': lng,
      if (q != null && q.isNotEmpty) 'p_q': q,
      if (jenjang != null) 'p_jenjang': jenjang,
      if (mapel != null) 'p_mapel': mapel,
      if (mode != null) 'p_mode': mode,
      if (hargaMax != null) 'p_harga_max': hargaMax,
      if (ratingMin != null) 'p_rating_min': ratingMin,
      if (radius != null) 'p_radius': radius,
      if (sort != null) 'p_sort': sort,
      'p_per_page': perPage,
    };
    try {
      final data = await ApiClient.rpcAuth('api_bimbel_list', params);
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
    final data = await ApiClient.rpcAuth('api_bimbel_detail', {
      'p_id': id,
      if (lat != null) 'p_lat': lat,
      if (lng != null) 'p_lng': lng,
    });
    return BimbelDetail.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<List<Review>> reviews(int id) async {
    final data = await ApiClient.rpcAuth('api_review_list', {'p_bimbel_id': id}) as List;
    return data.map((e) => Review.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<void> tambahReview(int id, int rating, String komentar) async {
    await ApiClient.rpcAuth('api_review_add', {'p_bimbel_id': id, 'p_rating': rating, 'p_komentar': komentar});
  }

  static Future<List<Bimbel>> favorit() async {
    final data = await ApiClient.rpcAuth('api_favorit_list') as List;
    return _parse(data);
  }

  static Future<void> setFavorit(int id, bool aktif) async {
    await ApiClient.rpcAuth('api_favorit_set', {'p_bimbel_id': id, 'p_aktif': aktif});
  }
}
