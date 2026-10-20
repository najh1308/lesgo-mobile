import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'common.dart';

/// Kartu bimbel yang dipakai di Beranda, Cari, dan Favorit.
class BimbelCard extends StatelessWidget {
  final Bimbel bimbel;
  final VoidCallback onTap;
  final VoidCallback? onFavorit;
  const BimbelCard({super.key, required this.bimbel, required this.onTap, this.onFavorit});

  @override
  Widget build(BuildContext context) {
    final b = bimbel;
    return Panel(
      onTap: onTap,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.school_rounded, size: 38, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.nama,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 4),
            Wrap(spacing: 10, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (b.jarakKm != null)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.location_on, size: 15, color: AppColors.muted),
                  Text(Fmt.jarak(b.jarakKm), style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star_rounded, size: 16, color: AppColors.accent),
                Text(Fmt.rating(b.rating), style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ]),
              Text('mulai ${Fmt.harga(b.hargaMulai)}/bulan',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ]),
            const SizedBox(height: 6),
            Text(b.mapel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              Pill(b.jenjang.join(' · ')),
              for (final m in b.mode)
                Pill(m == 'online' ? 'Online' : 'Offline',
                    color: m == 'online' ? AppColors.success : AppColors.accent),
            ]),
          ]),
        ),
        if (onFavorit != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onFavorit,
            icon: Icon(b.isFavorit ? Icons.bookmark : Icons.bookmark_border,
                color: b.isFavorit ? AppColors.primary : AppColors.muted),
          ),
      ]),
    );
  }
}
