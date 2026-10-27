import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../services/ai_service.dart';
import '../widgets/common.dart';
import '../core/personalisasi.dart';

/// Fitur AI & LLM: tanya jawab dengan tutor berbasis model bahasa (lewat backend).
class TutorAiScreen extends StatefulWidget {
  const TutorAiScreen({super.key});

  @override
  State<TutorAiScreen> createState() => _TutorAiScreenState();
}

class _TutorAiScreenState extends State<TutorAiScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatPesan> _pesan = [];
  bool _menunggu = false;

  static const _contohUmum = [
    'Rekomendasi bimbel Matematika SMA terdekat',
    'Bimbel online yang murah untuk SMP?',
    'Jelaskan cara mencari KPK dari 12 dan 18',
    'Bagaimana cara mendaftar program bimbel?',
    'Tips belajar UTBK penalaran matematika',
  ];

  /// Contoh pertanyaan mengikuti jawaban personalisasi.
  List<String> get _contoh {
    final p = Personalisasi.i;
    if (!p.aktif) return _contohUmum;
    final mapel = p.mapel.isEmpty ? null : p.mapel.first;
    final jenjang = p.jenjang ?? '';
    return [
      'Rekomendasi bimbel ${mapel ?? ''} $jenjang terdekat'
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim(),
      if (p.budgetMax != null)
        'Bimbel ${mapel ?? ''} dengan harga ${p.ringkasanBiaya}'.replaceAll(
          RegExp(r'\s+'),
          ' ',
        ),
      if (mapel != null) 'Jelaskan konsep dasar $mapel dengan sederhana',
      'Bagaimana cara mendaftar program bimbel?',
      'Tips belajar ${mapel ?? 'efektif'} $jenjang'
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim(),
    ];
  }

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    final r = await AiService.riwayat();
    if (!mounted) return;
    setState(() => _pesan.addAll(r));
    _keBawah();
  }

  void _keBawah() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _kirim([String? teks]) async {
    final isi = (teks ?? _input.text).trim();
    if (isi.isEmpty || _menunggu) return;
    _input.clear();
    setState(() {
      _pesan.add(ChatPesan('user', isi));
      _menunggu = true;
    });
    _keBawah();
    try {
      final jawaban = await AiService.tanya(List.of(_pesan));
      if (!mounted) return;
      setState(() => _pesan.add(ChatPesan('ai', jawaban)));
    } on ApiException catch (e) {
      if (!mounted) return;
      // Pertanyaan yang gagal dikembalikan ke kotak input agar bisa dikirim ulang.
      setState(() => _pesan.removeLast());
      _input.text = isi;
      showMsg(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _menunggu = false);
      _keBawah();
    }
  }

  Future<void> _hapus() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus percakapan?'),
        content: const Text('Riwayat chat di HP ini akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AiService.hapusRiwayat();
    if (mounted) setState(_pesan.clear);
  }

  @override
  Widget build(BuildContext context) {
    final semua = [AiService.sapaan, ..._pesan];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        shape: const Border(),
        titleSpacing: 0,
        title: Row(
          children: [
            const IconBox(
              Icons.smart_toy_outlined,
              bg: AppColors.teal,
              fg: Colors.white,
              size: 40,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Geo · Chatbot',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _menunggu
                            ? AppColors.coral
                            : const Color(0xFF59DB9E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _menunggu ? 'Sedang mengetik...' : 'Siap membantu',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFBFD3DF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_pesan.isNotEmpty)
            IconButton(
              tooltip: 'Hapus percakapan',
              onPressed: _hapus,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.softTeal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, size: 15, color: AppColors.teal),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tanya pelajaran atau rekomendasi bimbel. Periksa kembali jawaban penting.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.tealDark),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.softGrey,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'PERCAKAPAN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                for (final p in semua) _Gelembung(p),
                if (_menunggu)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        _MiniBot(),
                        SizedBox(width: 8),
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Geo sedang berpikir...',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                if (_pesan.isEmpty && !_menunggu) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Coba tanyakan:',
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in _contoh)
                        ActionChip(
                          label: Text(c),
                          labelStyle: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.teal,
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFA8DCD5)),
                          onPressed: () => _kirim(c),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _kirim(),
                        decoration: InputDecoration(
                          hintText: 'Tulis pertanyaanmu...',
                          fillColor: AppColors.bg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: AppColors.line),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: AppColors.line),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                              color: AppColors.teal,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: _menunggu ? AppColors.line : AppColors.teal,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _menunggu ? null : _kirim,
                        child: const SizedBox(
                          width: 46,
                          height: 46,
                          child: Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBot extends StatelessWidget {
  const _MiniBot();

  @override
  Widget build(BuildContext context) {
    return const IconBox(
      Icons.smart_toy_outlined,
      bg: AppColors.softTeal,
      fg: AppColors.teal,
      size: 28,
    );
  }
}

class _Gelembung extends StatelessWidget {
  final ChatPesan p;
  const _Gelembung(this.p);

  @override
  Widget build(BuildContext context) {
    final saya = p.dariSaya;
    final gelembung = Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.74,
      ),
      decoration: BoxDecoration(
        color: saya ? AppColors.indigo : Colors.white,
        border: saya ? null : Border.all(color: AppColors.line),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(saya ? 18 : 4),
          bottomRight: Radius.circular(saya ? 4 : 18),
        ),
      ),
      child: SelectableText(
        p.teks,
        style: TextStyle(
          color: saya ? Colors.white : AppColors.ink,
          height: 1.45,
          fontSize: 14,
        ),
      ),
    );
    return Row(
      mainAxisAlignment: saya ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!saya) ...[
          const Padding(padding: EdgeInsets.only(bottom: 6), child: _MiniBot()),
          const SizedBox(width: 8),
        ],
        gelembung,
      ],
    );
  }
}
