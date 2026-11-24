import 'package:flutter/material.dart';

import '../widgets/services_widgets.dart';
import '../../veterinary/screens/veterinary_screens.dart' show AppointmentCard;
import '../../pet_sitting/screens/pet_sitting_screens.dart'
    show PetSittingRequestCard;

class AdminServicesScreen extends StatelessWidget {
  const AdminServicesScreen({super.key});
  @override
  Widget build(BuildContext c) {
    if (serviceProfile(c) != UserProfile.admin) {
      return const ServicePage(
        title: 'Accès refusé',
        children: [Text('Supervision réservée à l’administration.')],
      );
    }
    return ServiceView(
      load: (s) async => (
        await s.appointments.getAppointments(),
        await s.petSitting.getPetSittingRequests(),
      ),
      builder: (c, data) => ServicePage(
        title: 'Supervision des rendez-vous et gardes',
        children: [
          const Text(
            'Consultation administrative des données nécessaires au suivi. Les décisions professionnelles restent réservées aux participants habilités.',
          ),
          serviceLink(c, 'Carnets de santé', '/health'),
          const Text(
            'Rendez-vous vétérinaires',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          if (data.$1.isEmpty) const Text('Aucun rendez-vous.'),
          ...data.$1.map((a) => AppointmentCard(a, readOnly: true)),
          const Text(
            'Demandes de garde',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          if (data.$2.isEmpty) const Text('Aucune garde.'),
          ...data.$2.map((r) => PetSittingRequestCard(r, readOnly: true)),
        ],
      ),
    );
  }
}
