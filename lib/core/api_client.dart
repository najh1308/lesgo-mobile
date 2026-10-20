import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

/// Klien HTTP tunggal: menambahkan token, memeriksa status, dan mengambil field `data`.
class ApiClient {
  static const _timeout = Duration(seconds: 15);

  static Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${Config.baseUrl}/api$path').replace(queryParameters: query);

  static Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{'Accept': 'application/json'};
    if (json) h['Content-Type'] = 'application/json';
    if (Session.token != null) h['Authorization'] = 'Bearer ${Session.token}';
    return h;
  }

  static Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send(() => http.get(_uri(path, query), headers: _headers()));

  static Future<dynamic> post(String path, {Object? body}) => _send(() =>
      http.post(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})));

  static Future<dynamic> put(String path, {Object? body}) => _send(() =>
      http.put(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})));

  static Future<dynamic> delete(String path) =>
      _send(() => http.delete(_uri(path), headers: _headers()));

  /// Unggah satu file (multipart), misalnya foto profil.
  static Future<dynamic> upload(String path, String field, String filePath) =>
      _send(() async {
        final req = http.MultipartRequest('POST', _uri(path))
          ..headers.addAll(_headers(json: false))
          ..files.add(await http.MultipartFile.fromPath(field, filePath));
        return http.Response.fromStream(await req.send());
      });

  static Future<dynamic> _send(Future<http.Response> Function() call) async {
    http.Response res;
    try {
      res = await call().timeout(_timeout);
    } on SocketException {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi internet.', isNetwork: true);
    } on TimeoutException {
      throw ApiException('Server terlalu lama merespons. Coba lagi.', isNetwork: true);
    } on http.ClientException {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi internet.', isNetwork: true);
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Respons server tidak dikenali (kode ${res.statusCode}).', status: res.statusCode);
    }

    if (res.statusCode >= 400) {
      if (res.statusCode == 401 && Session.token != null) {
        await Session.clear();
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (r) => false);
      }
      throw ApiException(
        body['pesan']?.toString() ?? 'Terjadi kesalahan',
        status: res.statusCode,
        errors: Map<String, dynamic>.from(body['errors'] ?? {}),
      );
    }
    return body['data'];
  }
}
