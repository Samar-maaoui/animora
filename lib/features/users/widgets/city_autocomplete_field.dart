import 'dart:async';

import 'package:flutter/material.dart';

import '../services/city_search_api.dart';

/// « Ville » text field with Photon suggestions while typing
/// (« Sou… » → Sousse). Free text stays allowed when offline.
class CityAutocompleteField extends StatefulWidget {
  const CityAutocompleteField({
    super.key,
    required this.controller,
    this.label = 'Ville',
    this.validator,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.onChanged,
    this.api,
  });
  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  /// Injectable for tests.
  final CitySearchApi? api;

  @override
  State<CityAutocompleteField> createState() => _CityAutocompleteFieldState();
}

class _CityAutocompleteFieldState extends State<CityAutocompleteField> {
  static final _sharedApi = CitySearchApi();
  final _focus = FocusNode();
  String _latest = '';
  String? _selected;

  CitySearchApi get _api => widget.api ?? _sharedApi;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<Iterable<CitySuggestion>> _options(TextEditingValue value) async {
    final query = value.text.trim();
    _latest = query;
    if (query.length < 2 || query == _selected) return const [];
    // Debounce: only the last keystroke within 350 ms hits the network.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (query != _latest || !mounted) return const [];
    return _api.search(query);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: RawAutocomplete<CitySuggestion>(
      textEditingController: widget.controller,
      focusNode: _focus,
      displayStringForOption: (s) => s.name,
      optionsBuilder: _options,
      onSelected: (s) {
        _selected = s.name;
        widget.onChanged?.call(s.name);
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
          TextFormField(
            key: const ValueKey('city'),
            controller: controller,
            focusNode: focusNode,
            enabled: widget.enabled,
            validator: widget.validator,
            textCapitalization: TextCapitalization.words,
            onChanged: (v) {
              _selected = null;
              widget.onChanged?.call(v);
            },
            onFieldSubmitted: (_) => onSubmitted(),
            decoration: InputDecoration(
              labelText: widget.label,
              prefixIcon: widget.prefixIcon == null
                  ? null
                  : Icon(widget.prefixIcon),
              suffixIcon: widget.suffixIcon,
              errorText: widget.errorText,
              errorMaxLines: 3,
            ),
          ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260, maxWidth: 440),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final s in options)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_city_outlined),
                    title: Text(s.name),
                    subtitle: s.details.isEmpty ? null : Text(s.details),
                    onTap: () => onSelected(s),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    'Suggestions © OpenStreetMap (Photon)',
                    style: TextStyle(fontSize: 10, color: Colors.black45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
