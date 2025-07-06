// lib/models/fixture_model.dart

import 'package:intl/intl.dart';

class Fixture {
  final String id;
  final String strEvent; // O nome do evento, ex: "Arsenal vs Chelsea"
  final DateTime date;
  final String time;

  Fixture({
    required this.id,
    required this.strEvent,
    required this.date,
    required this.time,
  });

  String get formattedDate {
    try {
      final dayFormat = DateFormat('dd MMM', 'pt_BR');
      final weekdayFormat = DateFormat('E', 'pt_BR');

      String day = dayFormat.format(date).toUpperCase();
      String weekday = weekdayFormat
          .format(date)
          .toUpperCase()
          .replaceAll('.', '');

      return '$day, $weekday';
    } catch (e) {
      return DateFormat('dd MMM, E').format(date).toUpperCase();
    }
  }

  factory Fixture.fromJson(Map<String, dynamic> json) {
    final dateStr = json['dateEvent'];
    final timeStr = json['strTime'] ?? '00:00:00';
    DateTime eventDateTime;

    if (dateStr != null) {
      try {
        eventDateTime = DateTime.parse('${dateStr}T$timeStr').toLocal();
      } catch (e) {
        eventDateTime = DateTime.now();
      }
    } else {
      eventDateTime = DateTime.now();
    }

    return Fixture(
      id: json['idEvent'] ?? '0',
      strEvent: json['strEvent'] ?? 'Evento Desconhecido',
      date: eventDateTime,
      time: timeStr,
    );
  }
}
