import 'package:cloud_firestore/cloud_firestore.dart';

/// Kampprogram-innstillinger for én klasse.
///
/// Lagres på klassedokumentet (`categories/{id}`):
///  - `court_numbers`: hvilke baner klassen spiller på (tom = alle baner)
///  - `round_start_times`: starttid per runde, f.eks. {'1': '09:00', '2': '09:50',
///    'playoff': '12:00'}. Runder uten tid starter automatisk etter forrige.
class CategorySchedule {
  final List<int> courts;
  final Map<String, String> roundTimes;

  const CategorySchedule({this.courts = const [], this.roundTimes = const {}});

  /// Nøkler for alle rundene i hele turneringen (gruppespill + sluttspill).
  static const roundKeys = ['1', '2', '3', 'omspill', 'r16', 'r8', 'qf', 'sf', 'final'];
  static const roundLabels = {
    '1': 'Gruppe runde 1',
    '2': 'Gruppe runde 2',
    '3': 'Gruppe runde 3',
    'omspill': 'Omspill',
    'r16': '1/16-finale',
    'r8': '1/8-finale',
    'qf': 'Kvartfinale',
    'sf': 'Semifinale',
    'final': 'Finale',
  };

  /// Rundenøkkel som hører til `matchRoundOrder`.
  static String? keyForOrder(int order) {
    if (order >= 1 && order <= 3) return '$order';
    const m = {9: 'omspill', 10: 'r16', 11: 'r8', 12: 'qf', 13: 'sf', 14: 'final'};
    return m[order];
  }

  factory CategorySchedule.fromMap(Map? d) {
    if (d == null) return const CategorySchedule();
    final courts = (d['court_numbers'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        <int>[];
    final times = <String, String>{};
    final raw = d['round_start_times'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is String && v.isNotEmpty) times[k.toString()] = v;
      });
    }
    return CategorySchedule(courts: courts..sort(), roundTimes: times);
  }

  Map<String, dynamic> toMap() => {
        'court_numbers': courts,
        'round_start_times': roundTimes,
      };

  CategorySchedule copyWith({List<int>? courts, Map<String, String>? roundTimes}) =>
      CategorySchedule(
        courts: courts ?? this.courts,
        roundTimes: roundTimes ?? this.roundTimes,
      );
}

int? parseHm(String? s) {
  if (s == null) return null;
  final p = s.split(':');
  if (p.length != 2) return null;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

String fmtMinutes(int totalMinutes) {
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

int matchRoundOrder(Map d) {
  final stage = d['stage'] as String? ?? '';
  final matchType = d['match_type'] as String? ?? '';
  final round = d['round'] as String? ?? '';
  if (stage == 'group') {
    if (matchType == 'group_match_1' || matchType == 'group_match_2') return 1;
    if (matchType == 'group_match_3' || matchType == 'group_match_4') return 2;
    if (matchType == 'group_match_5') return 3;
    return 1;
  }
  if (stage == 'playoff') {
    if (round == 'omspill') return 9;
    if (round == 'r16') return 10;
    if (round == 'r8') return 11;
    if (round == 'qf') return 12;
    if (round == 'sf') return 13;
    if (round == 'final') return 14;
  }
  return 99;
}

/// Setter bane, tid og dato på alle kampene i én klasse.
/// Bruker klassens egne baner og starttider per runde når de er satt.
Future<void> autoScheduleCategory({
  required String tournamentId,
  required String categoryId,
  required int startMinutes,
  required int matchDurationMinutes,
  required int courtsCount,
  required String startDate,
  required String endDate,
  int breakBetweenRounds = 5,
}) async {
  final db = FirebaseFirestore.instance;

  final catDoc = await db.collection('categories').doc(categoryId).get();
  final sched = CategorySchedule.fromMap(catDoc.data());
  final courts = sched.courts.isNotEmpty
      ? sched.courts
      : List<int>.generate(courtsCount, (i) => i + 1);

  final snap = await db
      .collection('matches')
      .where('tournament_id', isEqualTo: tournamentId)
      .where('category_id', isEqualTo: categoryId)
      .get();
  if (snap.docs.isEmpty) return;

  final docs = List<DocumentSnapshot>.from(snap.docs)
    ..sort((a, b) {
      final ao = matchRoundOrder(a.data() as Map);
      final bo = matchRoundOrder(b.data() as Map);
      if (ao != bo) return ao.compareTo(bo);
      final ag = (a.data() as Map)['group'] as String? ?? '';
      final bg = (b.data() as Map)['group'] as String? ?? '';
      return ag.compareTo(bg);
    });

  final Map<int, List<DocumentSnapshot>> byRound = {};
  for (final doc in docs) {
    byRound.putIfAbsent(matchRoundOrder(doc.data() as Map), () => []).add(doc);
  }

  final batch = db.batch();
  int currentMinutesDay1 = startMinutes;
  int currentMinutesDay2 = startMinutes;

  for (final roundOrder in (byRound.keys.toList()..sort())) {
    final isDay2 = (startDate != endDate) && (roundOrder >= 10);
    final matchDate = isDay2 ? endDate : startDate;
    int currentMinutes = isDay2 ? currentMinutesDay2 : currentMinutesDay1;

    // Egendefinert starttid for akkurat denne runden
    final rk = CategorySchedule.keyForOrder(roundOrder);
    final override = rk == null ? null : parseHm(sched.roundTimes[rk]);
    if (override != null) currentMinutes = override;

    final roundMatches = byRound[roundOrder]!;
    final numSlots = (roundMatches.length / courts.length).ceil();
    for (int slot = 0; slot < numSlots; slot++) {
      final slotMinutes = currentMinutes + slot * matchDurationMinutes;
      for (int c = 0; c < courts.length; c++) {
        final idx = slot * courts.length + c;
        if (idx >= roundMatches.length) break;
        batch.update(roundMatches[idx].reference, {
          'court': 'Bane ${courts[c]}',
          'match_time': fmtMinutes(slotMinutes),
          'match_date': matchDate,
          'scheduled_minutes': slotMinutes,
        });
      }
    }
    final next = currentMinutes + numSlots * matchDurationMinutes + breakBetweenRounds;
    if (isDay2) {
      currentMinutesDay2 = next;
    } else {
      currentMinutesDay1 = next;
    }
  }

  await batch.commit();
}
