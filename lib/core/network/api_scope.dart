import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api_client.dart';

class ApiScope extends StatefulWidget {
  const ApiScope({super.key, required this.child, this.client});
  final Widget child;
  final ApiClient? client;
  @override
  State<ApiScope> createState() => _ApiScopeState();
}

class _ApiScopeState extends State<ApiScope> {
  late final client = widget.client ?? ApiClient();
  @override
  void dispose() {
    if (widget.client == null) client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Provider<ApiClient>.value(value: client, child: widget.child);
}

ApiClient? apiClient(BuildContext context) => context.read<ApiClient?>();
