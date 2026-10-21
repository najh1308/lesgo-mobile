import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'common.dart';

/// Kartu bimbel yang dipakai di Beranda, Cari, Peta, dan Favorit.
/// [horizontal] = sampul di kiri (untuk daftar hasil pencarian).
class BimbelCard extends StatelessWidget {
  final Bimbel bimbel;
  final VoidCallback onTap;
  final VoidCallback? onFavorit;
  final bool horizontal;
  final String? badge;
  const BimbelCard({
    super.key,
    required this.bimbel,
    required this.onTap,
    this.onFavorit,
    this.horizontal = true,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final b = bimbel;
    final info = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Wrap(spacing: 5, runSpacing: 4, children: [
              if (badge != null) Pill(badge!),
              if (b.jenjang.isNotEmpty) Pill(b.jenjang.join(' · '), color: AppColors.indigo),
              for (final m in b.mode)
                Pill(m == 'online' ? 'Online' : 'Offline',
                    color: m == 'online' ? AppColors.teal : AppColors.coralDark),
            ]),
          ),
          if (onFavorit != null)
            InkResponse(
              onTap: onFavorit,
              radius: 20,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(b.isFavorit ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 21, color: b.isFavorit ? AppColors.danger : AppColors.muted),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Text(b.nama,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.25)),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.location_on_outlined, size: 14, color: AppColors.muted),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              [if (b.kota.isNotEmpty) b.kota, if (b.jarakKm != null) Fmt.jarak(b.jarakKm)].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        ]),
        if (b.mapel.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(b.mapel,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          RatingText(Fmt.rating(b.rating), size: 12.5),
          const Spacer(),
          Flexible(
            child: Text('Mulai ${Fmt.harga(b.hargaMulai)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.indigo)),
          ),
        ]),
      ]),
    );

    return Panel(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: horizontal
          ? IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                BimbelCover(seed: b.id, fotoUrl: b.foto, width: 104, iconSize: 34),
                Expanded(child: info),
              ]),
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              BimbelCover(seed: b.id, fotoUrl: b.foto, height: 125),
              info,
            ]),
    );
  }
}
