import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../models/models.dart';

/// Peta OpenStreetMap (gratis, tanpa API key) dengan marker bimbel dan posisi pengguna.
class BimbelMap extends StatelessWidget {
  final List<Bimbel> items;
  final LatLng center;
  final LatLng? user;
  final int? selectedId;
  final ValueChanged<Bimbel>? onSelect;
  final double zoom;
  final bool interactive;
  const BimbelMap({
    super.key,
    required this.items,
    required this.center,
    this.user,
    this.selectedId,
    this.onSelect,
    this.zoom = 13,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: zoom,
          interactionOptions: InteractionOptions(
            flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: Config.mapUserAgent,
          ),
          MarkerLayer(markers: [
            if (user != null)
              Marker(
                point: user!,
                width: 26,
                height: 26,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            for (final b in items)
              Marker(
                point: LatLng(b.lat, b.lng),
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: onSelect == null ? null : () => onSelect!(b),
                  child: Icon(Icons.location_on,
                      size: b.id == selectedId ? 46 : 38,
                      color: b.id == selectedId ? AppColors.accent : AppColors.danger),
                ),
              ),
          ]),
        ],
      ),
      const Positioned(
        right: 6,
        bottom: 4,
        child: Text('© OpenStreetMap', style: TextStyle(fontSize: 10, color: Colors.black54)),
      ),
    ]);
  }
}
