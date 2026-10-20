import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show FunctionException, PostgrestException, Supabase, SupabaseClient;

import 'config.dart';
import 'session.dart';

/// Error dari server atau jaringan, dengan pesan yang siap ditampilkan.
class ApiException implements Exception {
  final String message;
  final int status;
  final Map<String, dynamic> errors;
  final bool isNetwork;
  ApiException(this.message, {this.status = 0, this.errors = const {}, this.isNetwork = false});
  @override
  String toString() => message;
}

/// Dipakai untuk pindah ke halaman login saat token ditolak (401).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Penghubung ke web service di Supabase.
/// - [rpc]   : memanggil fungsi database api_* (lihat supabase/01_skema_dan_fungsi.sql)
/// - [fungsi]: memanggil Edge Function (misalnya tutor-ai)
/// Token login buatan sendiri dikirim sebagai parameter p_token.
class ApiClient {
  static const _timeout = Duration(seconds: 20);

  static SupabaseClient get _db => Supabase.instance.client;

  static Future<void> init() async {
    if (!Config.sudahDiisi) return; // pesan jelas akan muncul saat aplikasi memanggil server
    try {
      await Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabaseKey);
    } catch (e) {
      debugPrint('Supabase gagal disiapkan: $e');
    }
  }

  /// Fungsi tanpa login (register, login).
  static Future<dynamic> rpc(String fn, [Map<String, dynamic> params = const {}]) async {
    if (!Config.sudahDiisi) {
      throw ApiException('Alamat Supabase belum diisi di lib/core/config.dart', isNetwork: true);
    }
    try {
      return await _db.rpc(fn, params: params).timeout(_timeout);
    } on PostgrestException catch (e) {
      throw await _dariPostgrest(e);
    } on TimeoutException {
      throw ApiException('Server terlalu lama merespons. Coba lagi.', isNetwork: true);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi internet.', isNetwork: true);
    }
  }

  /// Fungsi yang butuh login: token ditambahkan otomatis.
  static Future<dynamic> rpcAuth(String fn, [Map<String, dynamic> params = const {}]) =>
      rpc(fn, {'p_token': Session.token, ...params});

  /// Memanggil Edge Function. Respons berbentuk {status, pesan, data}.
  static Future<dynamic> fungsi(String nama, Map<String, dynamic> body) async {
    if (!Config.sudahDiisi) {
      throw ApiException('Alamat Supabase belum diisi di lib/core/config.dart', isNetwork: true);
    }
    try {
      final res = await _db.functions
          .invoke(nama, body: {'token': Session.token, ...body})
          .timeout(const Duration(seconds: 60));
      final data = res.data;
      return data is Map ? data['data'] : data;
    } on FunctionException catch (e) {
      final d = e.details;
      final pesan = d is Map && d['pesan'] != null ? d['pesan'].toString() : 'Layanan sedang bermasalah (kode ${e.status}).';
      await _cek401(e.status);
      throw ApiException(pesan, status: e.status);
    } on TimeoutException {
      throw ApiException('Server terlalu lama merespons. Coba lagi.', isNetwork: true);
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi internet.', isNetwork: true);
    }
  }

  /// Fungsi SQL melempar error dengan kode status di "hint" dan error per kolom di "details".
  static Future<ApiException> _dariPostgrest(PostgrestException e) async {
    final status = int.tryParse(e.hint ?? '') ?? 0;
    if (status == 0) {
      // Bukan error buatan kita, misalnya fungsi belum dibuat di Supabase.
      final belumAda = e.code == 'PGRST202' || e.message.contains('Could not find the function');
      return ApiException(
        belumAda
            ? 'Fungsi di Supabase belum dibuat. Jalankan supabase/01_skema_dan_fungsi.sql.'
            : 'Terjadi kesalahan pada server: ${e.message}',
        status: 500,
      );
    }
    var errors = <String, dynamic>{};
    final detail = e.details;
    if (detail is String && detail.startsWith('{')) {
      try {
        errors = Map<String, dynamic>.from(jsonDecode(detail));
      } catch (_) {}
    }
    await _cek401(status);
    return ApiException(e.message, status: status, errors: errors);
  }

  static Future<void> _cek401(int status) async {
    if (status == 401 && Session.token != null) {
      await Session.clear();
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (r) => false);
    }
  }
}
