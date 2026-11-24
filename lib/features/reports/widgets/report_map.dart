import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class ReportMap extends StatefulWidget {
  const ReportMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.radius,
    this.onTap,
  });
  final double latitude, longitude;
  final double? radius;
  final void Function(double, double)? onTap;
  @override
  State<ReportMap> createState() => _ReportMapState();
}

class _ReportMapState extends State<ReportMap> {
  final controller = MapController();
  @override
  void didUpdateWidget(covariant ReportMap old) {
    super.didUpdateWidget(old);
    if (loaded &&
        (old.latitude != widget.latitude ||
            old.longitude != widget.longitude)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && loaded) {
          controller.move(
            LatLng(widget.latitude, widget.longitude),
            controller.camera.zoom,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  bool loaded = false;
  bool failed = false;
  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Position approximative. Charger la carte transmet cette zone à OpenStreetMap.',
              ),
              TextButton(
                onPressed: () => setState(() => loaded = true),
                child: const Text('Charger la carte interactive'),
              ),
            ],
          ),
        ),
      );
    }
    final p = LatLng(widget.latitude, widget.longitude);
    return SizedBox(
      height: 300,
      child: FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter: p,
          initialZoom: 12,
          maxZoom: 14,
          onTap: (_, point) =>
              widget.onTap?.call(point.latitude, point.longitude),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.animora',
            errorTileCallback: (_, error, stack) {
              if (mounted && !failed) setState(() => failed = true);
            },
          ),
          if (widget.radius != null)
            CircleLayer(
              circles: [
                CircleMarker(
                  point: p,
                  radius: widget.radius!,
                  useRadiusInMeter: true,
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderColor: Colors.orange,
                  borderStrokeWidth: 2,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              Marker(
                point: p,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.orange,
                  size: 36,
                ),
              ),
            ],
          ),
          if (failed)
            const Align(
              alignment: Alignment.topCenter,
              child: Material(
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Fond de carte indisponible. Vos informations restent utilisables.',
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.white,
              child: TextButton(
                onPressed: () => launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                ),
                child: const Text('© OpenStreetMap contributors'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
