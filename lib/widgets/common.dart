import 'package:flutter/material.dart';

void showMsg(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? const Color(0xFFE5484D) : const Color(0xFF1D2A44),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
}

/// Logo GeoLearn: kotak ikon peta + tulisan "GeoLearn".
class Brand extends StatelessWidget {
  final bool light;
  final double size;
  const Brand({super.key, this.light = false, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      BrandMark(light: light, size: size * 1.85),
      const SizedBox(width: 8),
      Text('GeoLearn',
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: light ? Colors.white : const Color(0xFF0F4C81),
          )),
    ]);
  }
}

class BrandMark extends StatelessWidget {
  final bool light;
  final double size;
  const BrandMark({super.key, this.light = false, this.size = 33});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: light ? Colors.white : const Color(0xFF00A896),
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Icon(Icons.map_outlined, size: size * 0.62, color: light ? const Color(0xFF0F4C81) : Colors.white),
    );
  }
}

/// Header putih untuk halaman tab (judul, subjudul, dan tombol di kanan).
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const PageHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, MediaQuery.paddingOf(context).top + 18, 18, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE6EBF0))),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: Color(0xFF1D2A44))),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: Color(0xFF6F7B8F))),
            ],
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}

/// Tombol ikon kotak bersudut membulat (42x42).
class SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool light;
  final bool dot;
  final String? tooltip;
  const SquareIconButton(this.icon, {super.key, this.onTap, this.light = false, this.dot = false, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: light ? Colors.white.withAlpha(31) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: light ? Colors.white.withAlpha(46) : const Color(0xFFE6EBF0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(alignment: Alignment.center, children: [
            Icon(icon, size: 21, color: light ? Colors.white : const Color(0xFF1D2A44)),
            if (dot)
              Positioned(
                right: 9,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4A261),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0F4C81)),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// Kartu putih dengan sudut membulat dan bayangan halus.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final bool shadow;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.color = Colors.white,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: shadow
            ? const [BoxShadow(color: Color(0x171D2A44), blurRadius: 26, offset: Offset(0, 8))]
            : null,
      ),
      child: Material(
        color: color,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: shadow ? BorderSide.none : const BorderSide(color: Color(0xFFE6EBF0)),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Kotak ikon kecil berwarna lembut (dipakai di menu dan pintasan).
class IconBox extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  final double size;
  const IconBox(this.icon, {super.key, this.bg = const Color(0xFFEAF2F8), this.fg = const Color(0xFF0F4C81), this.size = 38});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(icon, color: fg, size: size * 0.55),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  const PrimaryButton({super.key, required this.label, this.onPressed, this.loading = false, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: onPressed == null
            ? null
            : const [BoxShadow(color: Color(0x2E00A896), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00A896),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE6EBF0),
          elevation: 0,
          shadowColor: const Color(0x2E00A896),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: loading
            ? const SizedBox(
                height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 8)],
                  Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                ],
              ),
      ),
    );
  }
}

class AppField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool password;
  final TextInputType? keyboard;
  final String? errorText;
  final int maxLines;
  final ValueChanged<String>? onSubmitted;
  const AppField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.password = false,
    this.keyboard,
    this.errorText,
    this.maxLines = 1,
    this.onSubmitted,
  });

  @override
  State<AppField> createState() => _AppFieldState();
}

class _AppFieldState extends State<AppField> {
  bool _sembunyi = true;

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: Color(0xFFE6EBF0)),
    );
    return TextField(
      controller: widget.controller,
      obscureText: widget.password && _sembunyi,
      keyboardType: widget.keyboard,
      maxLines: widget.password ? 1 : widget.maxLines,
      onSubmitted: widget.onSubmitted,
      cursorColor: const Color(0xFF0F4C81),
      style: const TextStyle(color: Color(0xFF1D2A44)),
      decoration: InputDecoration(
        hintText: widget.hint,
        errorText: widget.errorText,
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: Color(0xFF8590A0), fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border,
        enabledBorder: border,
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFF00A896), width: 1.6),
        ),
        prefixIcon: Icon(widget.icon, color: const Color(0xFF6F7B8F), size: 21),
        suffixIcon: widget.password
            ? IconButton(
                icon: Icon(_sembunyi ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: const Color(0xFF6F7B8F)),
                onPressed: () => setState(() => _sembunyi = !_sembunyi),
              )
            : null,
      ),
    );
  }
}

/// Label kecil berbentuk kapsul. Warna bawaan: teal lembut.
class Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const Pill(this.label, {super.key, this.color = const Color(0xFF00A896), this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

/// Label huruf kapital kecil (mis. "PROMO PELAJAR", "TUTOR CERDAS 24/7").
class Eyebrow extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Eyebrow(this.text, {super.key, this.color = const Color(0xFFF4A261), this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
      Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: color)),
    ]);
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const IconBox(Icons.cloud_off_outlined, size: 64, bg: Color(0xFFFFF1E6), fg: Color(0xFFC56D2F)),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6F7B8F), height: 1.5)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F4C81),
              backgroundColor: Colors.white,
              minimumSize: const Size(160, 46),
              side: const BorderSide(color: Color(0xFFE6EBF0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            child: const Text('Coba lagi'),
          ),
        ]),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyView({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          IconBox(icon, size: 64, bg: const Color(0xFFE4F7F4), fg: const Color(0xFF00A896)),
          const SizedBox(height: 14),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6F7B8F), height: 1.5)),
        ]),
      ),
    );
  }
}

/// Judul bagian. [action] menampilkan tombol teks teal, mis. "Lihat semua >".
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  final String? action;
  final VoidCallback? onAction;
  const SectionTitle(this.text, {super.key, this.trailing, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Text(text,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: Color(0xFF1D2A44))),
      ),
      if (action != null)
        InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(action!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF00A896))),
              const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF00A896)),
            ]),
          ),
        ),
      ?trailing,
    ]);
  }
}

/// Pilihan segmen abu-abu (List/Peta, tab Aktivitas).
class SegmentToggle extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final bool expand;
  const SegmentToggle({super.key, required this.labels, required this.index, required this.onChanged, this.expand = false});

  @override
  Widget build(BuildContext context) {
    final items = [
      for (var i = 0; i < labels.length; i++)
        GestureDetector(
          onTap: () => onChanged(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: i == index ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: i == index
                  ? const [BoxShadow(color: Color(0xFFCFD6DC), blurRadius: 4, offset: Offset(0, 1))]
                  : null,
            ),
            child: Text(labels[i],
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                  color: i == index ? const Color(0xFF0F4C81) : const Color(0xFF1D2A44),
                )),
          ),
        ),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: const Color(0xFFEEF1F4), borderRadius: BorderRadius.circular(11)),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [for (final w in items) expand ? Expanded(child: w) : w],
      ),
    );
  }
}

/// Gambar profil bimbel. Urutan: [fotoUrl] (gambar online dari kolom bimbel.foto),
/// lalu logo bawaan `assets/bimbel/bimbel_ID.png`, lalu gradasi warna.
/// Jika gambar untuk id itu tidak ada, dipakai gradasi warna dengan ikon sekolah.
/// [avatar] = latar gradasi lebar dengan logo kotak di tengah (untuk header detail).
class BimbelCover extends StatelessWidget {
  final int seed;
  final double? height;
  final double? width;
  final BorderRadius borderRadius;
  final double iconSize;
  final bool avatar;
  final String? fotoUrl;
  const BimbelCover({
    super.key,
    required this.seed,
    this.height,
    this.width,
    this.borderRadius = BorderRadius.zero,
    this.iconSize = 44,
    this.avatar = false,
    this.fotoUrl,
  });

  static const _palet = [
    [Color(0xFF0F4C81), Color(0xFF00A896)],
    [Color(0xFF00A896), Color(0xFF0D7D76)],
    [Color(0xFF1D2A44), Color(0xFF0F4C81)],
    [Color(0xFFF4A261), Color(0xFFC56D2F)],
  ];

  static String asset(int id) => 'assets/bimbel/bimbel_$id.png';

  Widget _gradasi({bool ikon = true}) {
    final warna = _palet[seed.abs() % _palet.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: warna),
      ),
      child: Stack(children: [
        Positioned(
          right: -18,
          bottom: -22,
          child: Icon(Icons.public, size: iconSize * 2.4, color: Colors.white.withAlpha(25)),
        ),
        if (ikon) Center(child: Icon(Icons.school_rounded, size: iconSize, color: Colors.white.withAlpha(230))),
      ]),
    );
  }

  /// Gambar online jika ada (dengan logo bawaan saat memuat/gagal), selain itu logo bawaan.
  Widget _gambar() {
    final lokal = Image.asset(asset(seed), fit: BoxFit.cover, errorBuilder: (_, _, _) => _gradasi());
    final url = fotoUrl;
    if (url == null) return lokal;
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progres) => progres == null ? child : lokal,
      errorBuilder: (_, _, _) => lokal,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget isi;
    if (avatar) {
      final ukuran = iconSize * 1.7;
      isi = Stack(fit: StackFit.expand, children: [
        _gradasi(ikon: false),
        Center(
          child: Container(
            width: ukuran,
            height: ukuran,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ukuran * 0.28),
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ukuran * 0.28 - 4),
              child: _gambar(),
            ),
          ),
        ),
      ]);
    } else {
      isi = _gambar();
    }
    return SizedBox(
      height: height,
      width: width,
      child: ClipRRect(borderRadius: borderRadius, child: isi),
    );
  }
}

/// Teks rating oranye: ★ 4,9 (128)
class RatingText extends StatelessWidget {
  final String rating;
  final String? jumlah;
  final double size;
  const RatingText(this.rating, {super.key, this.jumlah, this.size = 13});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.star_rounded, size: size + 3, color: const Color(0xFFD77A25)),
      const SizedBox(width: 2),
      Text(rating, style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: const Color(0xFFD77A25))),
      if (jumlah != null) ...[
        const SizedBox(width: 3),
        Text(jumlah!, style: TextStyle(fontSize: size - 1, color: const Color(0xFF6F7B8F))),
      ],
    ]);
  }
}
