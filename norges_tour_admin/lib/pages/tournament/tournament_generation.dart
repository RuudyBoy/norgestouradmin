part of 'tournament_control_page.dart';

// Generering av puljer og sluttspill (NVBF-oppsett) og nullstilling av en klasse.
extension _Generation on _TournamentControlPageState {
  Map<String, dynamic> _buildGroupMatch({
    required String groupName,
    required String matchType,
    required DocumentSnapshot teamA,
    required DocumentSnapshot teamB,
  }) {
    final tA = teamA.data() as Map<String, dynamic>;
    final tB = teamB.data() as Map<String, dynamic>;
    return {
      'tournament_id': widget.tournamentId,
      'category_id': _selectedCategoryId,
      'stage': 'group',
      'group': groupName,
      'match_type': matchType,
      'status': 'scheduled',
      'court': 'TBD',
      'timestamp': FieldValue.serverTimestamp(),
      'home_score': 0,
      'away_score': 0,
      'home_sets': 0,
      'away_sets': 0,
      'current_set': 1,
      'past_sets': [],
      ..._slotFromTeam('team_a', teamA.id, tA, emptyName: 'Ukjent'),
      ..._slotFromTeam('team_b', teamB.id, tB, emptyName: 'Ukjent'),
    };
  }

  // ─── HOVEDNØKKEL: Generer hele turneringen på én gang ─────────────────────
  //
  // Trykk én gang → grupper + runde 2 + sluttspill opprettes med én gang.
  // Runde 2-kamper og sluttspillkamper starter som "pending" (lagene er
  // ukjente ennå). Etter hvert som kamper spilles og resultater registreres
  // kaller vi _resolvePendingMatches() som fyller inn lagnavnene automatisk.

  Future<void> _generateGroupStage() async {
    if (_selectedCategoryId == null || _selectedCategoryId == 'all') { _snack("Velg en spesifikk klasse."); return; }

    final snap = await _teamsQuery()
        .get();

    final teams = snap.docs;
    if (teams.length < 4) {
      _snack("Trenger minst 4 lag for å generere (har ${teams.length}).", isError: true);
      return;
    }

    final existing = await _matchesQuery()
        .get();
    if (existing.docs.isNotEmpty) {
      _snack("Turnering er allerede satt opp. Nullstill via ⋮-menyen.", isError: true);
      return;
    }

    // Serpentine seeding etter rankingpoeng
    final sorted = List<DocumentSnapshot>.from(teams)
      ..sort((a, b) {
        final ap = (a.data() as Map)['team_points'] as num? ?? 0;
        final bp = (b.data() as Map)['team_points'] as num? ?? 0;
        return bp.compareTo(ap);
      });

    final numGroups = (sorted.length / 4).ceil();
    if (numGroups < 2) {
      _snack("Trenger minst 2 grupper (8 lag).", isError: true);
      return;
    }

    final groupLists = List.generate(numGroups, (_) => <DocumentSnapshot>[]);
    for (int i = 0; i < sorted.length; i++) {
      final divIdx = i ~/ 16;
      final rankInDiv = i % 16;
      final groupsInThisDiv = (numGroups - divIdx * 4).clamp(1, 4);

      final row = rankInDiv ~/ groupsInThisDiv;
      final col = rankInDiv % groupsInThisDiv;
      final localGroupIdx = (row % 2 == 0) ? col : (groupsInThisDiv - 1 - col);

      final groupIdx = divIdx * 4 + localGroupIdx;
      groupLists[groupIdx].add(sorted[i]);
    }

    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final g = List.generate(numGroups, (i) => String.fromCharCode(65 + i));

    // Pre-alloker doc-IDer for alle gruppekamper
    // gruppeRefs[groupName] = { 'r1m1', 'r1m2', 'r2m3', 'r2m4' }
    final Map<String, Map<String, DocumentReference>> gr = {};
    for (final gn in g) {
      gr[gn] = {
        'r1m1': db.collection('matches').doc(),
        'r1m2': db.collection('matches').doc(),
        'r2m3': db.collection('matches').doc(),
        'r2m4': db.collection('matches').doc(),
      };
    }

    // ── Steg 1: Assign grupper og seeds ──────────────────────────────────────
    for (int gi = 0; gi < numGroups; gi++) {
      final gn = g[gi];
      for (final t in groupLists[gi]) {
        batch.update(t.reference, {
          'group': gn,
          'seed': sorted.indexOf(t) + 1,
          'group_placement': FieldValue.delete(),
        });
      }
    }

    // ── Steg 2: Gruppekamper ─────────────────────────────────────────────────
    for (int gi = 0; gi < numGroups; gi++) {
      final gn = g[gi];
      final gTeams = groupLists[gi];
      final refs = gr[gn]!;

      // Runde 1, Kamp 1: Seed 1 vs Seed 4
      if (gTeams.length >= 2) {
        final s4 = gTeams.length >= 4 ? gTeams[3] : gTeams.last;
        batch.set(refs['r1m1']!, _buildGroupMatch(
          groupName: gn, matchType: 'group_match_1',
          teamA: gTeams[0], teamB: s4,
        ));
      }

      // Runde 1, Kamp 2: Seed 2 vs Seed 3
      if (gTeams.length >= 3) {
        batch.set(refs['r1m2']!, _buildGroupMatch(
          groupName: gn, matchType: 'group_match_2',
          teamA: gTeams[1], teamB: gTeams[2],
        ));
      }

      // Runde 2, Kamp 3: Vinnere (pending til R1 er ferdig)
      batch.set(refs['r2m3']!, _pendingGroupMatch(
        groupName: gn, matchType: 'group_match_3',
        teamAFromMatchId: refs['r1m1']!.id, teamAFromSlot: 'winner',
        teamAPlaceholder: 'Vinner K.${gn}1',
        teamBFromMatchId: refs['r1m2']!.id, teamBFromSlot: 'winner',
        teamBPlaceholder: 'Vinner K.${gn}2',
      ));

      // Runde 2, Kamp 4: Tapere (pending til R1 er ferdig)
      batch.set(refs['r2m4']!, _pendingGroupMatch(
        groupName: gn, matchType: 'group_match_4',
        teamAFromMatchId: refs['r1m1']!.id, teamAFromSlot: 'loser',
        teamAPlaceholder: 'Taper K.${gn}1',
        teamBFromMatchId: refs['r1m2']!.id, teamBFromSlot: 'loser',
        teamBPlaceholder: 'Taper K.${gn}2',
      ));
    }

    // ── Steg 3: Sluttspillkamper (alle pending) ───────────────────────────────
    _addPlayoffsToBatch(batch: batch, g: g, db: db);

    await batch.commit();
    _snack("$numGroups grupper + sluttspillkryssninger generert!");

    // Auto-schedule all categories globally if tournament has start_time configured
    final tourDoc = await FirebaseFirestore.instance.collection('tournaments').doc(widget.tournamentId).get();
    final td = tourDoc.data() ?? {};
    final startTimeStr = td['start_time'] as String?;
    if (startTimeStr != null) {
      final parts = startTimeStr.split(':');
      if (parts.length == 2) {
        final startMinutes = (int.tryParse(parts[0]) ?? 9) * 60 + (int.tryParse(parts[1]) ?? 0);
        final duration = (td['match_duration_minutes'] as num?)?.toInt() ?? 60;
        final courts = (td['courts_count'] as num?)?.toInt() ?? 4;
        final startDate = td['start_date'] as String? ?? 'Kampdag';
        final endDate = td['end_date'] as String? ?? startDate;
        final interleave = (td['interleave_rounds'] as num?)?.toInt() ?? 0;
        await autoScheduleTournament(
          tournamentId: widget.tournamentId,
          startMinutes: startMinutes,
          matchDurationMinutes: duration,
          courtsCount: courts,
          startDate: startDate,
          endDate: endDate,
          interleaveRounds: interleave,
        );
        _snack("Kampskjema tildelt automatisk fra $startTimeStr.");
      }
    }
  }

  // Lager en pending gruppekamp med kilde-referanser
  Map<String, dynamic> _pendingGroupMatch({
    required String groupName,
    required String matchType,
    required String teamAFromMatchId,
    required String teamAFromSlot,
    required String teamAPlaceholder,
    required String teamBFromMatchId,
    required String teamBFromSlot,
    required String teamBPlaceholder,
  }) => {
    'tournament_id': widget.tournamentId,
    'category_id': _selectedCategoryId,
    'stage': 'group',
    'group': groupName,
    'match_type': matchType,
    'status': 'pending',
    'court': 'TBD',
    'timestamp': FieldValue.serverTimestamp(),
    'home_score': 0, 'away_score': 0,
    'home_sets': 0, 'away_sets': 0,
    'current_set': 1, 'past_sets': [],
    // Team A – placeholder
    'team_a_name': teamAPlaceholder,
    'team_a_id': 'placeholder',
    'team_a_from_match_id': teamAFromMatchId,
    'team_a_from_slot': teamAFromSlot,
    // Team B – placeholder
    'team_b_name': teamBPlaceholder,
    'team_b_id': 'placeholder',
    'team_b_from_match_id': teamBFromMatchId,
    'team_b_from_slot': teamBFromSlot,
  };

  // Legger til alle sluttspillkamper i batchen med placeholder-referanser
  void _addPlayoffsToBatch({
    required WriteBatch batch,
    required List<String> g,
    required FirebaseFirestore db,
  }) {
    final numGroups = g.length;

    // Hjelpere for placeholder-slots
    Map<String, dynamic> groupSlot(String prefix, String group, int place) {
      final labels = ['1. plass', '2. plass', '3. plass', '4. plass'];
      return {
        '${prefix}_name': '${labels[place - 1]} Pulje $group',
        '${prefix}_id': 'placeholder',
        '${prefix}_from_group': group,
        '${prefix}_from_place': place,
      };
    }

    Map<String, dynamic> winnerSlot(String prefix, String fromMatchId) => {
      '${prefix}_name': 'Vinner',
      '${prefix}_id': 'placeholder',
      '${prefix}_from_match_id': fromMatchId,
      '${prefix}_from_slot': 'winner',
    };

    Map<String, dynamic> loserSlot(String prefix, String fromMatchId, String label) => {
      '${prefix}_name': label,
      '${prefix}_id': 'placeholder',
      '${prefix}_from_match_id': fromMatchId,
      '${prefix}_from_slot': 'loser',
    };

    Map<String, dynamic> mkPlayoff({
      required String bracket, required String round, required int num,
      required Map<String, dynamic> aSlot, required Map<String, dynamic> bSlot,
      String? nextId, String? nextSlot,
    }) => {
      'tournament_id': widget.tournamentId,
      'category_id': _selectedCategoryId,
      'stage': 'playoff',
      'bracket': bracket, 'round': round, 'match_number': num,
      'status': 'pending', 'court': 'TBD',
      'timestamp': FieldValue.serverTimestamp(),
      'home_score': 0, 'away_score': 0,
      'home_sets': 0, 'away_sets': 0,
      'current_set': 1, 'past_sets': [],
      if (nextId != null) 'next_match_id': nextId,
      if (nextSlot != null) 'next_match_slot': nextSlot,
      ...aSlot, ...bSlot,
    };

    if (numGroups == 4) {
      // ─── 4-gruppe oppsett (16 lag) ─────────────────────────────────────────
      // A-bracket: QF → SF → Finale
      final r = <int, DocumentReference>{
        for (final n in [101,102,103,104,105,106,107,201,202,203,301,302,303])
          n: db.collection('matches').doc()
      };

      batch.set(r[101]!, mkPlayoff(bracket:'A', round:'qf', num:101,
          nextId: r[105]!.id, nextSlot:'a',
          aSlot: groupSlot('team_a', g[0], 1), bSlot: groupSlot('team_b', g[3], 2)));

      batch.set(r[102]!, mkPlayoff(bracket:'A', round:'qf', num:102,
          nextId: r[105]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[3], 1), bSlot: groupSlot('team_b', g[0], 2)));

      batch.set(r[103]!, mkPlayoff(bracket:'A', round:'qf', num:103,
          nextId: r[106]!.id, nextSlot:'a',
          aSlot: groupSlot('team_a', g[1], 1), bSlot: groupSlot('team_b', g[2], 2)));

      batch.set(r[104]!, mkPlayoff(bracket:'A', round:'qf', num:104,
          nextId: r[106]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[2], 1), bSlot: groupSlot('team_b', g[1], 2)));

      batch.set(r[105]!, mkPlayoff(bracket:'A', round:'sf', num:105,
          nextId: r[107]!.id, nextSlot:'a',
          aSlot: winnerSlot('team_a', r[101]!.id), bSlot: winnerSlot('team_b', r[102]!.id)));

      batch.set(r[106]!, mkPlayoff(bracket:'A', round:'sf', num:106,
          nextId: r[107]!.id, nextSlot:'b',
          aSlot: winnerSlot('team_a', r[103]!.id), bSlot: winnerSlot('team_b', r[104]!.id)));

      batch.set(r[107]!, mkPlayoff(bracket:'A', round:'final', num:107,
          aSlot: winnerSlot('team_a', r[105]!.id), bSlot: winnerSlot('team_b', r[106]!.id)));

      // B-bracket: SF → Finale (3. plass)
      batch.set(r[201]!, mkPlayoff(bracket:'B', round:'sf', num:201,
          nextId: r[203]!.id, nextSlot:'a',
          aSlot: groupSlot('team_a', g[0], 3), bSlot: groupSlot('team_b', g[3], 3)));

      batch.set(r[202]!, mkPlayoff(bracket:'B', round:'sf', num:202,
          nextId: r[203]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[1], 3), bSlot: groupSlot('team_b', g[2], 3)));

      batch.set(r[203]!, mkPlayoff(bracket:'B', round:'final', num:203,
          aSlot: winnerSlot('team_a', r[201]!.id), bSlot: winnerSlot('team_b', r[202]!.id)));

      // C-bracket: SF → Finale (siste plass)
      batch.set(r[301]!, mkPlayoff(bracket:'C', round:'sf', num:301,
          nextId: r[303]!.id, nextSlot:'a',
          aSlot: groupSlot('team_a', g[0], 4), bSlot: groupSlot('team_b', g[3], 4)));

      batch.set(r[302]!, mkPlayoff(bracket:'C', round:'sf', num:302,
          nextId: r[303]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[1], 4), bSlot: groupSlot('team_b', g[2], 4)));

      batch.set(r[303]!, mkPlayoff(bracket:'C', round:'final', num:303,
          aSlot: winnerSlot('team_a', r[301]!.id), bSlot: winnerSlot('team_b', r[302]!.id)));

    } else if (numGroups == 8) {
      // ─── 8-gruppe oppsett (32 lag) ────────────────────────────────────────
      // A-puljer: g[0]-g[3] (A,B,C,D – høyest seedede)
      // B-puljer: g[4]-g[7] (E,F,G,H – lavere seedede)
      //
      // NVBF Masters-format (korrekt):
      //   OMSPILL: 4.plass A-pulje vs 1.plass B-pulje
      //     → Vinner: A-bracket 1/16
      //     → Taper: B-bracket Kvartfinale (direkte, hopper over B 1/8)
      //
      //   A-BRACKET:
      //     1/16 (r16): 3.plass A-pulje (direkte) vs Omspill-vinner
      //     1/8  (r8) : 2.plass A-pulje (direkte) vs 1/16-vinner
      //     1/4  (qf) : 1.plass A-pulje (direkte) vs 1/8-vinner
      //     SF + Finale
      //
      //   B-BRACKET:
      //     1/8  (r8) : 2.plass B-pulje vs 3.plass B-pulje (kryssseeding)
      //     1/4  (qf) : Omspill-taper (direkte) vs B-1/8-vinner
      //     SF + Finale
      //
      //   C-BRACKET: 4.plass B-pulje (4 lag) → SF + Finale

      final r = <int, DocumentReference>{
        // Omspill: 1-4
        for (final n in [1, 2, 3, 4]) n: db.collection('matches').doc(),
        // A-bracket: r16(4) + r8(4) + qf(4) + sf(2) + final(1) = 15
        for (final n in [101,102,103,104, 105,106,107,108, 109,110,111,112, 113,114, 115])
          n: db.collection('matches').doc(),
        // B-bracket: r8(4) + qf(4) + sf(2) + final(1) = 11
        for (final n in [201,202,203,204, 205,206,207,208, 209,210, 211])
          n: db.collection('matches').doc(),
        // C-bracket: sf(2) + final(1) = 3
        for (final n in [301, 302, 303])
          n: db.collection('matches').doc(),
      };

      // ── OMSPILL (4 kamper) ──────────────────────────────────────────────────
      // Likeseeding (NVBF-standard): 4.plass indre pulje møter 1.plass korr. ytre pulje
      // A↔E, B↔F, C↔G, D↔H
      batch.set(r[1]!, mkPlayoff(bracket:'A', round:'omspill', num:1,
          nextId: r[101]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[0], 4),   // 4.plass Pulje A
          bSlot: groupSlot('team_b', g[4], 1)));  // 1.plass Pulje E

      batch.set(r[2]!, mkPlayoff(bracket:'A', round:'omspill', num:2,
          nextId: r[102]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[1], 4),   // 4.plass Pulje B
          bSlot: groupSlot('team_b', g[5], 1)));  // 1.plass Pulje F

      batch.set(r[3]!, mkPlayoff(bracket:'A', round:'omspill', num:3,
          nextId: r[103]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[2], 4),   // 4.plass Pulje C
          bSlot: groupSlot('team_b', g[6], 1)));  // 1.plass Pulje G

      batch.set(r[4]!, mkPlayoff(bracket:'A', round:'omspill', num:4,
          nextId: r[104]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[3], 4),   // 4.plass Pulje D
          bSlot: groupSlot('team_b', g[7], 1)));  // 1.plass Pulje H

      // ── A-bracket 1/16 (3.plass A-puljer vs omspill-vinnere) ──────────────
      // 3.plass fra pulje ikke involvert i tilsvarende omspill-kamp
      batch.set(r[101]!, mkPlayoff(bracket:'A', round:'r16', num:101,
          nextId: r[105]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[2], 3),       // 3.plass Pulje C (OM1=A,E → C ok)
          bSlot: winnerSlot('team_b', r[1]!.id)));   // Vinner omspill 1

      batch.set(r[102]!, mkPlayoff(bracket:'A', round:'r16', num:102,
          nextId: r[106]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[3], 3),       // 3.plass Pulje D (OM2=B,F → D ok)
          bSlot: winnerSlot('team_b', r[2]!.id)));   // Vinner omspill 2

      batch.set(r[103]!, mkPlayoff(bracket:'A', round:'r16', num:103,
          nextId: r[107]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[1], 3),       // 3.plass Pulje B (OM3=C,G → B ok)
          bSlot: winnerSlot('team_b', r[3]!.id)));   // Vinner omspill 3

      batch.set(r[104]!, mkPlayoff(bracket:'A', round:'r16', num:104,
          nextId: r[108]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[0], 3),       // 3.plass Pulje A (OM4=D,H → A ok)
          bSlot: winnerSlot('team_b', r[4]!.id)));   // Vinner omspill 4

      // ── A-bracket 1/8 (2.plass A-puljer vs 1/16-vinnere) ──────────────────
      batch.set(r[105]!, mkPlayoff(bracket:'A', round:'r8', num:105,
          nextId: r[109]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[3], 2),       // 2.plass Pulje D (kj. A,E,C → D ok)
          bSlot: winnerSlot('team_b', r[101]!.id)));

      batch.set(r[106]!, mkPlayoff(bracket:'A', round:'r8', num:106,
          nextId: r[110]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[2], 2),       // 2.plass Pulje C (kj. B,F,D → C ok)
          bSlot: winnerSlot('team_b', r[102]!.id)));

      batch.set(r[107]!, mkPlayoff(bracket:'A', round:'r8', num:107,
          nextId: r[111]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[0], 2),       // 2.plass Pulje A (kj. C,G,B → A ok)
          bSlot: winnerSlot('team_b', r[103]!.id)));

      batch.set(r[108]!, mkPlayoff(bracket:'A', round:'r8', num:108,
          nextId: r[112]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[1], 2),       // 2.plass Pulje B (kj. D,H,A → B ok)
          bSlot: winnerSlot('team_b', r[104]!.id)));

      // ── A-bracket Kvartfinale (1.plass A-puljer vs 1/8-vinnere) ─────────────
      batch.set(r[109]!, mkPlayoff(bracket:'A', round:'qf', num:109,
          nextId: r[113]!.id, nextSlot:'a',
          aSlot: groupSlot('team_a', g[0], 1),       // 1.plass Pulje A
          bSlot: winnerSlot('team_b', r[105]!.id)));

      batch.set(r[110]!, mkPlayoff(bracket:'A', round:'qf', num:110,
          nextId: r[113]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[3], 1),       // 1.plass Pulje D
          bSlot: winnerSlot('team_b', r[106]!.id)));

      batch.set(r[111]!, mkPlayoff(bracket:'A', round:'qf', num:111,
          nextId: r[114]!.id, nextSlot:'a',
          aSlot: groupSlot('team_a', g[1], 1),       // 1.plass Pulje B
          bSlot: winnerSlot('team_b', r[107]!.id)));

      batch.set(r[112]!, mkPlayoff(bracket:'A', round:'qf', num:112,
          nextId: r[114]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[2], 1),       // 1.plass Pulje C
          bSlot: winnerSlot('team_b', r[108]!.id)));

      // ── A-bracket SF + Finale ────────────────────────────────────────────────
      batch.set(r[113]!, mkPlayoff(bracket:'A', round:'sf', num:113,
          nextId: r[115]!.id, nextSlot:'a',
          aSlot: winnerSlot('team_a', r[109]!.id), bSlot: winnerSlot('team_b', r[110]!.id)));

      batch.set(r[114]!, mkPlayoff(bracket:'A', round:'sf', num:114,
          nextId: r[115]!.id, nextSlot:'b',
          aSlot: winnerSlot('team_a', r[111]!.id), bSlot: winnerSlot('team_b', r[112]!.id)));

      batch.set(r[115]!, mkPlayoff(bracket:'A', round:'final', num:115,
          aSlot: winnerSlot('team_a', r[113]!.id), bSlot: winnerSlot('team_b', r[114]!.id)));

      // ── B-bracket 1/8 (2.plass B-puljer vs 3.plass B-puljer, kryssseeding) ──
      // Kryssseeding slik at B-1/8-vinnere møter passende Omspill-taper i B-QF:
      //   201: 2.F vs 3.G  → B-qf-205 (mot Omspill-1-taper: A eller E)
      //   202: 2.E vs 3.H  → B-qf-206 (mot Omspill-2-taper: B eller F)
      //   203: 2.H vs 3.F  → B-qf-207 (mot Omspill-3-taper: C eller G)
      //   204: 2.G vs 3.E  → B-qf-208 (mot Omspill-4-taper: D eller H)
      batch.set(r[201]!, mkPlayoff(bracket:'B', round:'r8', num:201,
          nextId: r[205]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[5], 2),    // 2.plass Pulje F
          bSlot: groupSlot('team_b', g[6], 3)));   // 3.plass Pulje G

      batch.set(r[202]!, mkPlayoff(bracket:'B', round:'r8', num:202,
          nextId: r[206]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[4], 2),    // 2.plass Pulje E
          bSlot: groupSlot('team_b', g[7], 3)));   // 3.plass Pulje H

      batch.set(r[203]!, mkPlayoff(bracket:'B', round:'r8', num:203,
          nextId: r[207]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[7], 2),    // 2.plass Pulje H
          bSlot: groupSlot('team_b', g[5], 3)));   // 3.plass Pulje F

      batch.set(r[204]!, mkPlayoff(bracket:'B', round:'r8', num:204,
          nextId: r[208]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[6], 2),    // 2.plass Pulje G
          bSlot: groupSlot('team_b', g[4], 3)));   // 3.plass Pulje E

      // ── B-bracket Kvartfinale (Omspill-tapere direkte vs B-1/8-vinnere) ─────
      // Omspill-tapere hopper over B-1/8 og starter i B-QF
      batch.set(r[205]!, mkPlayoff(bracket:'B', round:'qf', num:205,
          nextId: r[209]!.id, nextSlot:'a',
          aSlot: loserSlot('team_a', r[1]!.id, 'Taper omspill 1'),   // Taper OM1 (A/E)
          bSlot: winnerSlot('team_b', r[201]!.id)));                   // B-1/8-201-vinner (F/G)

      batch.set(r[206]!, mkPlayoff(bracket:'B', round:'qf', num:206,
          nextId: r[209]!.id, nextSlot:'b',
          aSlot: loserSlot('team_a', r[2]!.id, 'Taper omspill 2'),   // Taper OM2 (B/F)
          bSlot: winnerSlot('team_b', r[202]!.id)));                   // B-1/8-202-vinner (E/H)

      batch.set(r[207]!, mkPlayoff(bracket:'B', round:'qf', num:207,
          nextId: r[210]!.id, nextSlot:'a',
          aSlot: loserSlot('team_a', r[3]!.id, 'Taper omspill 3'),   // Taper OM3 (C/G)
          bSlot: winnerSlot('team_b', r[203]!.id)));                   // B-1/8-203-vinner (H/F)

      batch.set(r[208]!, mkPlayoff(bracket:'B', round:'qf', num:208,
          nextId: r[210]!.id, nextSlot:'b',
          aSlot: loserSlot('team_a', r[4]!.id, 'Taper omspill 4'),   // Taper OM4 (D/H)
          bSlot: winnerSlot('team_b', r[204]!.id)));                   // B-1/8-204-vinner (G/E)

      // ── B-bracket SF + Finale ─────────────────────────────────────────────────
      batch.set(r[209]!, mkPlayoff(bracket:'B', round:'sf', num:209,
          nextId: r[211]!.id, nextSlot:'a',
          aSlot: winnerSlot('team_a', r[205]!.id), bSlot: winnerSlot('team_b', r[206]!.id)));

      batch.set(r[210]!, mkPlayoff(bracket:'B', round:'sf', num:210,
          nextId: r[211]!.id, nextSlot:'b',
          aSlot: winnerSlot('team_a', r[207]!.id), bSlot: winnerSlot('team_b', r[208]!.id)));

      batch.set(r[211]!, mkPlayoff(bracket:'B', round:'final', num:211,
          aSlot: winnerSlot('team_a', r[209]!.id), bSlot: winnerSlot('team_b', r[210]!.id)));

      // ── C-bracket (kun 4.plass B-puljer – 4 lag → SF + Finale) ─────────────
      batch.set(r[301]!, mkPlayoff(bracket:'C', round:'sf', num:301,
          nextId: r[303]!.id, nextSlot:'a',
          aSlot: groupSlot('team_a', g[4], 4),    // 4.plass Pulje E
          bSlot: groupSlot('team_b', g[7], 4)));   // 4.plass Pulje H

      batch.set(r[302]!, mkPlayoff(bracket:'C', round:'sf', num:302,
          nextId: r[303]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[5], 4),    // 4.plass Pulje F
          bSlot: groupSlot('team_b', g[6], 4)));   // 4.plass Pulje G

      batch.set(r[303]!, mkPlayoff(bracket:'C', round:'final', num:303,
          aSlot: winnerSlot('team_a', r[301]!.id), bSlot: winnerSlot('team_b', r[302]!.id)));
    }
    // For andre gruppeantall: sluttspill opprettes ikke automatisk
  }

  // ─── Reset ────────────────────────────────────────────────────────────────

  Future<void> _resetTournament() async {
    if (_selectedCategoryId == null || _selectedCategoryId == 'all') { _snack("Velg en spesifikk klasse."); return; }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Nullstill hele turneringen"),
        content: const Text(
            "Dette sletter ALLE kamper (gruppe + sluttspill) og tilbakestiller grupper og plasseringer.\n\nLagene beholdes.\n\nEr du sikker?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Avbryt")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminPrimary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Nullstill"),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // Slett ALLE kamper for denne klassen
    final matchSnap = await _matchesQuery()
        .get();

    final teamSnap = await _teamsQuery()
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final m in matchSnap.docs) {
      batch.delete(m.reference);
    }
    for (final t in teamSnap.docs) {
      batch.update(t.reference, {
        'group': FieldValue.delete(),
        'seed': FieldValue.delete(),
        'group_placement': FieldValue.delete(),
      });
    }
    await batch.commit();
    _snack("Turnering nullstilt. Lag beholdt.");
  }
}
