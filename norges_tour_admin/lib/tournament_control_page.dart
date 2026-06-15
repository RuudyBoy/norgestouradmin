import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'match_control_page.dart';
import 'simulator_logic.dart';

class TournamentControlPage extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;

  const TournamentControlPage({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  State<TournamentControlPage> createState() => _TournamentControlPageState();
}

class _TournamentControlPageState extends State<TournamentControlPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red[700] : null,
    ));
  }

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
      'team_a_name': tA['team_name'] ?? 'Ukjent',
      'team_a_id': teamA.id,
      'team_a_p1_name': tA['player1_name'] ?? '',
      'team_a_p1_id': tA['player1_id'] ?? '',
      'team_a_p2_name': tA['player2_name'] ?? '',
      'team_a_p2_id': tA['player2_id'] ?? '',
      'team_b_name': tB['team_name'] ?? 'Ukjent',
      'team_b_id': teamB.id,
      'team_b_p1_name': tB['player1_name'] ?? '',
      'team_b_p1_id': tB['player1_id'] ?? '',
      'team_b_p2_name': tB['player2_name'] ?? '',
      'team_b_p2_id': tB['player2_id'] ?? '',
    };
  }

  // ─── Team dialogs ──────────────────────────────────────────────────────────

  void _showAddTeamDialog() {
    if (_selectedCategoryId == null) { _snack("Velg en klasse først."); return; }

    String? p1Id, p2Id, p1Name, p2Name, p1Short, p2Short;

    String shortName(String first, String last) =>
        "${first.isNotEmpty ? first[0].toUpperCase() : ''}.$last";

    final playersStream =
        FirebaseFirestore.instance.collection('players').orderBy('first_name').snapshots();

    showDialog(
      context: context,
      builder: (ctx) => StreamBuilder<QuerySnapshot>(
        stream: playersStream,
        builder: (ctx, snap) {
          if (!snap.hasData) return const AlertDialog(content: SizedBox(height: 60, child: Center(child: CircularProgressIndicator())));
          final docs = snap.data!.docs;
          if (docs.isEmpty) return AlertDialog(content: const Text("Ingen spillere i databasen."), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Lukk"))]);

          final items = docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return DropdownMenuItem<String>(
              value: d.id,
              child: Text("${data['first_name']} ${data['last_name']}"),
            );
          }).toList();

          return StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
            title: const Text("Registrer nytt lag"),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Spiller 1", border: OutlineInputBorder()),
                  items: items,
                  initialValue: p1Id,
                  onChanged: (v) {
                    if (v == null) return;
                    final d = docs.firstWhere((d) => d.id == v).data() as Map<String, dynamic>;
                    setDlg(() {
                      p1Id = v;
                      p1Name = "${d['first_name']} ${d['last_name']}";
                      p1Short = shortName(d['first_name'] ?? '', d['last_name'] ?? '');
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Spiller 2", border: OutlineInputBorder()),
                  items: items,
                  initialValue: p2Id,
                  onChanged: (v) {
                    if (v == null) return;
                    final d = docs.firstWhere((d) => d.id == v).data() as Map<String, dynamic>;
                    setDlg(() {
                      p2Id = v;
                      p2Name = "${d['first_name']} ${d['last_name']}";
                      p2Short = shortName(d['first_name'] ?? '', d['last_name'] ?? '');
                    });
                  },
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Avbryt")),
              ElevatedButton(
                onPressed: () {
                  if (p1Id == null || p2Id == null) { _snack("Velg begge spillere!"); return; }
                  if (p1Id == p2Id) { _snack("Velg to forskjellige spillere!"); return; }
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);

                  final p1Data = docs.firstWhere((d) => d.id == p1Id).data() as Map<String, dynamic>;
                  final p2Data = docs.firstWhere((d) => d.id == p2Id).data() as Map<String, dynamic>;
                  final pts1 = (p1Data['ranking_points'] as num?)?.toInt() ?? 0;
                  final pts2 = (p2Data['ranking_points'] as num?)?.toInt() ?? 0;

                  FirebaseFirestore.instance.collection('teams').add({
                    'tournament_id': widget.tournamentId,
                    'category_id': _selectedCategoryId,
                    'team_name': "$p1Short/$p2Short",
                    'player1_id': p1Id,
                    'player1_name': p1Name,
                    'player2_id': p2Id,
                    'player2_name': p2Name,
                    'team_points': pts1 + pts2,
                    'created_at': FieldValue.serverTimestamp(),
                  }).then((_) => messenger.showSnackBar(const SnackBar(content: Text("Lag lagt til!"))));
                },
                child: const Text("Lagre"),
              ),
            ],
          ));
        },
      ),
    );
  }

  Future<void> _autoGenerateTeams() async {
    if (_selectedCategoryId == null) { _snack("Velg en klasse først."); return; }
    final snap = await FirebaseFirestore.instance.collection('players').get();
    final players = snap.docs.toList()..shuffle();
    if (players.length < 32) {
      _snack("Trenger minst 32 spillere i databasen (har ${players.length}).", isError: true);
      return;
    }
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < 16; i++) {
      final p1 = players[i * 2].data();
      final p2 = players[i * 2 + 1].data();
      final pts1 = (p1['ranking_points'] as num?)?.toInt() ?? 0;
      final pts2 = (p2['ranking_points'] as num?)?.toInt() ?? 0;
      final s1 = p1['last_name'] ?? p1['first_name'] ?? 'X';
      final s2 = p2['last_name'] ?? p2['first_name'] ?? 'X';
      batch.set(FirebaseFirestore.instance.collection('teams').doc(), {
        'tournament_id': widget.tournamentId,
        'category_id': _selectedCategoryId,
        'team_name': "$s1/$s2",
        'player1_id': players[i * 2].id,
        'player1_name': "${p1['first_name']} ${p1['last_name']}".trim(),
        'player2_id': players[i * 2 + 1].id,
        'player2_name': "${p2['first_name']} ${p2['last_name']}".trim(),
        'team_points': pts1 + pts2,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    _snack("16 lag generert!");
  }

  void _confirmDeleteTeam(String teamId, String name) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text("Slett $name?"),
      content: const Text("Er du sikker?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Avbryt")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () {
            FirebaseFirestore.instance.collection('teams').doc(teamId).delete();
            Navigator.pop(ctx);
          },
          child: const Text("Slett"),
        ),
      ],
    ));
  }

  void _showQrDialog(String matchId, String a, String b) {
    final url = "https://spikedunk.web.app/?matchId=$matchId";
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Dommer QR-kode"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text("$a vs $b", textAlign: TextAlign.center),
        const SizedBox(height: 16),
        SizedBox(height: 200, width: 200, child: QrImageView(data: url, version: QrVersions.auto, size: 200)),
        const SizedBox(height: 12),
        SelectableText(url, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Lukk"))],
    ));
  }

  // ─── Group stage logic ─────────────────────────────────────────────────────

  Future<void> _generateGroupStage() async {
    if (_selectedCategoryId == null) { _snack("Velg en klasse først."); return; }

    final snap = await FirebaseFirestore.instance
        .collection('teams')
        .where('tournament_id', isEqualTo: widget.tournamentId)
        .where('category_id', isEqualTo: _selectedCategoryId)
        .get();

    final teams = snap.docs;
    if (teams.length < 4) {
      _snack("Trenger minst 4 lag for å generere grupper (har ${teams.length}).", isError: true);
      return;
    }

    // Check if groups already generated
    final existingMatches = await FirebaseFirestore.instance
        .collection('matches')
        .where('tournament_id', isEqualTo: widget.tournamentId)
        .where('category_id', isEqualTo: _selectedCategoryId)
        .where('stage', isEqualTo: 'group')
        .get();
    if (existingMatches.docs.isNotEmpty) {
      _snack("Grupper er allerede generert. Slett eksisterende kamper først.", isError: true);
      return;
    }

    // Sort by team_points descending → Seed 1 = høyest poeng
    final sorted = List<DocumentSnapshot>.from(teams)
      ..sort((a, b) {
        final ap = (a.data() as Map)['team_points'] as num? ?? 0;
        final bp = (b.data() as Map)['team_points'] as num? ?? 0;
        return bp.compareTo(ap);
      });

    // Dynamic number of groups: prefer groups of 4
    final numGroups = (sorted.length / 4).ceil();

    // Serpentine seeding across N groups
    final groupLists = List.generate(numGroups, (_) => <DocumentSnapshot>[]);
    for (int i = 0; i < sorted.length; i++) {
      final row = i ~/ numGroups;
      final col = i % numGroups;
      final groupIdx = (row % 2 == 0) ? col : (numGroups - 1 - col);
      groupLists[groupIdx].add(sorted[i]);
    }

    final batch = FirebaseFirestore.instance.batch();

    for (int g = 0; g < numGroups; g++) {
      final groupName = String.fromCharCode(65 + g); // A, B, C, ...
      final gTeams = groupLists[g];

      // Assign global seed and group to each team
      for (int t = 0; t < gTeams.length; t++) {
        final globalSeed = sorted.indexOf(gTeams[t]) + 1;
        batch.update(gTeams[t].reference, {
          'group': groupName,
          'seed': globalSeed,
          'group_placement': FieldValue.delete(),
        });
      }

      // Modified Pool Play — Kamp 1: Seed 1 vs Seed 4 (høyest vs lavest)
      if (gTeams.length >= 2) {
        final m1Ref = FirebaseFirestore.instance.collection('matches').doc();
        final seed1 = gTeams[0];
        final seed4 = gTeams.length >= 4 ? gTeams[3] : gTeams[gTeams.length - 1];
        batch.set(m1Ref, _buildGroupMatch(
          groupName: groupName,
          matchType: 'group_match_1',
          teamA: seed1,
          teamB: seed4,
        ));
      }

      // Modified Pool Play — Kamp 2: Seed 2 vs Seed 3 (de to midterste)
      if (gTeams.length >= 3) {
        final m2Ref = FirebaseFirestore.instance.collection('matches').doc();
        batch.set(m2Ref, _buildGroupMatch(
          groupName: groupName,
          matchType: 'group_match_2',
          teamA: gTeams[1],
          teamB: gTeams[2],
        ));
      }
    }

    await batch.commit();
    _snack("Grupper generert! $numGroups puljer med serpentine-seeding.");
  }

  Future<void> _generateGroupRound2() async {
    if (_selectedCategoryId == null) { _snack("Velg en klasse først."); return; }

    final finishedSnap = await FirebaseFirestore.instance
        .collection('matches')
        .where('tournament_id', isEqualTo: widget.tournamentId)
        .where('category_id', isEqualTo: _selectedCategoryId)
        .where('stage', isEqualTo: 'group')
        .where('status', isEqualTo: 'finished')
        .get();

    final finished = finishedSnap.docs;
    final groups = finished
        .map((m) => (m.data() as Map)['group'] as String?)
        .whereType<String>()
        .toSet();

    if (groups.isEmpty) {
      _snack("Ingen ferdige kamper funnet. Spill Runde 1 først.", isError: true);
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    int added = 0;

    for (final groupName in groups) {
      // Skip if round 2 already exists for this group
      final r2Snap = await FirebaseFirestore.instance
          .collection('matches')
          .where('tournament_id', isEqualTo: widget.tournamentId)
          .where('group', isEqualTo: groupName)
          .where('stage', isEqualTo: 'group')
          .get();
      final hasR2 = r2Snap.docs.any((m) {
        final t = (m.data() as Map)['match_type'] as String? ?? '';
        return t == 'group_match_3' || t == 'group_match_4';
      });
      if (hasR2) continue;

      final m1List = finished.where((m) =>
          (m.data() as Map)['group'] == groupName &&
          (m.data() as Map)['match_type'] == 'group_match_1').toList();
      final m2List = finished.where((m) =>
          (m.data() as Map)['group'] == groupName &&
          (m.data() as Map)['match_type'] == 'group_match_2').toList();

      if (m1List.isEmpty || m2List.isEmpty) continue;

      final m1 = Map<String, dynamic>.from(m1List.first.data() as Map);
      final m2 = Map<String, dynamic>.from(m2List.first.data() as Map);

      bool homeWins(Map d) => (d['home_score'] as int? ?? 0) > (d['away_score'] as int? ?? 0);

      final m1WinnerId = homeWins(m1) ? m1['team_a_id'] : m1['team_b_id'];
      final m1LoserId  = homeWins(m1) ? m1['team_b_id'] : m1['team_a_id'];
      final m2WinnerId = homeWins(m2) ? m2['team_a_id'] : m2['team_b_id'];
      final m2LoserId  = homeWins(m2) ? m2['team_b_id'] : m2['team_a_id'];

      final winA  = await FirebaseFirestore.instance.collection('teams').doc(m1WinnerId as String).get();
      final winB  = await FirebaseFirestore.instance.collection('teams').doc(m2WinnerId as String).get();
      final loseA = await FirebaseFirestore.instance.collection('teams').doc(m1LoserId as String).get();
      final loseB = await FirebaseFirestore.instance.collection('teams').doc(m2LoserId as String).get();

      if (!winA.exists || !winB.exists || !loseA.exists || !loseB.exists) continue;

      // Kamp 3 (Vinnerkampen): Winner M1 vs Winner M2 → 1./2. plass
      batch.set(
        FirebaseFirestore.instance.collection('matches').doc(),
        _buildGroupMatch(groupName: groupName, matchType: 'group_match_3', teamA: winA, teamB: winB),
      );

      // Kamp 4 (Taperkampen): Loser M1 vs Loser M2 → 3./4. plass
      batch.set(
        FirebaseFirestore.instance.collection('matches').doc(),
        _buildGroupMatch(groupName: groupName, matchType: 'group_match_4', teamA: loseA, teamB: loseB),
      );

      added += 2;
    }

    if (added > 0) {
      await batch.commit();
      _snack("Runde 2 satt opp for $added kamper!");
    } else {
      _snack("Ingen nye grupper klare for Runde 2 ennå.");
    }
  }

  Future<void> _finalizePlacements() async {
    if (_selectedCategoryId == null) return;

    final finishedSnap = await FirebaseFirestore.instance
        .collection('matches')
        .where('tournament_id', isEqualTo: widget.tournamentId)
        .where('category_id', isEqualTo: _selectedCategoryId)
        .where('stage', isEqualTo: 'group')
        .where('status', isEqualTo: 'finished')
        .get();

    final batch = FirebaseFirestore.instance.batch();
    int updated = 0;

    for (final m in finishedSnap.docs) {
      final d = Map<String, dynamic>.from(m.data() as Map);
      final mType = d['match_type'] as String? ?? '';
      if (mType != 'group_match_3' && mType != 'group_match_4') continue;

      final homeWins = (d['home_score'] as int? ?? 0) > (d['away_score'] as int? ?? 0);
      final winnerId = homeWins ? d['team_a_id'] : d['team_b_id'];
      final loserId  = homeWins ? d['team_b_id'] : d['team_a_id'];

      final winPlace  = mType == 'group_match_3' ? 1 : 3;
      final losePlace = mType == 'group_match_3' ? 2 : 4;

      batch.update(FirebaseFirestore.instance.collection('teams').doc(winnerId as String), {'group_placement': winPlace});
      batch.update(FirebaseFirestore.instance.collection('teams').doc(loserId  as String), {'group_placement': losePlace});
      updated += 2;
    }

    if (updated > 0) {
      await batch.commit();
      _snack("Plasseringer beregnet for $updated lag.");
    } else {
      _snack("Ingen ferdige Runde 2-kamper funnet.");
    }
  }

  Future<void> _simulateAll() async {
    final snackCtrl = ScaffoldMessenger.of(context);
    snackCtrl.showSnackBar(const SnackBar(content: Text("Simulerer alle oppsatte kamper..."), duration: Duration(minutes: 2)));
    await MatchSimulator.simulateScheduledMatches(widget.tournamentId, (_) {});
    snackCtrl.hideCurrentSnackBar();
    snackCtrl.showSnackBar(const SnackBar(content: Text("Simulering fullført!")));
  }

  // ─── Playoff logic ─────────────────────────────────────────────────────────

  Future<void> _generatePlayoffs() async {
    if (_selectedCategoryId == null) { _snack("Velg en klasse først."); return; }

    final teamsSnap = await FirebaseFirestore.instance
        .collection('teams')
        .where('tournament_id', isEqualTo: widget.tournamentId)
        .where('category_id', isEqualTo: _selectedCategoryId)
        .get();
    final allTeams = teamsSnap.docs;

    if (allTeams.any((t) => (t.data() as Map)['group_placement'] == null)) {
      _snack("Alle lag må ha plasseringer. Kjør \"Beregn Plasseringer\" under Grupper-fanen.", isError: true);
      return;
    }

    final groupNames = allTeams
        .map((t) => (t.data() as Map)['group'] as String?)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    final numGroups = groupNames.length;

    if (numGroups != 4 && numGroups != 8) {
      _snack("Støtter 4 eller 8 grupper (har $numGroups grupper).", isError: true);
      return;
    }

    final existing = await FirebaseFirestore.instance
        .collection('matches')
        .where('tournament_id', isEqualTo: widget.tournamentId)
        .where('category_id', isEqualTo: _selectedCategoryId)
        .where('stage', isEqualTo: 'playoff')
        .get();
    if (existing.docs.isNotEmpty) {
      _snack("Sluttspill er allerede generert.", isError: true);
      return;
    }

    final db = FirebaseFirestore.instance;
    final List<int> nums = numGroups == 4
        ? [101,102,103,104,105,106,107,201,202,203,301,302,303]
        : [101,102,103,104,105,106,107,108,109,110,111,201,202,203,204,205,206,207,301,302,303,304,305,306,307];
    final refs = <int, DocumentReference>{for (final n in nums) n: db.collection('matches').doc()};

    // ── Slot helpers ─────────────────────────────────────────────────────────

    DocumentSnapshot? teamAt(String group, int placement) {
      try {
        return allTeams.firstWhere((t) {
          final d = t.data() as Map;
          return d['group'] == group && d['group_placement'] == placement;
        });
      } catch (_) { return null; }
    }

    Map<String, dynamic> realSlot(String px, DocumentSnapshot team) {
      final d = team.data() as Map<String, dynamic>;
      return {
        '${px}_name': d['team_name'] ?? '',
        '${px}_id': team.id,
        '${px}_p1_name': d['player1_name'] ?? '',
        '${px}_p1_id': d['player1_id'] ?? '',
        '${px}_p2_name': d['player2_name'] ?? '',
        '${px}_p2_id': d['player2_id'] ?? '',
      };
    }

    Map<String, dynamic> phSlot(String px, String ph) =>
        {'${px}_name': ph, '${px}_id': 'placeholder'};

    Map<String, dynamic> groupSlot(String px, String group, int place) {
      final team = teamAt(group, place);
      final placeStr = place == 1 ? '1st' : place == 2 ? '2nd' : place == 3 ? '3rd' : '4th';
      return team != null ? realSlot(px, team) : phSlot(px, '${placeStr}_Place_Pool_$group');
    }

    Map<String, dynamic> winSlot(String px, int fromNum) => {
      '${px}_name': 'Vinner Kamp $fromNum',
      '${px}_id': 'placeholder',
      '${px}_from_match': refs[fromNum]!.id,
    };

    Map<String, dynamic> mkMatch({
      required String bracket,
      required String round,
      required int num,
      required Map<String, dynamic> aSlot,
      required Map<String, dynamic> bSlot,
      int? nextNum,
      String? nextSlot,
    }) {
      final isPending = aSlot['team_a_id'] == 'placeholder' || bSlot['team_b_id'] == 'placeholder';
      return {
        'tournament_id': widget.tournamentId,
        'category_id': _selectedCategoryId,
        'stage': 'playoff',
        'bracket': bracket,
        'round': round,
        'match_number': num,
        'status': isPending ? 'pending' : 'scheduled',
        'court': 'TBD',
        'timestamp': FieldValue.serverTimestamp(),
        'home_score': 0, 'away_score': 0,
        'home_sets': 0, 'away_sets': 0,
        'current_set': 1, 'past_sets': [],
        if (nextNum != null) 'next_match_id': refs[nextNum]!.id,
        if (nextSlot != null) 'next_match_slot': nextSlot,
        ...aSlot,
        ...bSlot,
      };
    }

    // ── Build bracket ────────────────────────────────────────────────────────

    final batch = db.batch();
    final g = groupNames;

    if (numGroups == 4) {
      // A-bracket: QF (seed1 vs seed8 format) → SF → Finale
      // Half 1: seed1(g[0]) and seed4(g[3]) → 1stA/2ndD path
      // Half 2: seed2(g[1]) and seed3(g[2]) → 1stB/2ndC path
      batch.set(refs[101]!, mkMatch(bracket:'A', round:'qf', num:101, nextNum:105, nextSlot:'a',
          aSlot: groupSlot('team_a', g[0], 1), bSlot: groupSlot('team_b', g[3], 2)));
      batch.set(refs[102]!, mkMatch(bracket:'A', round:'qf', num:102, nextNum:105, nextSlot:'b',
          aSlot: groupSlot('team_a', g[3], 1), bSlot: groupSlot('team_b', g[0], 2)));
      batch.set(refs[103]!, mkMatch(bracket:'A', round:'qf', num:103, nextNum:106, nextSlot:'a',
          aSlot: groupSlot('team_a', g[1], 1), bSlot: groupSlot('team_b', g[2], 2)));
      batch.set(refs[104]!, mkMatch(bracket:'A', round:'qf', num:104, nextNum:106, nextSlot:'b',
          aSlot: groupSlot('team_a', g[2], 1), bSlot: groupSlot('team_b', g[1], 2)));
      batch.set(refs[105]!, mkMatch(bracket:'A', round:'sf', num:105, nextNum:107, nextSlot:'a',
          aSlot: winSlot('team_a', 101), bSlot: winSlot('team_b', 102)));
      batch.set(refs[106]!, mkMatch(bracket:'A', round:'sf', num:106, nextNum:107, nextSlot:'b',
          aSlot: winSlot('team_a', 103), bSlot: winSlot('team_b', 104)));
      batch.set(refs[107]!, mkMatch(bracket:'A', round:'final', num:107,
          aSlot: winSlot('team_a', 105), bSlot: winSlot('team_b', 106)));

      // B-bracket: SF → Finale (4 lag, 3. plasserte)
      batch.set(refs[201]!, mkMatch(bracket:'B', round:'sf', num:201, nextNum:203, nextSlot:'a',
          aSlot: groupSlot('team_a', g[0], 3), bSlot: groupSlot('team_b', g[3], 3)));
      batch.set(refs[202]!, mkMatch(bracket:'B', round:'sf', num:202, nextNum:203, nextSlot:'b',
          aSlot: groupSlot('team_a', g[1], 3), bSlot: groupSlot('team_b', g[2], 3)));
      batch.set(refs[203]!, mkMatch(bracket:'B', round:'final', num:203,
          aSlot: winSlot('team_a', 201), bSlot: winSlot('team_b', 202)));

      // C-bracket: SF → Finale (4 lag, 4. plasserte)
      batch.set(refs[301]!, mkMatch(bracket:'C', round:'sf', num:301, nextNum:303, nextSlot:'a',
          aSlot: groupSlot('team_a', g[0], 4), bSlot: groupSlot('team_b', g[3], 4)));
      batch.set(refs[302]!, mkMatch(bracket:'C', round:'sf', num:302, nextNum:303, nextSlot:'b',
          aSlot: groupSlot('team_a', g[1], 4), bSlot: groupSlot('team_b', g[2], 4)));
      batch.set(refs[303]!, mkMatch(bracket:'C', round:'final', num:303,
          aSlot: winSlot('team_a', 301), bSlot: winSlot('team_b', 302)));

    } else {
      // 8 grupper — A-bracket med 4 Byes (g[0]–g[3] = A–D, g[4]–g[7] = E–H)
      // R16: nedre halvdel spiller seg opp til KF
      batch.set(refs[101]!, mkMatch(bracket:'A', round:'r16', num:101, nextNum:106, nextSlot:'b',
          aSlot: groupSlot('team_a', g[4], 1), bSlot: groupSlot('team_b', g[3], 2)));
      batch.set(refs[102]!, mkMatch(bracket:'A', round:'r16', num:102, nextNum:105, nextSlot:'b',
          aSlot: groupSlot('team_a', g[7], 1), bSlot: groupSlot('team_b', g[0], 2)));
      batch.set(refs[103]!, mkMatch(bracket:'A', round:'r16', num:103, nextNum:108, nextSlot:'b',
          aSlot: groupSlot('team_a', g[5], 1), bSlot: groupSlot('team_b', g[2], 2)));
      batch.set(refs[104]!, mkMatch(bracket:'A', round:'r16', num:104, nextNum:107, nextSlot:'b',
          aSlot: groupSlot('team_a', g[6], 1), bSlot: groupSlot('team_b', g[1], 2)));
      // KF: 1stA og 1stB på HVER SIN HALVDEL (møtes aldri før Finale)
      batch.set(refs[105]!, mkMatch(bracket:'A', round:'qf', num:105, nextNum:109, nextSlot:'a',
          aSlot: groupSlot('team_a', g[0], 1), bSlot: winSlot('team_b', 102)));
      batch.set(refs[106]!, mkMatch(bracket:'A', round:'qf', num:106, nextNum:109, nextSlot:'b',
          aSlot: groupSlot('team_a', g[3], 1), bSlot: winSlot('team_b', 101)));
      batch.set(refs[107]!, mkMatch(bracket:'A', round:'qf', num:107, nextNum:110, nextSlot:'a',
          aSlot: groupSlot('team_a', g[1], 1), bSlot: winSlot('team_b', 104)));
      batch.set(refs[108]!, mkMatch(bracket:'A', round:'qf', num:108, nextNum:110, nextSlot:'b',
          aSlot: groupSlot('team_a', g[2], 1), bSlot: winSlot('team_b', 103)));
      batch.set(refs[109]!, mkMatch(bracket:'A', round:'sf', num:109, nextNum:111, nextSlot:'a',
          aSlot: winSlot('team_a', 105), bSlot: winSlot('team_b', 106)));
      batch.set(refs[110]!, mkMatch(bracket:'A', round:'sf', num:110, nextNum:111, nextSlot:'b',
          aSlot: winSlot('team_a', 107), bSlot: winSlot('team_b', 108)));
      batch.set(refs[111]!, mkMatch(bracket:'A', round:'final', num:111,
          aSlot: winSlot('team_a', 109), bSlot: winSlot('team_b', 110)));

      // B-bracket: KF → SF → Finale (8 lag, 3. plasserte)
      batch.set(refs[201]!, mkMatch(bracket:'B', round:'qf', num:201, nextNum:205, nextSlot:'a',
          aSlot: groupSlot('team_a', g[0], 3), bSlot: groupSlot('team_b', g[7], 3)));
      batch.set(refs[202]!, mkMatch(bracket:'B', round:'qf', num:202, nextNum:205, nextSlot:'b',
          aSlot: groupSlot('team_a', g[3], 3), bSlot: groupSlot('team_b', g[4], 3)));
      batch.set(refs[203]!, mkMatch(bracket:'B', round:'qf', num:203, nextNum:206, nextSlot:'a',
          aSlot: groupSlot('team_a', g[1], 3), bSlot: groupSlot('team_b', g[6], 3)));
      batch.set(refs[204]!, mkMatch(bracket:'B', round:'qf', num:204, nextNum:206, nextSlot:'b',
          aSlot: groupSlot('team_a', g[2], 3), bSlot: groupSlot('team_b', g[5], 3)));
      batch.set(refs[205]!, mkMatch(bracket:'B', round:'sf', num:205, nextNum:207, nextSlot:'a',
          aSlot: winSlot('team_a', 201), bSlot: winSlot('team_b', 202)));
      batch.set(refs[206]!, mkMatch(bracket:'B', round:'sf', num:206, nextNum:207, nextSlot:'b',
          aSlot: winSlot('team_a', 203), bSlot: winSlot('team_b', 204)));
      batch.set(refs[207]!, mkMatch(bracket:'B', round:'final', num:207,
          aSlot: winSlot('team_a', 205), bSlot: winSlot('team_b', 206)));

      // C-bracket: KF → SF → Finale (8 lag, 4. plasserte)
      batch.set(refs[301]!, mkMatch(bracket:'C', round:'qf', num:301, nextNum:305, nextSlot:'a',
          aSlot: groupSlot('team_a', g[0], 4), bSlot: groupSlot('team_b', g[7], 4)));
      batch.set(refs[302]!, mkMatch(bracket:'C', round:'qf', num:302, nextNum:305, nextSlot:'b',
          aSlot: groupSlot('team_a', g[3], 4), bSlot: groupSlot('team_b', g[4], 4)));
      batch.set(refs[303]!, mkMatch(bracket:'C', round:'qf', num:303, nextNum:306, nextSlot:'a',
          aSlot: groupSlot('team_a', g[1], 4), bSlot: groupSlot('team_b', g[6], 4)));
      batch.set(refs[304]!, mkMatch(bracket:'C', round:'qf', num:304, nextNum:306, nextSlot:'b',
          aSlot: groupSlot('team_a', g[2], 4), bSlot: groupSlot('team_b', g[5], 4)));
      batch.set(refs[305]!, mkMatch(bracket:'C', round:'sf', num:305, nextNum:307, nextSlot:'a',
          aSlot: winSlot('team_a', 301), bSlot: winSlot('team_b', 302)));
      batch.set(refs[306]!, mkMatch(bracket:'C', round:'sf', num:306, nextNum:307, nextSlot:'b',
          aSlot: winSlot('team_a', 303), bSlot: winSlot('team_b', 304)));
      batch.set(refs[307]!, mkMatch(bracket:'C', round:'final', num:307,
          aSlot: winSlot('team_a', 305), bSlot: winSlot('team_b', 306)));
    }

    await batch.commit();
    _snack("A/B/C-sluttspill generert ($numGroups grupper)!");
  }

  // ─── Sluttspill-fanen ────────────────────────────────────────────────────

  Widget _buildPlayoffsTab() {
    if (_selectedCategoryId == null) {
      return const Center(child: Text("Velg en klasse i menyen over."));
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.emoji_events, size: 16),
            label: const Text("Generer A/B/C Sluttspill"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5A623),
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            onPressed: _generatePlayoffs,
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildBracketsDisplay()),
      ],
    );
  }

  Widget _buildBracketsDisplay() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('tournament_id', isEqualTo: widget.tournamentId)
          .where('category_id', isEqualTo: _selectedCategoryId)
          .where('stage', isEqualTo: 'playoff')
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final matches = snap.data!.docs;

        if (matches.isEmpty) {
          return const Center(
            child: Text(
              "Sluttspill ikke generert enda.\nFullfør gruppespillet og trykk knappen over.",
              textAlign: TextAlign.center,
            ),
          );
        }

        List<DocumentSnapshot> forBracket(String b) => (matches
            .where((m) => (m.data() as Map)['bracket'] == b)
            .toList()
          ..sort((a, x) => ((a.data() as Map)['match_number'] as int? ?? 0)
              .compareTo((x.data() as Map)['match_number'] as int? ?? 0)));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _bracketHeader('A-SLUTTSPILL', Colors.amber[800]!),
            const SizedBox(height: 4),
            ...forBracket('A').map(_buildPlayoffMatchRow),
            const SizedBox(height: 20),
            _bracketHeader('B-SLUTTSPILL', Colors.blue[700]!),
            const SizedBox(height: 4),
            ...forBracket('B').map(_buildPlayoffMatchRow),
            const SizedBox(height: 20),
            _bracketHeader('C-SLUTTSPILL', Colors.grey[700]!),
            const SizedBox(height: 4),
            ...forBracket('C').map(_buildPlayoffMatchRow),
          ],
        );
      },
    );
  }

  Widget _bracketHeader(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _buildPlayoffMatchRow(DocumentSnapshot matchDoc) {
    final d = matchDoc.data() as Map<String, dynamic>;
    final status = d['status'] as String? ?? 'pending';
    final round = d['round'] as String? ?? '';
    final num = d['match_number'] as int? ?? 0;
    final isFinished = status == 'finished';
    final isPending = status == 'pending';
    final isPlaceholder = d['team_a_id'] == 'placeholder' || d['team_b_id'] == 'placeholder';

    String roundLabel = round;
    if (round == 'r16') roundLabel = 'R16';
    if (round == 'qf') roundLabel = 'Kvartfinale';
    if (round == 'sf') roundLabel = 'Semifinale';
    if (round == 'final') roundLabel = 'FINALE';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 85,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kamp $num', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  Text(roundLabel,
                      style: TextStyle(
                          fontSize: 11, color: Colors.blue[900], fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d['team_a_name'] ?? 'TBD',
                    style: TextStyle(
                      fontSize: 12,
                      color: isPending ? Colors.grey[500] : null,
                      fontStyle: isPending ? FontStyle.italic : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    d['team_b_name'] ?? 'TBD',
                    style: TextStyle(
                      fontSize: 12,
                      color: isPending ? Colors.grey[500] : null,
                      fontStyle: isPending ? FontStyle.italic : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isFinished)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${d['home_score']} – ${d['away_score']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                ),
              )
            else
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isPending ? Colors.grey[200] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isPending ? 'Venter' : 'Planlagt',
                  style: TextStyle(
                      fontSize: 10,
                      color: isPending ? Colors.grey[600] : Colors.blue[800]),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.qr_code, size: 18),
              tooltip: "QR",
              onPressed: () =>
                  _showQrDialog(matchDoc.id, d['team_a_name'] ?? 'A', d['team_b_name'] ?? 'B'),
            ),
            IconButton(
              icon: Icon(Icons.sports_esports,
                  size: 18, color: isPlaceholder ? Colors.grey : Colors.green),
              tooltip: "Styr kamp",
              onPressed: isPlaceholder
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MatchControlPage(
                            matchId: matchDoc.id,
                            teamAName: d['team_a_name'] ?? 'Lag A',
                            teamBName: d['team_b_name'] ?? 'Lag B',
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin: ${widget.tournamentName}"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.groups), text: "Lag"),
            Tab(icon: Icon(Icons.grid_view), text: "Grupper"),
            Tab(icon: Icon(Icons.emoji_events), text: "Sluttspill"),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildCategorySelector(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTeamsTab(),
                _buildGroupsTab(),
                _buildPlayoffsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddTeamDialog,
              label: const Text("Nytt Lag"),
              icon: const Icon(Icons.group_add),
              backgroundColor: Colors.blue[900],
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      color: Colors.blue[50],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('categories')
            .where('tournament_id', isEqualTo: widget.tournamentId)
            .snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const SizedBox(height: 40, child: Center(child: LinearProgressIndicator()));
          final cats = snap.data!.docs;
          if (cats.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(8),
              child: Text("Ingen klasser funnet. Legg til klasser ved turneringsopprettelse.",
                  style: TextStyle(color: Colors.red)),
            );
          }

          // Auto-select first if none selected
          if (_selectedCategoryId == null && cats.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _selectedCategoryId = cats.first.id;
              });
            });
          }

          return Row(
            children: [
              const Text("Klasse:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedCategoryId,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: cats.map((c) {
                    final data = c.data() as Map<String, dynamic>;
                    return DropdownMenuItem<String>(
                      value: c.id,
                      child: Text("${data['name']} (max ${data['max_teams']} lag)"),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Lag-fanen ────────────────────────────────────────────────────────────

  Widget _buildTeamsTab() {
    if (_selectedCategoryId == null) {
      return const Center(child: Text("Velg en klasse i menyen over."));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.auto_awesome),
            label: const Text("Auto-generer 16 testlag (fra spillerdatabase)"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[800], foregroundColor: Colors.white),
            onPressed: _autoGenerateTeams,
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('teams')
                .where('tournament_id', isEqualTo: widget.tournamentId)
                .where('category_id', isEqualTo: _selectedCategoryId)
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final teams = snap.data!.docs;
              if (teams.isEmpty) return const Center(child: Text("Ingen lag registrert enda.\nTrykk + for å legge til lag.", textAlign: TextAlign.center));

              final sorted = List<DocumentSnapshot>.from(teams)
                ..sort((a, b) {
                  final as_ = (a.data() as Map)['seed'] as int? ?? 999;
                  final bs = (b.data() as Map)['seed'] as int? ?? 999;
                  final ap = (a.data() as Map)['team_points'] as num? ?? 0;
                  final bp = (b.data() as Map)['team_points'] as num? ?? 0;
                  if (as_ != 999 || bs != 999) return as_.compareTo(bs);
                  return bp.compareTo(ap);
                });

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: sorted.length,
                itemBuilder: (ctx, i) {
                  final d = sorted[i].data() as Map<String, dynamic>;
                  final seed = d['seed'] as int?;
                  final group = d['group'] as String?;
                  final placement = d['group_placement'] as int?;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: seed != null ? Colors.blue[100] : Colors.grey[200],
                        child: Text(seed?.toString() ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      title: Text(d['team_name'] ?? 'Ukjent Lag',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${d['player1_name'] ?? ''} & ${d['player2_name'] ?? ''}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (group != null)
                            Chip(
                              label: Text("Pulje $group${placement != null ? ' • $placement.' : ''}"),
                              backgroundColor: Colors.blue[50],
                              visualDensity: VisualDensity.compact,
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDeleteTeam(sorted[i].id, d['team_name'] ?? 'laget'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Grupper-fanen ────────────────────────────────────────────────────────

  Widget _buildGroupsTab() {
    if (_selectedCategoryId == null) {
      return const Center(child: Text("Velg en klasse i menyen over."));
    }

    return Column(
      children: [
        // Action buttons
        Container(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.shuffle, size: 16),
                label: const Text("Generer Grupper\n(Runde 1)"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[900], foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 12)),
                onPressed: _generateGroupStage,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text("Sett opp\nRunde 2"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800], foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 12)),
                onPressed: _generateGroupRound2,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.leaderboard, size: 16),
                label: const Text("Beregn\nPlasseringer"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[800], foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 12)),
                onPressed: _finalizePlacements,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text("Simuler\nAlt"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[800], foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 12)),
                onPressed: _simulateAll,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Groups display
        Expanded(child: _buildGroupsDisplay()),
      ],
    );
  }

  Widget _buildGroupsDisplay() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('teams')
          .where('tournament_id', isEqualTo: widget.tournamentId)
          .where('category_id', isEqualTo: _selectedCategoryId)
          .snapshots(),
      builder: (ctx, teamSnap) {
        if (!teamSnap.hasData) return const Center(child: CircularProgressIndicator());
        final allTeams = teamSnap.data!.docs;

        // Collect unique group names
        final groupNames = allTeams
            .map((t) => (t.data() as Map)['group'] as String?)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();

        if (groupNames.isEmpty) {
          return const Center(
            child: Text("Grupper ikke generert enda.\nTrykk \"Generer Grupper\" over.",
                textAlign: TextAlign.center),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('matches')
              .where('tournament_id', isEqualTo: widget.tournamentId)
              .where('category_id', isEqualTo: _selectedCategoryId)
              .where('stage', isEqualTo: 'group')
              .snapshots(),
          builder: (ctx, matchSnap) {
            final allMatches = matchSnap.hasData ? matchSnap.data!.docs : <DocumentSnapshot>[];

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groupNames.length,
              itemBuilder: (ctx, i) {
                final groupName = groupNames[i];
                final groupTeams = allTeams
                    .where((t) => (t.data() as Map)['group'] == groupName)
                    .toList()
                  ..sort((a, b) {
                    final ap = (a.data() as Map)['group_placement'] as int? ?? 99;
                    final bp = (b.data() as Map)['group_placement'] as int? ?? 99;
                    if (ap != 99 || bp != 99) return ap.compareTo(bp);
                    final as_ = (a.data() as Map)['seed'] as int? ?? 99;
                    final bs = (b.data() as Map)['seed'] as int? ?? 99;
                    return as_.compareTo(bs);
                  });

                final groupMatches = allMatches
                    .where((m) => (m.data() as Map)['group'] == groupName)
                    .toList()
                  ..sort((a, b) {
                    final ta = (a.data() as Map)['match_type'] as String? ?? '';
                    final tb = (b.data() as Map)['match_type'] as String? ?? '';
                    return ta.compareTo(tb);
                  });

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: Colors.blue[900],
                        child: Text("Pulje $groupName",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      // Teams
                      ...groupTeams.asMap().entries.map((e) {
                        final idx = e.key;
                        final d = e.value.data() as Map<String, dynamic>;
                        final placement = d['group_placement'] as int?;
                        final seed = d['seed'] as int?;
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: placement != null
                                ? [Colors.amber[700], Colors.grey[400], Colors.brown[400], Colors.grey[300]][placement - 1]
                                : Colors.blue[100],
                            child: Text(
                              placement?.toString() ?? (idx + 1).toString(),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(d['team_name'] ?? 'Ukjent',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text("Seed $seed • ${d['player1_name'] ?? ''} & ${d['player2_name'] ?? ''}",
                              style: const TextStyle(fontSize: 11)),
                        );
                      }),
                      const Divider(height: 1),
                      // Matches
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text("KAMPER",
                            style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                      ),
                      if (groupMatches.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text("Ingen kamper enda.", style: TextStyle(color: Colors.grey)),
                        )
                      else
                        ...groupMatches.map((m) => _buildMatchRow(m)),
                      const SizedBox(height: 4),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMatchRow(DocumentSnapshot matchDoc) {
    final d = matchDoc.data() as Map<String, dynamic>;
    final mType = d['match_type'] as String? ?? '';
    final status = d['status'] as String? ?? 'scheduled';
    final isFinished = status == 'finished';
    final isPlaceholder = d['team_a_id'] == 'placeholder' || d['team_b_id'] == 'placeholder';

    String label = mType;
    if (mType == 'group_match_1') label = 'Kamp 1 (S1 vs S4)';
    if (mType == 'group_match_2') label = 'Kamp 2 (S2 vs S3)';
    if (mType == 'group_match_3') label = 'Vinnerkamp → 1./2.';
    if (mType == 'group_match_4') label = 'Taperkamp → 3./4.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.blue[900], fontWeight: FontWeight.bold)),
                Text(
                  "${d['team_a_name'] ?? 'TBD'} vs ${d['team_b_name'] ?? 'TBD'}",
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                if (isFinished)
                  Text("${d['home_score']} – ${d['away_score']}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
          ),
          // Status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isFinished ? Colors.green[100] : (status == 'live' ? Colors.red[100] : Colors.grey[200]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isFinished ? 'Ferdig' : (status == 'live' ? 'LIVE' : 'Planlagt'),
              style: TextStyle(
                fontSize: 10,
                color: isFinished ? Colors.green[800] : (status == 'live' ? Colors.red[800] : Colors.grey[600]),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // QR button
          IconButton(
            icon: const Icon(Icons.qr_code, size: 20),
            tooltip: "Vis QR",
            onPressed: () => _showQrDialog(matchDoc.id, d['team_a_name'] ?? 'A', d['team_b_name'] ?? 'B'),
          ),
          // Control button
          IconButton(
            icon: Icon(Icons.sports_esports, size: 20, color: isPlaceholder ? Colors.grey : Colors.green),
            tooltip: "Styr kamp",
            onPressed: isPlaceholder ? null : () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MatchControlPage(
                matchId: matchDoc.id,
                teamAName: d['team_a_name'] ?? 'Lag A',
                teamBName: d['team_b_name'] ?? 'Lag B',
              )),
            ),
          ),
        ],
      ),
    );
  }
}
