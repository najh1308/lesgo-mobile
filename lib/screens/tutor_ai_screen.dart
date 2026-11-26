import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
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
    'Tips belajar TKA Matematika untuk kelas 12',
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
    final dialogBtnStyle = TextButton.styleFrom(
      foregroundColor: const Color(0xFF00A896),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus percakapan?'),
        content: const Text('Riwayat chat di HP ini akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            style: dialogBtnStyle,
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: dialogBtnStyle,
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
      backgroundColor: const Color(0xFFF8F9FA), // ubah warna latar halaman ini di sini
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F4C81),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        shape: const Border(),
        titleSpacing: 0,
        title: Row(
          children: [
            const IconBox(
              Icons.smart_toy_outlined,
              bg: Color(0xFF00A896),
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
                            ? const Color(0xFFF4A261)
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
            color: const Color(0xFFE4F7F4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, size: 15, color: Color(0xFF00A896)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tanya pelajaran atau rekomendasi bimbel. Periksa kembali jawaban penting.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF0D7D76)),
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
                      color: const Color(0xFFEEF1F4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'PERCAKAPAN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Color(0xFF6F7B8F),
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF00A896),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Geo sedang berpikir...',
                          style: TextStyle(color: Color(0xFF6F7B8F)),
                        ),
                      ],
                    ),
                  ),
                if (_pesan.isEmpty && !_menunggu) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Coba tanyakan:',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF6F7B8F)),
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
                            color: Color(0xFF00A896),
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFA8DCD5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
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
              border: Border(top: BorderSide(color: Color(0xFFE6EBF0))),
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
                        cursorColor: const Color(0xFF0F4C81),
                        style: const TextStyle(color: Color(0xFF1D2A44)),
                        decoration: InputDecoration(
                          hintText: 'Tulis pertanyaanmu...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF8590A0),
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: Color(0xFFE6EBF0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: Color(0xFFE6EBF0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                              color: Color(0xFF00A896),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: _menunggu ? const Color(0xFFE6EBF0) : const Color(0xFF00A896),
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
      bg: Color(0xFFE4F7F4),
      fg: Color(0xFF00A896),
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
        color: saya ? const Color(0xFF0F4C81) : Colors.white,
        border: saya ? null : Border.all(color: const Color(0xFFE6EBF0)),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(saya ? 18 : 4),
          bottomRight: Radius.circular(saya ? 4 : 18),
        ),
      ),
      child: SelectableText(
        p.teks,
        cursorColor: const Color(0xFF0F4C81),
        style: TextStyle(
          color: saya ? Colors.white : const Color(0xFF1D2A44),
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
