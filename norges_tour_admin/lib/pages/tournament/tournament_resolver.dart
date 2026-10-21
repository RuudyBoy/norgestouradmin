part of 'tournament_control_page.dart';

// Fyller inn lag i ventende kamper etter hvert som resultater kommer inn.
extension _Resolver on _TournamentControlPageState {
  // ─── Auto-resolve: Fyll inn riktige lag etter hvert som resultater kommer ─

  Future<void> _resolvePendingMatches({String? categoryId}) async {
    final catId = categoryId ?? _selectedCategoryId;
    if (catId == null) return;

    // Last alle kamper for denne turneringen + klassen
    final allSnap = await FirebaseFirestore.instance
        .collection('matches')
        .where('tournament_id', isEqualTo: widget.tournamentId)
        .where('category_id', isEqualTo: catId)
        .get();

    final allMatches = allSnap.docs;
    if (allMatches.isEmpty) return;

    final matchById = <String, Map<String, dynamic>>{
      for (final m in allMatches) m.id: m.data()
    };

    // ── Del 1: Beregn og oppdater lag-plasseringer fra ferdige R2-kamper ────
    final teamPlacements = <String, int>{}; // teamId → placement
    for (final m in allMatches) {
      final d = matchById[m.id]!;
      if (d['stage'] != 'group' || d['status'] != 'finished') continue;
      final mType = d['match_type'] as String? ?? '';
      if (mType != 'group_match_3' && mType != 'group_match_4') continue;

      final homeWins = (d['home_score'] as int? ?? 0) > (d['away_score'] as int? ?? 0);
      final winnerId = (homeWins ? d['team_a_id'] : d['team_b_id']) as String?;
      final loserId  = (homeWins ? d['team_b_id'] : d['team_a_id']) as String?;
      final winPlace  = mType == 'group_match_3' ? 1 : 3;
      final losePlace = mType == 'group_match_3' ? 2 : 4;

      if (winnerId != null && winnerId != 'placeholder') teamPlacements[winnerId] = winPlace;
      if (loserId  != null && loserId  != 'placeholder') teamPlacements[loserId]  = losePlace;
    }

    if (teamPlacements.isNotEmpty) {
      final tBatch = FirebaseFirestore.instance.batch();
      for (final e in teamPlacements.entries) {
        tBatch.update(
          FirebaseFirestore.instance.collection('teams').doc(e.key),
          {'group_placement': e.value},
        );
      }
      await tBatch.commit();
    }

    // Last oppdaterte lagdata for (gruppe, plass) → lagdata
    final teamsSnap = await FirebaseFirestore.instance
        .collection('teams')
        .where('tournament_id', isEqualTo: widget.tournamentId)
        .where('category_id', isEqualTo: catId)
        .get();

    final teamByGroupPlace = <String, Map<String, dynamic>>{};
    for (final t in teamsSnap.docs) {
      final d = t.data();
      final group = d['group'] as String?;
      final place = d['group_placement'] as int?;
      if (group != null && place != null) {
        teamByGroupPlace['${group}_$place'] = {'_id': t.id, ...d};
      }
    }

    // ── Del 2: Resolve pending kamper ────────────────────────────────────────
    final mBatch = FirebaseFirestore.instance.batch();
    int updates = 0;

    for (final matchDoc in allMatches) {
      final d = matchById[matchDoc.id]!;
      // Hopp over kamper som allerede er startet eller ferdig
      if (d['status'] == 'finished' || d['status'] == 'live' || d['status'] == 'scheduled') continue;

      final upd = <String, dynamic>{};

      // Resolver team_a og team_b
      for (final prefix in ['team_a', 'team_b']) {
        final currentId = d['${prefix}_id'] as String? ?? '';
        if (currentId != 'placeholder') continue; // Allerede resolved

        // Kilde: vinner/taper av en annen kamp
        final fromMatchId = d['${prefix}_from_match_id'] as String?;
        final fromSlot    = d['${prefix}_from_slot'] as String?;
        if (fromMatchId != null && fromSlot != null) {
          final src = matchById[fromMatchId];
          if (src != null && src['status'] == 'finished') {
            final homeWins = (src['home_score'] as int? ?? 0) > (src['away_score'] as int? ?? 0);
            final isWinner = fromSlot == 'winner';
            final useA = isWinner ? homeWins : !homeWins;
            upd.addAll(_slotFromMatch(prefix, src, useA ? 'team_a' : 'team_b'));
          }
          continue;
        }

        // Kilde: gruppeplass (f.eks. "1. plass Pulje A")
        final fromGroup = d['${prefix}_from_group'] as String?;
        final fromPlace = d['${prefix}_from_place'] as int?;
        if (fromGroup != null && fromPlace != null) {
          final team = teamByGroupPlace['${fromGroup}_$fromPlace'];
          if (team != null) {
            upd.addAll(_slotFromTeam(prefix, team['_id'] ?? '', team));
          }
        }
      }

      if (upd.isNotEmpty) {
        // Sjekk om begge lag er resolved nå → sett til 'scheduled'
        final aId = (upd['team_a_id'] ?? d['team_a_id']) as String? ?? '';
        final bId = (upd['team_b_id'] ?? d['team_b_id']) as String? ?? '';
        if (aId.isNotEmpty && aId != 'placeholder' && bId.isNotEmpty && bId != 'placeholder') {
          upd['status'] = 'scheduled';
        }
        mBatch.update(matchDoc.reference, upd);
        updates++;
      }
    }

    if (updates > 0) await mBatch.commit();
  }
}
