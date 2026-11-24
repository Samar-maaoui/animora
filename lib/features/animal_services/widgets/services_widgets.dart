import '../../../core/widgets/app_notification.dart';
import '../../../core/widgets/guarded_form.dart';
import '../../../core/widgets/navigation_app_bar.dart';

import 'dart:convert';

import '../../users/models/user.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/enums/user_profile.dart';
import '../../auth/state/auth_session.dart';
import '../../reports/widgets/reports_widgets.dart' show ReportPhotoPicker;
import '../services/services_failure.dart';
import 'services_scope.dart';
export '../services/services_failure.dart';
export 'services_scope.dart';
export '../../../core/enums/user_profile.dart';
export '../../../core/enums/appointment_status.dart';
export '../../../core/enums/pet_sitting_status.dart';
export '../../auth/state/auth_session.dart';
export '../../reports/widgets/reports_widgets.dart' show ReportPhotoPicker;

const veterinaryColor = Color(0xFF06B6D4), sittingColor = Color(0xFF22C55E);
String serviceDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String serviceDateTime(DateTime d) =>
    '${serviceDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String serviceTime(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
Widget serviceLink(BuildContext c, String label, String route) =>
    OutlinedButton(onPressed: () => c.push(route), child: Text(label));
UserProfile? serviceProfile(BuildContext c) =>
    c.watch<AuthSession>().currentUser?.profile;

class ServicePage extends StatelessWidget {
  const ServicePage({
    super.key,
    required this.title,
    required this.children,
    this.sitting = false,
  });
  final String title;
  final List<Widget> children;
  final bool sitting;
  @override
  Widget build(BuildContext c) => Theme(
    data: Theme.of(c).copyWith(
      colorScheme: Theme.of(c).colorScheme.copyWith(
        primary: sitting ? sittingColor : veterinaryColor,
        onPrimary: const Color(0xFF172554),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: sitting ? sittingColor : veterinaryColor,
          foregroundColor: const Color(0xFF172554),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF155E75),
        ),
      ),
    ),
    child: Scaffold(
      appBar: NavigationAppBar(
        title: Text(title),
        backgroundColor: (sitting ? sittingColor : veterinaryColor).withValues(
          alpha: 0.1,
        ),
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
                      'Démonstration locale • réservations et données privées sur cet appareil',
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

class ServiceView<T> extends StatefulWidget {
  const ServiceView({super.key, required this.load, required this.builder});
  final Future<T> Function(ServicesStore) load;
  final Widget Function(BuildContext, T) builder;
  @override
  State<ServiceView<T>> createState() => _ServiceViewState<T>();
}

class _ServiceViewState<T> extends State<ServiceView<T>> {
  Future<T>? future;
  int? revision;
  @override
  Widget build(BuildContext c) {
    final store = c.watch<ServicesStore>();
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
          return ServicePage(
            title: 'Information',
            children: [
              Text(servicesError(s.error!)),
              TextButton(
                onPressed: () => setState(() => future = null),
                child: const Text('Réessayer'),
              ),
              serviceLink(c, 'Retour à l’accueil', '/home'),
            ],
          );
        }
        if (!s.hasData) return const SizedBox.shrink();
        return widget.builder(c, s.data as T);
      },
    );
  }
}

Widget serviceField(
  TextEditingController controller,
  String label, {
  int lines = 1,
}) => TextField(
  controller: controller,
  decoration: InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
  ),
  maxLines: lines,
);
Widget serviceDropdown<T>(
  T? value,
  List<T> items,
  String label,
  String Function(T) name,
  ValueChanged<T?> onChanged,
) => DropdownButtonFormField<T>(
  key: ValueKey('$label/$value/${items.length}'),
  initialValue: items.contains(value) ? value : null,
  isExpanded: true,
  decoration: InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
  ),
  items: items
      .map(
        (v) => DropdownMenuItem(
          value: v,
          child: Text(name(v), overflow: TextOverflow.ellipsis),
        ),
      )
      .toList(),
  onChanged: onChanged,
);
Future<bool> serviceConfirm(BuildContext c, String message) async =>
    await showDialog<bool>(
      context: c,
      builder: (c) => AlertDialog(
        title: const Text('Confirmer'),
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
Future<bool> serviceAction(
  BuildContext c,
  Future<void> Function() action, {
  String message = 'Enregistré.',
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
      AppNotification.error(c, servicesError(e));
    }
    return false;
  }
}

Future<DateTime?> servicePickDate(
  BuildContext c,
  DateTime initial, {
  bool past = false,
  bool time = false,
}) async {
  final now = DateTime.now();
  final first = past ? DateTime(2000) : DateTime(now.year, now.month, now.day);
  final picked = await showDatePicker(
    context: c,
    initialDate: initial.isBefore(first) ? first : initial,
    firstDate: first,
    lastDate: DateTime(now.year + 10),
  );
  if (picked == null || !c.mounted) return null;
  if (!time) {
    GuardedForm.markDirty();
    return picked;
  }
  final t = await showTimePicker(
    context: c,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (t != null) GuardedForm.markDirty();
  return t == null
      ? null
      : DateTime(picked.year, picked.month, picked.day, t.hour, t.minute);
}

class ServicePhotoPicker extends StatelessWidget {
  const ServicePhotoPicker({super.key, required this.onChanged});
  final ValueChanged<Uint8List?> onChanged;
  @override
  Widget build(BuildContext c) => ReportPhotoPicker(onChanged: onChanged);
}

Widget serviceBadge(String label) => Align(
  alignment: Alignment.centerLeft,
  child: Chip(label: Text(label)),
);
Widget serviceCard(List<Widget> children) => Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children.expand((w) => [w, const SizedBox(height: 8)]).toList(),
    ),
  ),
);

class ServiceAvatar extends StatelessWidget {
  const ServiceAvatar(this.user, {super.key});
  final User user;
  @override
  Widget build(BuildContext c) {
    final initials =
        (user.firstName.isEmpty ? '' : user.firstName[0]) +
        (user.lastName.isEmpty ? '' : user.lastName[0]);
    Widget fallback() => Text(
      initials,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
    );
    Widget content = fallback();
    try {
      if (user.photo?.startsWith('data:image/') == true) {
        content = Image.memory(
          base64Decode(user.photo!.split(',').last),
          fit: BoxFit.cover,
          errorBuilder: (_, e, s) => fallback(),
        );
      } else if (user.photo?.startsWith('assets/') == true) {
        content = Image.asset(
          user.photo!,
          fit: BoxFit.cover,
          errorBuilder: (_, e, s) => fallback(),
        );
      }
    } catch (_) {}
    return CircleAvatar(
      radius: 30,
      backgroundColor: veterinaryColor.withValues(alpha: 0.15),
      child: ClipOval(
        child: SizedBox(width: 60, height: 60, child: Center(child: content)),
      ),
    );
  }
}
