import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../services/ai_service.dart';
import '../widgets/common.dart';

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

  static const _contoh = [
    'Jelaskan cara mencari KPK dari 12 dan 18',
    'Apa itu fotosintesis?',
    'Bantu aku paham persamaan linear satu variabel',
    'Tips belajar UTBK penalaran matematika',
  ];

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
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
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
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
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
        title: const Text('Tutor AI'),
        actions: [
          if (_pesan.isNotEmpty)
            IconButton(tooltip: 'Hapus percakapan', onPressed: _hapus, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              for (final p in semua) _Gelembung(p),
              if (_menunggu)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('Tutor sedang berpikir...', style: TextStyle(color: AppColors.muted)),
                  ]),
                ),
              if (_pesan.isEmpty && !_menunggu) ...[
                const SizedBox(height: 8),
                const Text('Coba tanyakan:', style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in _contoh)
                    ActionChip(label: Text(c), onPressed: () => _kirim(c)),
                ]),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _kirim(),
                  decoration: const InputDecoration(hintText: 'Tulis pertanyaanmu...'),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: _menunggu ? null : _kirim,
                icon: const Icon(Icons.send_rounded),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Gelembung extends StatelessWidget {
  final ChatPesan p;
  const _Gelembung(this.p);

  @override
  Widget build(BuildContext context) {
    final saya = p.dariSaya;
    return Align(
      alignment: saya ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        decoration: BoxDecoration(
          color: saya ? AppColors.primary : Colors.white,
          border: saya ? null : Border.all(color: AppColors.line),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(saya ? 16 : 4),
            bottomRight: Radius.circular(saya ? 4 : 16),
          ),
        ),
        child: SelectableText(
          p.teks,
          style: TextStyle(color: saya ? Colors.white : AppColors.ink, height: 1.4),
        ),
      ),
    );
  }
}
