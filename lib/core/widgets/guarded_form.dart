import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GuardedForm extends StatefulWidget {
  const GuardedForm({
    super.key,
    this.formKey,
    required this.child,
    this.autovalidateMode,
    this.onChanged,
  });
  final GlobalKey<FormState>? formKey;
  final Widget child;
  final AutovalidateMode? autovalidateMode;
  final VoidCallback? onChanged;
  static Future<bool>? _confirmation;
  static bool _active(_GuardedFormState s) =>
      s.mounted &&
      TickerMode.valuesOf(s.context).enabled &&
      (ModalRoute.of(s.context)?.isCurrent ?? true);
  static final _drafts = <_GuardedFormState>{};
  static void markDirty() {
    for (final s in _drafts) {
      if (_active(s)) s.dirty = true;
    }
  }

  static ValueChanged<T>? track<T>(ValueChanged<T>? callback) =>
      callback == null
      ? null
      : (value) {
          markDirty();
          callback(value);
        };
  static void markSaved() {
    for (final s in _drafts) {
      if (_active(s)) {
        s.dirty = false;
        s.ignoreChanges = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          s.ignoreChanges = false;
        });
      }
    }
  }

  static void savedGo(BuildContext context, String location) {
    markSaved();
    context.go(location);
  }

  static FutureOr<bool> confirmExit(BuildContext context) {
    final active = _drafts
        .where((s) => _active(s) && s.dirty && !s.ignoreChanges)
        .toList();
    if (active.isEmpty) return true;
    return _confirmation ??= _confirm(
      context,
      active,
    ).whenComplete(() => _confirmation = null);
  }

  static Future<bool> _confirm(
    BuildContext context,
    List<_GuardedFormState> active,
  ) async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Quitter le formulaire ?'),
        content: const Text(
          'Les modifications non enregistrées seront abandonnées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (exit == true) {
      for (final draft in active) {
        draft.dirty = false;
      }
    }
    return exit == true;
  }

  @override
  State<GuardedForm> createState() => _GuardedFormState();
}

class _GuardedFormState extends State<GuardedForm> {
  bool dirty = false, ignoreChanges = false;
  @override
  void initState() {
    super.initState();
    GuardedForm._drafts.add(this);
  }

  @override
  void dispose() {
    GuardedForm._drafts.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: widget.formKey,
    autovalidateMode: widget.autovalidateMode,
    onChanged: () {
      if (ignoreChanges) return;
      dirty = true;
      var parent = context.findAncestorStateOfType<_GuardedFormState>();
      while (parent != null) {
        parent.dirty = true;
        parent = parent.context.findAncestorStateOfType<_GuardedFormState>();
      }
      widget.onChanged?.call();
    },
    child: widget.child,
  );
}
