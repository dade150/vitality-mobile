import 'package:flutter/material.dart';
import '../models/medical_report.dart';

class ReportsProvider extends ChangeNotifier {
  final List<MedicalReport> reports = [
    MedicalReport(
      id: 'r1',
      title: 'Referto Cardiologico',
      date: DateTime.now(),
      extractedParams: const {
        'HbA1c': '6.8%',
        'eGFR': '92 mL/min',
        'UACR': '15 mg/g',
        'Pressione': '120/80',
      },
    ),
    MedicalReport(
      id: 'r2',
      title: 'Ricetta Medica',
      date: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  void addReport(MedicalReport report) {
    reports.insert(0, report);
    notifyListeners();
  }
}
