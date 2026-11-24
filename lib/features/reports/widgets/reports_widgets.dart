import '../../../core/widgets/app_notification.dart';
import '../../../core/widgets/guarded_form.dart';
import '../../../core/widgets/navigation_app_bar.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_scope.dart';
import '../services/geocoding_api.dart';

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/enums/user_profile.dart';
import '../../auth/state/auth_session.dart';
import '../repositories/local_reports_repository.dart';
import '../repositories/reports_database.dart';
import '../services/report_privacy.dart';
import '../services/report_location_service.dart';
import 'report_map.dart';
export '../../../core/enums/report_type.dart';
export '../../../core/enums/report_status.dart';
export '../../../core/enums/announcement_type.dart';
export '../../../core/enums/announcement_status.dart';
export '../../../core/enums/claim_status.dart';
export '../../../core/enums/match_status.dart';
export '../repositories/local_reports_repository.dart';
export '../../auth/state/auth_session.dart';

bool reportsAdmin(BuildContext c) =>
    c.read<AuthSession>().currentUser?.profile == UserProfile.admin;
String reportDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
Widget routeButton(BuildContext c, String text, String path) =>
    OutlinedButton(onPressed: () => c.push(path), child: Text(text));

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext c) => Theme(
    data: Theme.of(c).copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFF59E0B),
          foregroundColor: const Color(0xFF172554),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF92400E),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: const Color(0xFF92400E)),
      ),
      colorScheme: Theme.of(c).colorScheme.copyWith(
        primary: const Color(0xFFF59E0B),
        onPrimary: const Color(0xFF172554),
      ),
    ),
    child: Scaffold(
      appBar: NavigationAppBar(
        title: Text(title),
        backgroundColor: const Color(0xFFFFF4DF),
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
                      'Espace local de démonstration • aucune synchronisation communautaire',
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

class ReportsView<T> extends StatefulWidget {
  const ReportsView({super.key, required this.load, required this.builder});
  final Future<T> Function(LocalReportsRepository) load;
  final Widget Function(BuildContext, T) builder;
  @override
  State<ReportsView<T>> createState() => _ReportsViewState<T>();
}

class _ReportsViewState<T> extends State<ReportsView<T>> {
  Future<T>? future;
  Object? revision;
  Object? user;
  @override
  Widget build(BuildContext c) {
    final session = c.watch<AuthSession>();
    // A listener invalidates futures after durable writes.
    if (future == null ||
        revision != _revision ||
        user != session.currentUser) {
      revision = _revision;
      user = session.currentUser;
      future = widget.load(c.read<LocalReportsRepository>());
    }
    return FutureBuilder<T>(
      future: future,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return ReportsPage(
            title: 'Information',
            children: [
              Text(reportsError(s.error!)),
              TextButton(
                onPressed: () => setState(() => future = null),
                child: const Text('Réessayer'),
              ),
            ],
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return widget.builder(c, s.data as T);
      },
    );
  }

  int _revision = 0;
  ReportsDatabase? _db;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final d = context.read<ReportsDatabase>();
    if (d != _db) {
      _db?.removeListener(changed);
      _db = d;
      d.addListener(changed);
    }
  }

  void changed() {
    if (mounted) setState(() => _revision++);
  }

  @override
  void dispose() {
    _db?.removeListener(changed);
    super.dispose();
  }
}

Future<bool> reportAction(
  BuildContext c,
  Future<void> Function() action, {
  String success = 'Enregistré.',
}) async {
  try {
    await action();
    if (c.mounted) {
      AppNotification.success(c, success);
    }
    GuardedForm.markSaved();
    return true;
  } catch (e) {
    if (c.mounted) {
      AppNotification.error(c, reportsError(e));
    }
    return false;
  }
}

Future<bool> reportConfirm(BuildContext c, String message) async =>
    await showDialog<bool>(
      context: c,
      builder: (c) => AlertDialog(
        title: const Text('Confirmer la décision'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    ) ??
    false;

class ReportPhoto extends StatelessWidget {
  const ReportPhoto(this.reference, {super.key});
  final String? reference;
  @override
  Widget build(BuildContext c) {
    if (reference == null) return const SizedBox.shrink();
    if (reference!.startsWith('assets/')) {
      return Image.asset(reference!, height: 220, fit: BoxFit.contain);
    }
    return FutureBuilder<Uint8List?>(
      future: c.read<LocalReportsRepository>().readPhoto(reference!),
      builder: (c, s) => s.hasData
          ? Image.memory(s.data!, height: 220, fit: BoxFit.contain)
          : const Text('Photo indisponible'),
    );
  }
}

class ReportPhotoPicker extends StatefulWidget {
  const ReportPhotoPicker({super.key, required this.onChanged, this.existing});
  final void Function(Uint8List?) onChanged;
  final String? existing;
  @override
  State<ReportPhotoPicker> createState() => _ReportPhotoPickerState();
}

class _ReportPhotoPickerState extends State<ReportPhotoPicker> {
  Uint8List? bytes;
  bool busy = false;
  Future<void> pick() async {
    setState(() => busy = true);
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (f == null) return;
      if (await f.length() > 8 * 1024 * 1024) {
        throw const ReportsFailure('Choisissez une photo inférieure à 8 Mo.');
      }
      final raw = await f.readAsBytes();
      final codec = await ui.instantiateImageCodec(
        raw,
        targetWidth: 1200,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      if (png == null || png.lengthInBytes > 2 * 1024 * 1024) {
        throw const ReportsFailure(
          'Photo trop volumineuse après préparation (2 Mo maximum).',
        );
      }
      if (!mounted) return;
      setState(() => bytes = png.buffer.asUint8List());
      GuardedForm.markDirty();
      widget.onChanged(bytes);
    } catch (e) {
      if (mounted) {
        AppNotification.error(context, reportsError(e));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Column(
    children: [
      if (bytes != null)
        Image.memory(bytes!, height: 160, fit: BoxFit.contain)
      else if (widget.existing != null)
        ReportPhoto(widget.existing),
      OutlinedButton.icon(
        onPressed: busy ? null : pick,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(busy ? 'Préparation…' : 'Photo facultative'),
      ),
      const Text(
        'Les métadonnées de la photo sont retirées avant le stockage local.',
        style: TextStyle(fontSize: 12),
      ),
    ],
  );
}

class LocationFields extends StatefulWidget {
  const LocationFields({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onConsent,
    this.initialConsent = false,
    this.showMap = true,
    this.onPositionChanged,
  });
  final TextEditingController latitude, longitude;
  final ValueChanged<bool> onConsent;
  final bool initialConsent;
  final bool showMap;
  final VoidCallback? onPositionChanged;
  @override
  State<LocationFields> createState() => _LocationFieldsState();
}

class _LocationFieldsState extends State<LocationFields> {
  late bool consent = widget.initialConsent;
  bool busy = false;
  String? error;
  ApiValue<ApproximateAddress>? address;
  Future<void> reverseAddress() async {
    final lat = double.tryParse(widget.latitude.text),
        lon = double.tryParse(widget.longitude.text);
    if (lat == null || lon == null) return;
    final client = apiClient(context);
    if (client == null) return;
    setState(() {
      address = null;
      error = null;
    });
    try {
      final result = await GeocodingApi.forClient(client)
          .reverse(lat, lon, consent: true);
      if (mounted) setState(() => address = result);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiFailure ? e.message : 'Adresse externe indisponible, saisissez les coordonnées manuellement.',
        );
      }
    }
  }

  Future<void> gps() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final p = await context.read<ReportLocationService>().locate();
      if (!mounted) return;
      widget.latitude.text = p.latitude.toStringAsFixed(2);
      widget.longitude.text = p.longitude.toStringAsFixed(2);
      widget.onPositionChanged?.call();
      await reverseAddress();
    } catch (e) {
      if (mounted) setState(() => error = reportsError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Localisation facultative • seule une position arrondie à environ 1 km est publiée.',
      ),
      const Text(
        'Ce bouton autorise aussi l’envoi de coordonnées arrondies au géocodeur OSM pour afficher une ville approximative. Aucune adresse précise n’est publiée.',
      ),
      OutlinedButton(
        onPressed: busy ? null : gps,
        child: Text(busy ? 'Recherche GPS…' : 'Utiliser ma position GPS'),
      ),
      if (address != null) ...[
        Text(address!.value.city),
        Text(address!.value.area),
        Text(address!.response.notice),
      ],
      const Text(
        '© OpenStreetMap contributors • ODbL • adresse indicative non enregistrée.',
      ),
      TextButton(
        onPressed: busy
            ? null
            : () async {
                setState(() => busy = true);
                await reverseAddress();
                if (mounted) setState(() => busy = false);
              },
        child: const Text('Rechercher / Réessayer la ville de ces coordonnées'),
      ),
      TextButton(
        onPressed: () async {
          final controller = TextEditingController(
            text: apiClient(c) == null
                ? 'https://nominatim.openstreetmap.org/reverse'
                : GeocodingApi.forClient(apiClient(c)!).endpoint,
          );
          final value = await showDialog<String>(
            context: c,
            builder: (d) => AlertDialog(
              title: const Text('Fournisseur de géocodage'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'URL HTTPS /reverse',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(d),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(d, controller.text),
                  child: const Text('Appliquer'),
                ),
              ],
            ),
          );
          if (value != null && c.mounted && apiClient(c) != null) {
            try {
              await GeocodingApi.forClient(apiClient(c)!).setEndpoint(value);
              if (mounted) setState(() => address = null);
            } catch (e) {
              if (mounted) setState(() => error = e.toString());
            }
          }
        },
        child: const Text('Fournisseur de géocodage'),
      ),
      if (error != null)
        Text(error!, style: TextStyle(color: Theme.of(c).colorScheme.error)),
      TextField(
        controller: widget.latitude,
        onChanged: (_) {
          setState(() {
            address = null;
          });
          widget.onPositionChanged?.call();
        },
        decoration: const InputDecoration(
          labelText: 'Latitude (facultative)',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: widget.longitude,
        onChanged: (_) {
          setState(() {});
          widget.onPositionChanged?.call();
        },
        decoration: const InputDecoration(
          labelText: 'Longitude (facultative)',
          border: OutlineInputBorder(),
        ),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('J’accepte de publier cette position approximative.'),
        value: consent,
        onChanged: GuardedForm.track<bool?>((v) {
          setState(() => consent = v!);
          widget.onConsent(v!);
        }),
      ),
      TextButton(
        onPressed: () {
          widget.latitude.clear();
          widget.longitude.clear();
          setState(() {
            consent = false;
            address = null;
            error = null;
          });
          widget.onConsent(false);
          widget.onPositionChanged?.call();
        },
        child: const Text('Continuer sans localisation'),
      ),
      if (widget.showMap &&
          double.tryParse(widget.latitude.text) != null &&
          double.tryParse(widget.longitude.text) != null &&
          double.parse(widget.latitude.text).abs() <= 90 &&
          double.parse(widget.longitude.text).abs() <= 180)
        ReportMap(
          latitude: (double.parse(widget.latitude.text) * 100).round() / 100,
          longitude: (double.parse(widget.longitude.text) * 100).round() / 100,
          onTap: (lat, lon) => setState(() {
            widget.latitude.text = lat.toStringAsFixed(2);
            widget.longitude.text = lon.toStringAsFixed(2);
          }),
        ),
    ],
  );
}

Widget field(TextEditingController controller, String label, {int lines = 1}) =>
    TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      maxLines: lines,
    );
double? coordinate(TextEditingController c) {
  if (c.text.trim().isEmpty) return null;
  final n = double.tryParse(c.text.trim().replaceAll(',', '.'));
  if (n == null) {
    throw const ReportsFailure('Coordonnées numériques attendues.');
  }
  return n;
}

Widget dropdown<T>(
  T value,
  List<T> values,
  String label,
  String Function(T) name,
  ValueChanged<T?> changed,
) => DropdownButtonFormField<T>(
  initialValue: value,
  isExpanded: true,
  decoration: InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
  ),
  items: values
      .map((v) => DropdownMenuItem(value: v, child: Text(name(v))))
      .toList(),
  onChanged: changed,
);
