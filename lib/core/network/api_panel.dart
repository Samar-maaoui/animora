import 'package:flutter/material.dart';

import 'api_client.dart';

class ApiPanel<T> extends StatefulWidget {
  const ApiPanel({
    super.key,
    required this.title,
    required this.load,
    required this.builder,
    this.empty,
    this.action = 'Consulter le service externe',
  });
  final String title, action;
  final Future<ApiValue<T>> Function(bool refresh) load;
  final Widget Function(BuildContext, T) builder;
  final bool Function(T)? empty;
  @override
  State<ApiPanel<T>> createState() => _ApiPanelState<T>();
}

class _ApiPanelState<T> extends State<ApiPanel<T>> {
  bool busy = false;
  ApiValue<T>? value;
  String? error;
  Future<void> fetch() async {
    final refresh = value != null || error != null;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.load(refresh);
      if (mounted) setState(() => value = result);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiFailure
              ? e.message
              : 'Réponse externe indisponible. Réessayez.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(c).textTheme.titleMedium),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Chargement du service externe…'),
            ),
          if (error != null)
            Text(
              error!,
              key: const ValueKey('api-error'),
              semanticsLabel: error,
            ),
          if (value != null) ...[
            Text(value!.response.notice),
            Text('Reçu le ${value!.response.receivedAt.toLocal()}'),
            if (widget.empty?.call(value!.value) == true)
              const Text('Aucun résultat disponible.')
            else
              widget.builder(c, value!.value),
          ],
          OutlinedButton(
            onPressed: busy ? null : fetch,
            child: Text(
              error != null
                  ? 'Réessayer'
                  : value != null
                  ? 'Actualiser'
                  : widget.action,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<T?> searchableApiChoice<T>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required String Function(T) label,
}) => showDialog<T>(
  context: context,
  builder: (c) => _SearchChoices(title: title, items: items, label: label),
);

class _SearchChoices<T> extends StatefulWidget {
  const _SearchChoices({
    required this.title,
    required this.items,
    required this.label,
  });
  final String title;
  final List<T> items;
  final String Function(T) label;
  @override
  State<_SearchChoices<T>> createState() => _SearchChoicesState<T>();
}

class _SearchChoicesState<T> extends State<_SearchChoices<T>> {
  String search = '';
  @override
  Widget build(BuildContext c) {
    final matches = widget.items
        .where(
          (x) => widget.label(x).toLowerCase().contains(search.toLowerCase()),
        )
        .toList();
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        height: 360,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Rechercher'),
              onChanged: (v) => setState(() => search = v),
            ),
            Expanded(
              child: matches.isEmpty
                  ? const Text('Aucun résultat.')
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (c, i) => ListTile(
                        title: Text(widget.label(matches[i])),
                        onTap: () => Navigator.pop(c, matches[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}
