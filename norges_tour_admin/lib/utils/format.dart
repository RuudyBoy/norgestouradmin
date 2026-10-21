import 'package:flutter/material.dart';

// Felles formatering av datoer, tider og resultater.
// Datoer lagres som tekst «dd.MM.yyyy» og tider som «HH:mm» i Firestore.

String _two(int n) => n.toString().padLeft(2, '0');

/// «dd.MM.yyyy» → [DateTime], eller null hvis teksten ikke er en gyldig dato.
DateTime? parseNoDate(String? s) {
  if (s == null) return null;
  final p = s.trim().split('.');
  if (p.length != 3) return null;
  final d = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final y = int.tryParse(p[2]);
  if (d == null || m == null || y == null) return null;
  return DateTime(y, m, d);
}

/// «dd.MM.yyyy» + «HH:mm» → [DateTime], eller null hvis noen av delene er ugyldige.
DateTime? parseNoDateTime(String date, String time) {
  final dp = date.split('.');
  final tp = time.split(':');
  if (dp.length != 3 || tp.length != 2) return null;
  try {
    return DateTime(int.parse(dp[2]), int.parse(dp[1]), int.parse(dp[0]),
        int.parse(tp[0]), int.parse(tp[1]));
  } catch (_) {
    return null;
  }
}

/// [DateTime] → «dd.MM.yyyy» (formatet som lagres i Firestore).
String fmtNoDate(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';

/// [TimeOfDay] → «HH:mm».
String fmtTimeOfDay(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';

/// «dd.MM.yyyy» → «dd.MM» (eller «–» hvis tom).
String shortDate(String? s) {
  if (s == null || s.isEmpty) return '–';
  final parts = s.split('.');
  if (parts.length >= 2) return '${parts[0]}.${parts[1]}';
  return s;
}

/// Datoperiode, f.eks. «22.–24.08.2026» eller «30.08.–01.09.2026».
/// Returnerer null hvis en av datoene ikke kan leses.
String? formatDateRange(String? startS, String? endS, {bool withYear = true}) {
  final s = parseNoDate(startS);
  final e = parseNoDate(endS);
  if (s == null || e == null) return null;
  final y = withYear ? '.${e.year}' : '';
  if (s == e) return '${_two(s.day)}.${_two(s.month)}$y';
  if (s.year == e.year && s.month == e.month) {
    return '${_two(s.day)}.–${_two(e.day)}.${_two(e.month)}$y';
  }
  return '${_two(s.day)}.${_two(s.month)}.–${_two(e.day)}.${_two(e.month)}$y';
}

/// Live-score for én side: fullførte sett + pågående poeng, f.eks. «21  14».
String liveScoreLine(Map<String, dynamic> d, bool home, {String separator = '  '}) {
  final past = (d['past_sets'] as List?) ?? const [];
  final parts = <String>[];
  for (final s in past) {
    if (s is Map) parts.add('${s[home ? 'home' : 'away']}');
  }
  parts.add('${d[home ? 'home_score' : 'away_score'] ?? 0}');
  return parts.join(separator);
}
