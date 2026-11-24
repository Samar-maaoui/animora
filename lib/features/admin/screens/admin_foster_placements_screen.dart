import 'package:flutter/material.dart';

import '../../adoption/screens/foster_family_screen.dart';

class AdminFosterPlacementsScreen extends StatelessWidget {
  const AdminFosterPlacementsScreen({super.key});
  @override
  Widget build(BuildContext context) => const FosterFamilyScreen(admin: true);
}
