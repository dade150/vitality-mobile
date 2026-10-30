import 'package:flutter/material.dart';

class Appointment {
  final String id;
  String type;
  DateTime date;
  TimeOfDay time;

  String? _doctorName;
  String get doctorName => _doctorName ?? '';
  set doctorName(String val) => _doctorName = val;

  String? _location;
  String get location => _location ?? '';
  set location(String val) => _location = val;

  String? _notes;
  String get notes => _notes ?? '';
  set notes(String val) => _notes = val;

  Appointment({
    required this.id,
    required this.type,
    required this.date,
    required this.time,
    String? doctorName,
    String? location,
    String? notes,
  })  : _doctorName = doctorName ?? '',
        _location = location ?? '',
        _notes = notes ?? '';

  DateTime get dateTime =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
