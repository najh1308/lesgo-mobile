import '../core/api_client.dart';
import '../core/local_db.dart';

class ChatPesan {
  final String role; // 'user' atau 'ai'
  final String teks;
  const ChatPesan(this.role, this.teks);
  bool get dariSaya => role == 'user';
  Map<String, String> toJson() => {'role': role, 'teks': teks};
}

/// Tutor AI: pertanyaan dikirim ke Edge Function Supabase "tutor-ai", yang meneruskannya ke LLM (Gemini).
/// Riwayat percakapan disimpan di Hive agar tetap terlihat saat offline.
class AiService {
  static const sapaan = ChatPesan('ai',
      'Halo! Aku Tutor LesGo. Tanyakan soal matematika, IPA, bahasa, atau materi UTBK. Aku jelaskan langkah demi langkah.');

  static Future<List<ChatPesan>> riwayat() async {
    try {
      final rows = await LocalDb.ambilChat();
      return rows.map((r) => ChatPesan(r['role'] as String, r['teks'] as String)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> hapusRiwayat() async {
    try {
      await LocalDb.hapusChat();
    } catch (_) {}
  }

  /// [percakapan] sudah termasuk pertanyaan terbaru di posisi terakhir.
  static Future<String> tanya(List<ChatPesan> percakapan) async {
    final kirim = percakapan.length > 12 ? percakapan.sublist(percakapan.length - 12) : percakapan;
    final data = await ApiClient.fungsi('tutor-ai', {'pesan': kirim.map((p) => p.toJson()).toList()});
    final jawaban = _rapikan(data['jawaban']?.toString() ?? '');
    try {
      await LocalDb.tambahChat('user', percakapan.last.teks);
      await LocalDb.tambahChat('ai', jawaban);
    } catch (_) {}
    return jawaban;
  }

  /// Membuang sisa format markdown yang kadang tetap dikirim model.
  static String _rapikan(String s) => s
      .replaceAll('**', '')
      .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*[*-]\s+', multiLine: true), '• ')
      .trim();
}
