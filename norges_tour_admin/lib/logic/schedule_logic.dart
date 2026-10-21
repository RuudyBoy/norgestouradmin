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

// ─── Intern hjelpeklasse ────────────────────────────────────────────────────
class _ScheduleTask {
  final String catId;
  final int roundOrder;
  _ScheduleTask(this.catId, this.roundOrder);
}

/// Planlegger HELE turneringen globalt (alle klasser samtidig).
///
/// Støtter:
///  - Separate baner per klasse (ingen overlapp)
///  - Rullering mellom klasser (interleaveRounds = 0 / 1 / 2)
///  - Egendefinerte starttider per runde per klasse
///
/// [interleaveRounds]:
///   0 = ingen rullering (klasse A alle runder, deretter klasse B alle runder)
///   1 = annenhver runde  (A runde 1, B runde 1, A runde 2, B runde 2 …)
///   2 = to-og-to         (A runde 1+2, B runde 1+2, A runde 3, …)
Future<void> autoScheduleTournament({
  required String tournamentId,
  required int startMinutes,
  required int matchDurationMinutes,
  required int courtsCount,
  required String startDate,
  required String endDate,
  int breakBetweenRounds = 5,
  int interleaveRounds = 0,
}) async {
  final db = FirebaseFirestore.instance;

  // --- Hent klasser og kampene ---
  final catSnap = await db
      .collection('categories')
      .where('tournament_id', isEqualTo: tournamentId)
      .get();
  final catSchedules = <String, CategorySchedule>{};
  for (final doc in catSnap.docs) {
    catSchedules[doc.id] = CategorySchedule.fromMap(doc.data());
  }

  final snap = await db
      .collection('matches')
      .where('tournament_id', isEqualTo: tournamentId)
      .get();
  if (snap.docs.isEmpty) return;

  // --- Organiser kamper per klasse og runde ---
  final matchesByCategory = <String, List<DocumentSnapshot>>{};
  for (final doc in snap.docs) {
    final catId = (doc.data() as Map)['category_id'] as String;
    matchesByCategory.putIfAbsent(catId, () => []).add(doc);
  }

  final byRoundByCat = <String, Map<int, List<DocumentSnapshot>>>{};
  final allRoundOrders = <int>{};

  for (final catId in matchesByCategory.keys) {
    final docs = matchesByCategory[catId]!..sort((a, b) {
      final ao = matchRoundOrder(a.data() as Map);
      final bo = matchRoundOrder(b.data() as Map);
      if (ao != bo) return ao.compareTo(bo);
      final ag = (a.data() as Map)['group'] as String? ?? '';
      final bg = (b.data() as Map)['group'] as String? ?? '';
      return ag.compareTo(bg);
    });

    final byRound = <int, List<DocumentSnapshot>>{};
    for (final doc in docs) {
      final order = matchRoundOrder(doc.data() as Map);
      byRound.putIfAbsent(order, () => []).add(doc);
      allRoundOrders.add(order);
    }
    byRoundByCat[catId] = byRound;
  }

  final sortedRounds = allRoundOrders.toList()..sort();
  // Stabil rekkefølge på klasser (gjerne sortert på navn)
  final catIds = matchesByCategory.keys.toList()..sort();

  // --- Bygg opp liste av oppgaver i riktig rulleringsrekkefølge ---
  final tasks = <_ScheduleTask>[];

  if (interleaveRounds == 0) {
    // Én klasse hele veien, deretter neste
    for (final catId in catIds) {
      for (final r in sortedRounds) {
        if (byRoundByCat[catId]?.containsKey(r) == true) {
          tasks.add(_ScheduleTask(catId, r));
        }
      }
    }
  } else {
    // Rullering: klasse A [interleaveRounds] runder, klasse B [interleaveRounds] runder …
    int rIdx = 0;
    while (rIdx < sortedRounds.length) {
      for (final catId in catIds) {
        for (int i = 0; i < interleaveRounds; i++) {
          final idx = rIdx + i;
          if (idx < sortedRounds.length) {
            final r = sortedRounds[idx];
            if (byRoundByCat[catId]?.containsKey(r) == true) {
              tasks.add(_ScheduleTask(catId, r));
            }
          }
        }
      }
      rIdx += interleaveRounds;
    }
  }

  // --- Per-bane-klokke (sikrer at ingen bane dobbelbooker) ---
  // courtTimesDay1/2[n] = tidligste ledige minutt på bane n
  final courtTimesDay1 = <int, int>{};
  final courtTimesDay2 = <int, int>{};
  for (int i = 1; i <= courtsCount; i++) {
    courtTimesDay1[i] = startMinutes;
    courtTimesDay2[i] = startMinutes;
  }

  final batch = db.batch();

  for (final task in tasks) {
    final catId = task.catId;
    final roundOrder = task.roundOrder;
    final roundMatches = byRoundByCat[catId]![roundOrder]!;

    final sched = catSchedules[catId] ?? const CategorySchedule();
    final courts = sched.courts.isNotEmpty
        ? sched.courts
        : List<int>.generate(courtsCount, (i) => i + 1);

    final isDay2 = (startDate != endDate) && (roundOrder >= 10);
    final matchDate = isDay2 ? endDate : startDate;
    final courtTimes = isDay2 ? courtTimesDay2 : courtTimesDay1;

    // Egendefinert starttid for runden – skyv alle klassens baner frem til denne
    final rk = CategorySchedule.keyForOrder(roundOrder);
    final override = rk == null ? null : parseHm(sched.roundTimes[rk]);
    if (override != null) {
      for (final c in courts) {
        if ((courtTimes[c] ?? startMinutes) < override) {
          courtTimes[c] = override;
        }
      }
    }

    // Tidligste ledige minutt for ALLE klassens baner (ingen bane kan starte
    // før den er ferdig med forrige kamp)
    int baseMinutes = courts.fold<int>(
      0,
      (prev, c) => (courtTimes[c] ?? startMinutes) > prev ? (courtTimes[c] ?? startMinutes) : prev,
    );

    final numSlots = (roundMatches.length / courts.length).ceil();
    for (int slot = 0; slot < numSlots; slot++) {
      final slotMinutes = baseMinutes + slot * matchDurationMinutes;
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

    // Oppdater bane-klokken etter denne rundeblokkens kamper
    final endMinutes = baseMinutes + numSlots * matchDurationMinutes + breakBetweenRounds;
    for (final c in courts) {
      courtTimes[c] = endMinutes;
    }
  }

  await batch.commit();
}
