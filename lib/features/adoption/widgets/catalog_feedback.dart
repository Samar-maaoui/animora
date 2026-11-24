import 'package:flutter/material.dart';

import '../../../core/widgets/loading_widget.dart';
import '../state/adoption_store.dart';

class CatalogFeedback extends StatelessWidget {
  const CatalogFeedback({super.key, required this.store});
  final AdoptionStore store;
  @override
  Widget build(BuildContext context) => store.loading
      ? const Padding(padding: EdgeInsets.all(32), child: LoadingWidget())
      : Column(
          children: [
            Text(
              store.error ?? 'Le catalogue n’est pas disponible.',
              textAlign: TextAlign.center,
            ),
            TextButton(onPressed: store.load, child: const Text('Réessayer')),
          ],
        );
}
