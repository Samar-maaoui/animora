import '../../../core/widgets/app_notification.dart';
import '../../../core/widgets/guarded_form.dart';
import '../../../core/widgets/navigation_app_bar.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/loading_widget.dart';
import '../repositories/animal_repository.dart';
import '../state/adoption_workflow_store.dart';

String workflowDate(DateTime? date) => date == null
    ? 'Non renseignée'
    : '${date.toLocal().day.toString().padLeft(2, '0')}/${date.toLocal().month.toString().padLeft(2, '0')}/${date.toLocal().year}';

class WorkflowPage extends StatelessWidget {
  const WorkflowPage({super.key, required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme
          .copyWith(primary: AppColors.adoption),
    ),
    child: Scaffold(
      appBar: NavigationAppBar(title: Text(title)),
      body: GuardedForm(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class WorkflowView<T> extends StatefulWidget {
  const WorkflowView({super.key, required this.load, required this.builder});
  final Future<T> Function(AdoptionWorkflowStore) load;
  final Widget Function(BuildContext, T) builder;
  @override
  State<WorkflowView<T>> createState() => _WorkflowViewState<T>();
}

class _WorkflowViewState<T> extends State<WorkflowView<T>> {
  Future<T>? _future;
  int? _revision;
  String? _userId;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = context.watch<AdoptionWorkflowStore>();
    final id = store.session.currentUser?.id;
    if (_future == null || _revision != store.revision || id != _userId) {
      _revision = store.revision;
      _userId = id;
      _future = widget.load(store);
    }
  }

  @override
  void didUpdateWidget(covariant WorkflowView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.key != oldWidget.key) {
      _future = widget.load(context.read<AdoptionWorkflowStore>());
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(32),
          child: LoadingWidget(),
        );
      }
      if (snapshot.hasError) {
        return Column(
          children: [
            Text(
              catalogErrorMessage(snapshot.error!),
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: () => setState(
                () => _future = widget.load(
                  context.read<AdoptionWorkflowStore>(),
                ),
              ),
              child: const Text('Réessayer'),
            ),
          ],
        );
      }
      return widget.builder(context, snapshot.data as T);
    },
  );
}

class WorkflowInfo extends StatelessWidget {
  const WorkflowInfo({super.key, required this.title, required this.values});
  final String title;
  final Map<String, String> values;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          for (final e in values.entries)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('${e.key} : ${e.value}'),
            ),
        ],
      ),
    ),
  );
}

class CompatibilitySummary extends StatelessWidget {
  const CompatibilitySummary({
    super.key,
    required this.score,
    this.explanations = const [],
  });
  final double score;
  final List<String> explanations;
  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.greenLight,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Compatibilité : ${score.toStringAsFixed(1)} %',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (score / 100).clamp(0, 1),
            color: AppColors.adoption,
          ),
          const SizedBox(height: 12),
          for (final text in explanations)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(text),
            ),
          if (explanations.isEmpty)
            const Text(
              'Score de démonstration. La décision appartient à un administrateur.',
            ),
        ],
      ),
    ),
  );
}

Future<bool> confirmWorkflow(
  BuildContext context,
  String title,
  String message, {
  String label = 'Confirmer',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(label),
          ),
        ],
      ),
    ) ??
    false;
Future<bool> runWorkflow(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await context.read<AdoptionWorkflowStore>().run(action);
    if (context.mounted && success != null) {
      AppNotification.success(context, success);
    }
    GuardedForm.markSaved();
    return true;
  } catch (error) {
    if (context.mounted) {
      AppNotification.error(context, catalogErrorMessage(error));
    }
    return false;
  }
}
