import 'package:flutter/material.dart';

class Appointment {
  final String id;
  String type;
  DateTime date;
  TimeOfDay time;
  String location;
  String notes;

  Appointment({
    required this.id,
    required this.type,
    required this.date,
    required this.time,
    required this.location,
    this.notes = '',
  });

  DateTime get dateTime =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
