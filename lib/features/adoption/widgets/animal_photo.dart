import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

class AnimalPhoto extends StatelessWidget {
  const AnimalPhoto({
    super.key,
    required this.source,
    required this.name,
    this.height = 180,
    this.fit = BoxFit.cover,
  });
  final String source, name;
  final double height;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
      height: height,
      color: AppColors.primaryLight,
      child: const Center(
        child: Icon(Icons.pets_rounded, size: 48, color: AppColors.primary),
      ),
    );
    try {
      if (source.startsWith('data:image/')) {
        return Image.memory(
          base64Decode(source.split(',').last),
          height: height,
          width: double.infinity,
          fit: fit,
          semanticLabel: 'Photo de $name',
          errorBuilder: (_, error, stack) => fallback(),
        );
      }
      if (source.startsWith('assets/')) {
        return Image.asset(
          source,
          height: height,
          width: double.infinity,
          fit: fit,
          semanticLabel: 'Photo de $name',
          errorBuilder: (_, error, stack) => fallback(),
        );
      }
    } catch (_) {
      return fallback();
    }
    return fallback();
  }
}
