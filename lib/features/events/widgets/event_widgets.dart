import '../../../core/widgets/app_notification.dart';
import '../../../core/widgets/guarded_form.dart';
import '../../../core/widgets/navigation_app_bar.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr/qr.dart';

import 'events_scope.dart';
import '../services/event_rules.dart';
export 'events_scope.dart';
export '../services/event_rules.dart';
export '../../../core/enums/event_type.dart';
export '../../../core/enums/event_status.dart';
export '../../../core/enums/registration_type.dart';
export '../../../core/enums/registration_status.dart';
export '../../../core/enums/volunteer_task_status.dart';
export '../../../core/enums/user_profile.dart';
export '../../auth/state/auth_session.dart';
export '../../animal_services/widgets/services_widgets.dart'
    show
        serviceDate,
        serviceDateTime,
        serviceLink,
        serviceBadge,
        serviceField,
        serviceDropdown,
        serviceConfirm,
        servicePickDate,
        ServicePhotoPicker;

const eventsColor = Color(0xFFFF6B6B);
Widget eventCard(List<Widget> children) => Card(
  semanticContainer: false,
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children.expand((w) => [w, const SizedBox(height: 8)]).toList(),
    ),
  ),
);

class EventsPage extends StatelessWidget {
  const EventsPage({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext c) => Theme(
    data: Theme.of(c).copyWith(
      colorScheme: Theme.of(c).colorScheme.copyWith(primary: eventsColor),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF9F2635),
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF9F2635),
        ),
      ),
    ),
    child: Scaffold(
      appBar: NavigationAppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => c.read<EventsStore>().refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
        backgroundColor: const Color(0xFFFFE8E8),
      ),
      body: GuardedForm(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Événements gratuits • données et billets conservés sur cet appareil',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    ...children.expand((w) => [w, const SizedBox(height: 12)]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class EventsView<T> extends StatefulWidget {
  const EventsView({super.key, required this.load, required this.builder});
  final Future<T> Function(EventsStore) load;
  final Widget Function(BuildContext, T) builder;
  @override
  State<EventsView<T>> createState() => _EventsViewState<T>();
}

class _EventsViewState<T> extends State<EventsView<T>> {
  Future<T>? future;
  int? revision;
  @override
  Widget build(BuildContext c) {
    final store = c.watch<EventsStore>();
    if (future == null || revision != store.revision) {
      revision = store.revision;
      future = widget.load(store);
    }
    return FutureBuilder<T>(
      future: future,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (s.hasError) {
          return EventsPage(
            title: 'Information',
            children: [
              Text(eventError(s.error!)),
              TextButton(
                onPressed: () => setState(() => future = null),
                child: const Text('Réessayer'),
              ),
            ],
          );
        }
        if (!s.hasData) return const SizedBox.shrink();
        return widget.builder(c, s.data as T);
      },
    );
  }
}

Future<bool> eventAction(
  BuildContext c,
  Future<void> Function() action, {
  String message = 'Enregistré sur cet appareil.',
}) async {
  try {
    await action();
    if (c.mounted) {
      AppNotification.success(c, message);
    }
    GuardedForm.markSaved();
    return true;
  } catch (e) {
    if (c.mounted) {
      AppNotification.error(c, eventError(e));
    }
    return false;
  }
}

class EventPhoto extends StatefulWidget {
  const EventPhoto(this.eventId, {super.key, this.reference});
  final int eventId;
  final String? reference;
  @override
  State<EventPhoto> createState() => _EventPhotoState();
}

class _EventPhotoState extends State<EventPhoto> {
  @override
  void didUpdateWidget(covariant EventPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId ||
        oldWidget.reference != widget.reference) {
      future = null;
    }
  }

  Future<Uint8List?>? future;
  int? revision;
  @override
  Widget build(BuildContext c) {
    final store = c.watch<EventsStore>();
    if (future == null || revision != store.revision) {
      revision = store.revision;
      future = widget.reference == null
          ? store.events.eventPhoto(widget.eventId)
          : store.reports.reportPhoto(widget.eventId, widget.reference!);
    }
    return FutureBuilder<Uint8List?>(
      future: future,
      builder: (c, s) {
        if (s.connectionState == ConnectionState.done && s.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              s.data!,
              height: 190,
              fit: BoxFit.contain,
              errorBuilder: (_, e, st) => const Text('Image indisponible'),
            ),
          );
        }
        return const SizedBox(
          height: 90,
          child: Icon(Icons.event_outlined, size: 48, color: eventsColor),
        );
      },
    );
  }
}

class EventQr extends StatelessWidget {
  const EventQr(this.code, {super.key});
  final String code;
  @override
  Widget build(BuildContext c) => Semantics(
    label: 'QR code du billet, code également disponible en texte',
    image: true,
    child: Center(
      child: SizedBox(
        width: 240,
        height: 240,
        child: CustomPaint(painter: EventQrPainter(code)),
      ),
    ),
  );
}

class EventQrPainter extends CustomPainter {
  EventQrPainter(String code)
    : image = QrImage(
        QrCode.fromData(data: code, errorCorrectLevel: QrErrorCorrectLevel.M),
      );
  final QrImage image;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final cell = size.shortestSide / (image.moduleCount + 8);
    final ink = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (var row = 0; row < image.moduleCount; row++) {
      for (var col = 0; col < image.moduleCount; col++) {
        if (image.isDark(row, col)) {
          canvas.drawRect(
            Rect.fromLTWH((col + 4) * cell, (row + 4) * cell, cell, cell),
            ink,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(EventQrPainter old) => old.image != image;
}

class EventMap extends StatefulWidget {
  const EventMap({super.key, required this.latitude, required this.longitude});
  final double latitude, longitude;
  @override
  State<EventMap> createState() => _EventMapState();
}

class _EventMapState extends State<EventMap> {
  bool visible = false;
  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Coordonnées : ${widget.latitude}, ${widget.longitude}'),
      OutlinedButton.icon(
        icon: const Icon(Icons.map_outlined),
        onPressed: () => setState(() => visible = !visible),
        label: Text(
          visible
              ? 'Masquer la carte'
              : 'Afficher la carte (connexion nécessaire)',
        ),
      ),
      if (visible) ...[
        SizedBox(
          height: 240,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(widget.latitude, widget.longitude),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'tn.animora.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(widget.latitude, widget.longitude),
                    child: const Icon(
                      Icons.location_on,
                      color: eventsColor,
                      size: 36,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Text(
          '© OpenStreetMap contributors • fond de carte en ligne',
          style: TextStyle(fontSize: 12),
        ),
      ],
    ],
  );
}
