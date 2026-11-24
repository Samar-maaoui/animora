import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

enum NotificationKind { success, error, info, warning }

/// Modern in-app notification shown at the TOP of the screen, in the app
/// theme: white card, coloured icon bubble, title + message, swipe up or
/// tap ✕ to close. Replaces the bottom SnackBars.
abstract final class AppNotification {
  static OverlayEntry? _current;

  static void success(BuildContext context, String message, {String? title}) =>
      show(context, message, kind: NotificationKind.success, title: title);
  static void error(BuildContext context, String message, {String? title}) =>
      show(context, message, kind: NotificationKind.error, title: title);
  static void info(BuildContext context, String message, {String? title}) =>
      show(context, message, title: title);
  static void warning(BuildContext context, String message, {String? title}) =>
      show(context, message, kind: NotificationKind.warning, title: title);

  static void show(
    BuildContext context,
    String message, {
    NotificationKind kind = NotificationKind.info,
    String? title,
    Duration duration = const Duration(milliseconds: 3500),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    dismiss();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _NotificationToast(
        message: message,
        title: title ?? _defaultTitle(kind),
        kind: kind,
        duration: duration,
        onClosed: () {
          if (_current == entry) _current = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  /// Removes the visible notification, if any.
  static void dismiss() {
    final entry = _current;
    _current = null;
    if (entry != null && entry.mounted) entry.remove();
  }

  static String _defaultTitle(NotificationKind kind) => switch (kind) {
    NotificationKind.success => 'C’est fait',
    NotificationKind.error => 'Oups…',
    NotificationKind.warning => 'Attention',
    NotificationKind.info => 'Information',
  };
}

class _NotificationToast extends StatefulWidget {
  const _NotificationToast({
    required this.message,
    required this.title,
    required this.kind,
    required this.duration,
    required this.onClosed,
  });
  final String message, title;
  final NotificationKind kind;
  final Duration duration;
  final VoidCallback onClosed;

  @override
  State<_NotificationToast> createState() => _NotificationToastState();
}

class _NotificationToastState extends State<_NotificationToast>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 200),
  )..forward();
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _close);
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    await _controller.reverse();
    widget.onClosed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  (IconData, Color, Color) get _style => switch (widget.kind) {
    NotificationKind.success => (
      Icons.check_circle_rounded,
      AppColors.adoption,
      AppColors.greenLight,
    ),
    NotificationKind.error => (
      Icons.error_rounded,
      const Color(0xFFE5484D),
      const Color(0xFFFFE9EA),
    ),
    NotificationKind.warning => (
      Icons.warning_amber_rounded,
      AppColors.primaryDark,
      AppColors.primaryLight,
    ),
    NotificationKind.info => (
      Icons.pets,
      AppColors.primary,
      AppColors.primaryLight,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color, tint) = _style;
    final top = MediaQuery.paddingOf(context).top + 10;
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
    return Positioned(
      top: top,
      left: 14,
      right: 14,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, -1.4),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(
                opacity: _controller,
                child: Dismissible(
                  key: const ValueKey('app-notification'),
                  direction: DismissDirection.up,
                  onDismissed: (_) {
                    _timer?.cancel();
                    widget.onClosed();
                  },
                  child: Semantics(
                    liveRegion: true,
                    container: true,
                    child: Material(
                      color: AppColors.surface,
                      elevation: 10,
                      shadowColor: const Color(0x337A4A1A),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: tint, width: 1.5),
                        ),
                        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: tint,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(icon, color: color, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.message,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.3,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Fermer la notification',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: AppColors.muted,
                              ),
                              onPressed: _close,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
