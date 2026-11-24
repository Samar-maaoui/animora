import 'package:flutter/material.dart';

import '../../adoption/screens/my_adoptions_screen.dart';

class AdminAdoptionsScreen extends StatelessWidget {
  const AdminAdoptionsScreen({super.key});
  @override
  Widget build(BuildContext context) => const AdoptionListScreen(admin: true);
}
