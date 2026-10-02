import 'package:flutter/material.dart';
import '../models/appointment.dart';

class AppointmentsProvider extends ChangeNotifier {
  final List<Appointment> appointments = [
    Appointment(
      id: 'a1',
      type: 'Visita Diabetologica',
      date: DateTime.now(),
      time: const TimeOfDay(hour: 10, minute: 30),
      location: 'Ospedale San Raffaele',
    ),
    Appointment(
      id: 'a2',
      type: 'Esami del Sangue',
      date: DateTime.now().add(const Duration(days: 3)),
      time: const TimeOfDay(hour: 8, minute: 0),
      location: 'Laboratorio Analisi',
    ),
  ];

  List<Appointment> get sorted {
    final list = List<Appointment>.from(appointments);
    list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return list;
  }

  Appointment? get next {
    final upcoming = sorted.where(
      (a) => a.dateTime.isAfter(DateTime.now().subtract(const Duration(hours: 1))),
    );
    return upcoming.isEmpty ? null : upcoming.first;
  }

  void addAppointment(Appointment appointment) {
    appointments.add(appointment);
    notifyListeners();
  }

  void removeAppointment(String id) {
    appointments.removeWhere((a) => a.id == id);
    notifyListeners();
  }
}
