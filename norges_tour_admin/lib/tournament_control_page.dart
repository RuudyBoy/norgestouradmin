import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'match_control_page.dart';
import 'registrations_page.dart';
import 'edit_tournament_page.dart';
import 'tournament_schedule_page.dart';
import 'theme/app_colors.dart';

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

  // Lytter på Firestore – oppdager når livescore-appen registrerer resultater
  StreamSubscription<QuerySnapshot>? _finishedMatchListener;
  Set<String> _knownFinishedIds = {};
  bool _listenerReady = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
      if (_tabController.index == 2 && !_tabController.indexIsChanging) {
        _resolvePendingMatches();
      }
    });
    _setupFinishedMatchListener();
  }

  /// Lytter på alle kamper i denne turneringen med status == 'finished'.
  /// Når livescore-appen markerer en kamp som ferdig, trigges
  /// _resolvePendingMatches() automatisk slik at neste runde og sluttspill
  /// oppdateres med riktige lag umiddelbart.
  void _setupFinishedMatchListener() {
    _finishedMatchListener = FirebaseFirestore.instance
        .collection('matches')
        .where('tournament_id', isEqualTo: widget.tournamentId)
        .where('status', isEqualTo: 'finished')
        .snapshots()
        .listen((snapshot) {
      final currentIds = snapshot.docs.map((d) => d.id).toSet();

      if (!_listenerReady) {
        // Første emisjon – bare noter eksisterende, ikke trigger resolve
        _knownFinishedIds = currentIds;
        _listenerReady = true;
        return;
      }

      final newlyFinished = currentIds.difference(_knownFinishedIds);
      if (newlyFinished.isNotEmpty) {
        _knownFinishedIds = currentIds;
        // En eller flere kamper ble nettopp avsluttet av livescore-appen
        _resolvePendingMatches();
      }
    });
  }

  @override
  void dispose() {
    _finishedMatchListener?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.adminOrangeHover : null,
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
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminOrange, foregroundColor: AppColors.adminText),
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
        SelectableText(url, style: const TextStyle(fontSize: 10, color: AppColors.adminTextSecondary)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Lukk"))],
    ));
  }

  // ─── HOVEDNØKKEL: Generer hele turneringen på én gang ─────────────────────
  //
  // Trykk én gang → grupper + runde 2 + sluttspill opprettes med én gang.
  // Runde 2-kamper og sluttspillkamper starter som "pending" (lagene er
  // ukjente ennå). Etter hvert som kamper spilles og resultater registreres
  // kaller vi _resolvePendingMatches() som fyller inn lagnavnene automatisk.

  Future<void> _generateGroupStage() async {
    if (_selectedCategoryId == null) { _snack("Velg en klasse først."); return; }

    final snap = await FirebaseFirestore.instance
        .collection('teams')
        .where('tournament_id', isEqualTo: widget.tournamentId)
        .where('category_id', isEqualTo: _selectedCategoryId)
        .get();

    final teams = snap.docs;
    if (teams.length < 4) {
      _snack("Trenger minst 4 lag for å generere (har ${teams.length}).", isError: true);
      return;
    }

    final existing = await FirebaseFirestore.instance
        .collection('matches')
        .where('tournament_id', isEqualTo: widget.tournamentId)
        .where('category_id', isEqualTo: _selectedCategoryId)
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
      final row = i ~/ numGroups;
      final col = i % numGroups;
      final groupIdx = (row % 2 == 0) ? col : (numGroups - 1 - col);
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
      // ─── 8-gruppe oppsett (32 lag) ─────────────────────────────────────────
      // A-bracket: R16 → QF → SF → Finale
      final r = <int, DocumentReference>{
        for (final n in [
          101,102,103,104,105,106,107,108,109,110,111,
          201,202,203,204,205,206,207,
          301,302,303,304,305,306,307
        ]) n: db.collection('matches').doc()
      };

      // R16 – 4 "wild card" kamper: høyere seedede 1ere vs 2ere
      batch.set(r[101]!, mkPlayoff(bracket:'A', round:'r16', num:101,
          nextId: r[106]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[4], 1), bSlot: groupSlot('team_b', g[3], 2)));

      batch.set(r[102]!, mkPlayoff(bracket:'A', round:'r16', num:102,
          nextId: r[105]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[7], 1), bSlot: groupSlot('team_b', g[0], 2)));

      batch.set(r[103]!, mkPlayoff(bracket:'A', round:'r16', num:103,
          nextId: r[108]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[5], 1), bSlot: groupSlot('team_b', g[2], 2)));

      batch.set(r[104]!, mkPlayoff(bracket:'A', round:'r16', num:104,
          nextId: r[107]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[6], 1), bSlot: groupSlot('team_b', g[1], 2)));

      // QF
      batch.set(r[105]!, mkPlayoff(bracket:'A', round:'qf', num:105,
          nextId: r[109]!.id, nextSlot:'a',
          aSlot: groupSlot('team_a', g[0], 1), bSlot: winnerSlot('team_b', r[102]!.id)));

      batch.set(r[106]!, mkPlayoff(bracket:'A', round:'qf', num:106,
          nextId: r[109]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[3], 1), bSlot: winnerSlot('team_b', r[101]!.id)));

      batch.set(r[107]!, mkPlayoff(bracket:'A', round:'qf', num:107,
          nextId: r[110]!.id, nextSlot:'a',
          aSlot: groupSlot('team_a', g[1], 1), bSlot: winnerSlot('team_b', r[104]!.id)));

      batch.set(r[108]!, mkPlayoff(bracket:'A', round:'qf', num:108,
          nextId: r[110]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[2], 1), bSlot: winnerSlot('team_b', r[103]!.id)));

      // SF
      batch.set(r[109]!, mkPlayoff(bracket:'A', round:'sf', num:109,
          nextId: r[111]!.id, nextSlot:'a',
          aSlot: winnerSlot('team_a', r[105]!.id), bSlot: winnerSlot('team_b', r[106]!.id)));

      batch.set(r[110]!, mkPlayoff(bracket:'A', round:'sf', num:110,
          nextId: r[111]!.id, nextSlot:'b',
          aSlot: winnerSlot('team_a', r[107]!.id), bSlot: winnerSlot('team_b', r[108]!.id)));

      batch.set(r[111]!, mkPlayoff(bracket:'A', round:'final', num:111,
          aSlot: winnerSlot('team_a', r[109]!.id), bSlot: winnerSlot('team_b', r[110]!.id)));

      // B-bracket (3. plass)
      batch.set(r[201]!, mkPlayoff(bracket:'B', round:'qf', num:201,
          nextId: r[205]!.id, nextSlot:'a',
          aSlot: groupSlot('team_a', g[0], 3), bSlot: groupSlot('team_b', g[7], 3)));

      batch.set(r[202]!, mkPlayoff(bracket:'B', round:'qf', num:202,
          nextId: r[205]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[3], 3), bSlot: groupSlot('team_b', g[4], 3)));

      batch.set(r[203]!, mkPlayoff(bracket:'B', round:'qf', num:203,
          nextId: r[206]!.id, nextSlot:'a',
          aSlot: groupSlot('team_a', g[1], 3), bSlot: groupSlot('team_b', g[6], 3)));

      batch.set(r[204]!, mkPlayoff(bracket:'B', round:'qf', num:204,
          nextId: r[206]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[2], 3), bSlot: groupSlot('team_b', g[5], 3)));

      batch.set(r[205]!, mkPlayoff(bracket:'B', round:'sf', num:205,
          nextId: r[207]!.id, nextSlot:'a',
          aSlot: winnerSlot('team_a', r[201]!.id), bSlot: winnerSlot('team_b', r[202]!.id)));

      batch.set(r[206]!, mkPlayoff(bracket:'B', round:'sf', num:206,
          nextId: r[207]!.id, nextSlot:'b',
          aSlot: winnerSlot('team_a', r[203]!.id), bSlot: winnerSlot('team_b', r[204]!.id)));

      batch.set(r[207]!, mkPlayoff(bracket:'B', round:'final', num:207,
          aSlot: winnerSlot('team_a', r[205]!.id), bSlot: winnerSlot('team_b', r[206]!.id)));

      // C-bracket (siste plass)
      batch.set(r[301]!, mkPlayoff(bracket:'C', round:'qf', num:301,
          nextId: r[305]!.id, nextSlot:'a',
          aSlot: groupSlot('team_a', g[0], 4), bSlot: groupSlot('team_b', g[7], 4)));

      batch.set(r[302]!, mkPlayoff(bracket:'C', round:'qf', num:302,
          nextId: r[305]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[3], 4), bSlot: groupSlot('team_b', g[4], 4)));

      batch.set(r[303]!, mkPlayoff(bracket:'C', round:'qf', num:303,
          nextId: r[306]!.id, nextSlot:'a',
          aSlot: groupSlot('team_a', g[1], 4), bSlot: groupSlot('team_b', g[6], 4)));

      batch.set(r[304]!, mkPlayoff(bracket:'C', round:'qf', num:304,
          nextId: r[306]!.id, nextSlot:'b',
          aSlot: groupSlot('team_a', g[2], 4), bSlot: groupSlot('team_b', g[5], 4)));

      batch.set(r[305]!, mkPlayoff(bracket:'C', round:'sf', num:305,
          nextId: r[307]!.id, nextSlot:'a',
          aSlot: winnerSlot('team_a', r[301]!.id), bSlot: winnerSlot('team_b', r[302]!.id)));

      batch.set(r[306]!, mkPlayoff(bracket:'C', round:'sf', num:306,
          nextId: r[307]!.id, nextSlot:'b',
          aSlot: winnerSlot('team_a', r[303]!.id), bSlot: winnerSlot('team_b', r[304]!.id)));

      batch.set(r[307]!, mkPlayoff(bracket:'C', round:'final', num:307,
          aSlot: winnerSlot('team_a', r[305]!.id), bSlot: winnerSlot('team_b', r[306]!.id)));
    }
    // For andre gruppeantall: sluttspill opprettes ikke automatisk
  }

  // ─── Auto-resolve: Fyll inn riktige lag etter hvert som resultater kommer ─

  Future<void> _resolvePendingMatches() async {
    if (_selectedCategoryId == null) return;

    // Last alle kamper for denne turneringen + klassen
    final allSnap = await FirebaseFirestore.instance
        .collection('matches')
        .where('tournament_id', isEqualTo: widget.tournamentId)
        .where('category_id', isEqualTo: _selectedCategoryId)
        .get();

    final allMatches = allSnap.docs;
    if (allMatches.isEmpty) return;

    final matchById = <String, Map<String, dynamic>>{
      for (final m in allMatches) m.id: m.data() as Map<String, dynamic>
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
        .where('category_id', isEqualTo: _selectedCategoryId)
        .get();

    final teamByGroupPlace = <String, Map<String, dynamic>>{};
    for (final t in teamsSnap.docs) {
      final d = t.data() as Map<String, dynamic>;
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
            final sp = useA ? 'team_a' : 'team_b';

            upd['${prefix}_name']   = src['${sp}_name']   ?? '';
            upd['${prefix}_id']     = src['${sp}_id']     ?? '';
            upd['${prefix}_p1_name'] = src['${sp}_p1_name'] ?? '';
            upd['${prefix}_p1_id']   = src['${sp}_p1_id']   ?? '';
            upd['${prefix}_p2_name'] = src['${sp}_p2_name'] ?? '';
            upd['${prefix}_p2_id']   = src['${sp}_p2_id']   ?? '';
          }
          continue;
        }

        // Kilde: gruppeplass (f.eks. "1. plass Pulje A")
        final fromGroup = d['${prefix}_from_group'] as String?;
        final fromPlace = d['${prefix}_from_place'] as int?;
        if (fromGroup != null && fromPlace != null) {
          final team = teamByGroupPlace['${fromGroup}_$fromPlace'];
          if (team != null) {
            upd['${prefix}_name']   = team['team_name']    ?? '';
            upd['${prefix}_id']     = team['_id']          ?? '';
            upd['${prefix}_p1_name'] = team['player1_name'] ?? '';
            upd['${prefix}_p1_id']   = team['player1_id']   ?? '';
            upd['${prefix}_p2_name'] = team['player2_name'] ?? '';
            upd['${prefix}_p2_id']   = team['player2_id']   ?? '';
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

  // ─── Reset ────────────────────────────────────────────────────────────────

  Future<void> _resetTournament() async {
    if (_selectedCategoryId == null) { _snack("Velg en klasse først."); return; }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Nullstill hele turneringen"),
        content: const Text(
            "Dette sletter ALLE kamper (gruppe + sluttspill) og tilbakestiller grupper og plasseringer.\n\nLagene beholdes.\n\nEr du sikker?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Avbryt")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminOrange, foregroundColor: AppColors.adminText),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Nullstill"),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // Slett ALLE kamper for denne klassen
    final matchSnap = await FirebaseFirestore.instance
        .collection('matches')
        .where('tournament_id', isEqualTo: widget.tournamentId)
        .where('category_id', isEqualTo: _selectedCategoryId)
        .get();

    final teamSnap = await FirebaseFirestore.instance
        .collection('teams')
        .where('tournament_id', isEqualTo: widget.tournamentId)
        .where('category_id', isEqualTo: _selectedCategoryId)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final m in matchSnap.docs) batch.delete(m.reference);
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

  // ─── Match editing ─────────────────────────────────────────────────────────

  void _showMatchEditDialog(DocumentSnapshot matchDoc) {
    final d = matchDoc.data() as Map<String, dynamic>;
    final courtCtrl = TextEditingController(text: d['court'] as String? ?? '');
    final timeCtrl  = TextEditingController(text: d['match_time'] as String? ?? '');
    final homeScoreCtrl = TextEditingController(text: '${d['home_score'] ?? 0}');
    final awayScoreCtrl = TextEditingController(text: '${d['away_score'] ?? 0}');
    final isFinished = (d['status'] as String? ?? '') == 'finished';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
        title: Text(
          "${d['team_a_name'] ?? 'A'} vs ${d['team_b_name'] ?? 'B'}",
          style: const TextStyle(fontSize: 15),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: courtCtrl,
                      decoration: const InputDecoration(
                          labelText: "Bane", border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.grid_view)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: timeCtrl,
                      decoration: const InputDecoration(
                          labelText: "Tid (HH:MM)", border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time)),
                    ),
                  ),
                ],
              ),
              if (isFinished) ...[
                const SizedBox(height: 12),
                const Divider(),
                const Text("Overstyr resultat", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: homeScoreCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: d['team_a_name'] ?? 'Lag A', border: const OutlineInputBorder()),
                      ),
                    ),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text("–", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    Expanded(
                      child: TextField(
                        controller: awayScoreCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: d['team_b_name'] ?? 'Lag B', border: const OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              const Divider(),
              const Text("Bytt lag", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.swap_horiz),
                label: const Text("Bytt Lag A ↔ Lag B"),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _swapTeamsInMatch(matchDoc);
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.flag, color: AppColors.adminOrange),
                label: const Text("Walkover – Lag A vinner",
                    style: TextStyle(color: AppColors.adminOrange)),
                onPressed: () async {
                  await matchDoc.reference.update({
                    'status': 'finished', 'home_score': 1, 'away_score': 0, 'walkover': true,
                  });
                  await _resolvePendingMatches();
                  if (ctx.mounted) { Navigator.pop(ctx); _snack("Walkover – Lag A vinner."); }
                },
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                icon: const Icon(Icons.flag, color: AppColors.adminOrange),
                label: const Text("Walkover – Lag B vinner",
                    style: TextStyle(color: AppColors.adminOrange)),
                onPressed: () async {
                  await matchDoc.reference.update({
                    'status': 'finished', 'home_score': 0, 'away_score': 1, 'walkover': true,
                  });
                  await _resolvePendingMatches();
                  if (ctx.mounted) { Navigator.pop(ctx); _snack("Walkover – Lag B vinner."); }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Avbryt")),
          ElevatedButton(
            onPressed: () async {
              final updates = <String, dynamic>{
                'court': courtCtrl.text.trim(),
                'match_time': timeCtrl.text.trim(),
              };
              if (isFinished) {
                updates['home_score'] = int.tryParse(homeScoreCtrl.text) ?? (d['home_score'] as int? ?? 0);
                updates['away_score'] = int.tryParse(awayScoreCtrl.text) ?? (d['away_score'] as int? ?? 0);
              }
              await matchDoc.reference.update(updates);
              // Resolve downstream kamper hvis resultat er endret
              if (isFinished) await _resolvePendingMatches();
              if (ctx.mounted) { Navigator.pop(ctx); _snack("Kamp oppdatert."); }
            },
            child: const Text("Lagre"),
          ),
        ],
      )),
    );
  }

  Future<void> _swapTeamsInMatch(DocumentSnapshot matchDoc) async {
    final d = matchDoc.data() as Map<String, dynamic>;
    await matchDoc.reference.update({
      'team_a_name': d['team_b_name'], 'team_a_id': d['team_b_id'],
      'team_a_p1_name': d['team_b_p1_name'], 'team_a_p1_id': d['team_b_p1_id'],
      'team_a_p2_name': d['team_b_p2_name'], 'team_a_p2_id': d['team_b_p2_id'],
      'team_b_name': d['team_a_name'], 'team_b_id': d['team_a_id'],
      'team_b_p1_name': d['team_a_p1_name'], 'team_b_p1_id': d['team_a_p1_id'],
      'team_b_p2_name': d['team_a_p2_name'], 'team_b_p2_id': d['team_a_p2_id'],
    });
    _snack("Lag byttet.");
  }

  // ─── Team editing ──────────────────────────────────────────────────────────

  void _showTeamEditDialog(DocumentSnapshot teamDoc) async {
    final d = teamDoc.data() as Map<String, dynamic>;
    final nameCtrl = TextEditingController(text: d['team_name'] ?? '');
    int? seed = (d['seed'] as num?)?.toInt();
    String? currentGroup = d['group'] as String?;
    String? selectedGroup = currentGroup;

    final groupsSnap = await FirebaseFirestore.instance
        .collection('teams')
        .where('tournament_id', isEqualTo: widget.tournamentId)
        .where('category_id', isEqualTo: _selectedCategoryId)
        .get();

    final allGroups = groupsSnap.docs
        .map((t) => (t.data() as Map)['group'] as String?)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
        title: Text("Rediger: ${d['team_name'] ?? ''}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Lagnavn", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: seed?.toString() ?? ''),
              decoration: const InputDecoration(labelText: "Seed-nummer", border: OutlineInputBorder()),
              onChanged: (v) => seed = int.tryParse(v),
            ),
            if (allGroups.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedGroup != null && allGroups.contains(selectedGroup) ? selectedGroup : null,
                decoration: const InputDecoration(labelText: "Flytt til pulje", border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text("Ingen pulje")),
                  ...allGroups.map((g) => DropdownMenuItem(value: g, child: Text("Pulje $g"))),
                ],
                onChanged: (v) => set(() => selectedGroup = v),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Avbryt")),
          ElevatedButton(
            onPressed: () async {
              final updates = <String, dynamic>{
                'team_name': nameCtrl.text.trim(),
                if (seed != null) 'seed': seed,
              };
              if (selectedGroup != currentGroup) {
                updates['group'] = selectedGroup == null ? FieldValue.delete() : selectedGroup;
              }
              await teamDoc.reference.update(updates);
              if (ctx.mounted) { Navigator.pop(ctx); _snack("Lag oppdatert."); }
            },
            child: const Text("Lagre"),
          ),
        ],
      )),
    );
  }

  // ─── Sluttspill – visual bracket ──────────────────────────────────────────

  Widget _buildPlayoffsTab() {
    if (_selectedCategoryId == null) {
      return const Center(child: Text("Velg en klasse i menyen over."));
    }
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events, size: 64, color: AppColors.adminOrange),
                  const SizedBox(height: 16),
                  const Text("Sluttspill ikke generert ennå.",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adminText)),
                  const SizedBox(height: 8),
                  const Text(
                    "Gå til Grupper-fanen og trykk\n\"Generer Grupper\" for å sette opp hele turneringen.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.adminTextSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        final brackets = matches
            .map((m) => (m.data() as Map)['bracket'] as String?)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();

        return DefaultTabController(
          length: brackets.isEmpty ? 1 : brackets.length,
          child: Column(
            children: [
              // Sync-knapp øverst
              Container(
                color: AppColors.adminSurface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    const Text("Oppdateres automatisk etter hvert som kamper spilles",
                        style: TextStyle(fontSize: 11, color: AppColors.adminTextSecondary)),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.sync, size: 15, color: AppColors.adminOrange),
                      label: const Text("Sync", style: TextStyle(color: AppColors.adminOrange, fontSize: 12)),
                      onPressed: () async {
                        await _resolvePendingMatches();
                        _snack("Bracket synkronisert.");
                      },
                    ),
                  ],
                ),
              ),
              Container(
                color: AppColors.adminSurface,
                child: TabBar(
                  indicatorColor: AppColors.adminOrange,
                  labelColor: AppColors.adminText,
                  unselectedLabelColor: AppColors.adminTextSecondary,
                  tabs: brackets.map((b) => Tab(
                    icon: Icon(
                      b == 'A' ? Icons.emoji_events
                          : b == 'B' ? Icons.workspace_premium
                          : Icons.military_tech,
                      size: 16,
                    ),
                    text: "$b-Bracket",
                  )).toList(),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: brackets.map((b) {
                    final bMatches = matches
                        .where((m) => (m.data() as Map)['bracket'] == b)
                        .toList();
                    return _buildVisualBracket(b, bMatches);
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisualBracket(String bracket, List<DocumentSnapshot> matches) {
    if (matches.isEmpty) {
      return const Center(child: Text("Ingen kamper.", style: TextStyle(color: AppColors.adminTextSecondary)));
    }

    const double cardW = 200.0;
    const double cardH = 68.0;
    const double colGap = 44.0;
    const double cardGap = 16.0;
    const double headerH = 28.0;

    final Map<String, List<DocumentSnapshot>> byRound = {};
    for (final m in matches) {
      final r = (m.data() as Map)['round'] as String? ?? '';
      byRound.putIfAbsent(r, () => []).add(m);
    }
    for (final r in byRound.keys) {
      byRound[r]!.sort((a, b) =>
          ((a.data() as Map)['match_number'] as int? ?? 0)
              .compareTo((b.data() as Map)['match_number'] as int? ?? 0));
    }

    const roundOrder = ['r16', 'qf', 'sf', 'final'];
    final allRounds = roundOrder.where((r) => byRound.containsKey(r)).toList();
    if (allRounds.isEmpty) return const SizedBox.shrink();

    final firstCount = byRound[allRounds.first]!.length;
    final unitH = cardH + cardGap;
    final bracketH = firstCount * unitH - cardGap;

    double centerY(int ri, int mi) {
      final sp = 1 << ri;
      return (mi * sp + sp * 0.5) * unitH - cardGap * 0.5;
    }

    final Map<int, Offset> pos = {};
    for (int ri = 0; ri < allRounds.length; ri++) {
      for (int mi = 0; mi < byRound[allRounds[ri]]!.length; mi++) {
        final num = (byRound[allRounds[ri]]![mi].data() as Map)['match_number'] as int? ?? 0;
        pos[num] = Offset(
          ri * (cardW + colGap),
          headerH + centerY(ri, mi) - cardH * 0.5,
        );
      }
    }

    final totalW = allRounds.length * cardW + (allRounds.length - 1) * colGap + 16;
    final totalH = headerH + bracketH + 24;

    const roundLabels = {
      'r16': 'R16', 'qf': 'KVARTFINALE', 'sf': 'SEMIFINALE', 'final': 'FINALE'
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SizedBox(
          width: totalW,
          height: totalH,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _BracketPainter(
                    pos: pos,
                    byRound: byRound,
                    allRounds: allRounds,
                    cardW: cardW,
                    cardH: cardH,
                    colGap: colGap,
                  ),
                ),
              ),
              for (int ri = 0; ri < allRounds.length; ri++)
                Positioned(
                  left: ri * (cardW + colGap),
                  top: 0, width: cardW, height: headerH,
                  child: Center(
                    child: Text(
                      roundLabels[allRounds[ri]] ?? allRounds[ri].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10,
                          color: AppColors.adminOrange, letterSpacing: 0.8),
                    ),
                  ),
                ),
              for (final m in matches)
                Builder(builder: (_) {
                  final d = m.data() as Map<String, dynamic>;
                  final num = d['match_number'] as int? ?? 0;
                  final p = pos[num];
                  if (p == null) return const SizedBox.shrink();
                  return Positioned(
                    left: p.dx, top: p.dy, width: cardW, height: cardH,
                    child: GestureDetector(
                      onTap: () => _showMatchEditDialog(m),
                      child: _bracketCard(d),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bracketCard(Map<String, dynamic> d) {
    final status = d['status'] as String? ?? 'pending';
    final isFinished = status == 'finished';
    final isAPH = (d['team_a_id'] as String? ?? '') == 'placeholder';
    final isBPH = (d['team_b_id'] as String? ?? '') == 'placeholder';
    final isPending = isAPH || isBPH || status == 'pending';
    final homeScore = d['home_score'] as int? ?? 0;
    final awayScore = d['away_score'] as int? ?? 0;
    final homeWins = isFinished && homeScore > awayScore;
    final awayWins = isFinished && awayScore > homeScore;

    Widget row(String name, bool wins, int score, bool isPH) => Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: wins ? AppColors.green.withOpacity(0.12) : Colors.transparent,
      child: Row(children: [
        Expanded(
          child: Text(
            name.isEmpty ? 'TBD' : name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: wins ? FontWeight.bold : FontWeight.normal,
              color: isPH ? AppColors.adminTextSecondary
                  : (wins ? AppColors.green : AppColors.adminText),
              fontStyle: isPH ? FontStyle.italic : FontStyle.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isFinished)
          Text('$score', style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold,
            color: wins ? AppColors.green : AppColors.adminTextSecondary,
          )),
      ]),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.adminSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isFinished ? AppColors.green.withOpacity(0.4)
              : isPending ? AppColors.adminSurfaceElevated.withOpacity(0.5)
              : AppColors.adminSurfaceElevated,
          width: isFinished ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 3, offset: const Offset(0, 1))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row(d['team_a_name'] as String? ?? 'TBD', homeWins, homeScore, isAPH),
            Container(height: 1, color: AppColors.adminSurfaceElevated),
            row(d['team_b_name'] as String? ?? 'TBD', awayWins, awayScore, isBPH),
            Container(
              height: 12,
              color: AppColors.adminSurfaceElevated,
              alignment: Alignment.center,
              child: Text(
                isFinished ? '$homeScore – $awayScore'
                    : (d['match_time'] as String? ?? (isPending ? 'Venter...' : 'Planlagt')),
                style: TextStyle(
                  fontSize: 8,
                  color: isFinished ? AppColors.green
                      : isPending ? AppColors.adminTextSecondary
                      : AppColors.adminOrange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Program-fanen – Tournify-stil kampskjema ──────────────────────────────

  Widget _buildScheduleTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('tournament_id', isEqualTo: widget.tournamentId)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final allMatches = snap.data!.docs;

        if (allMatches.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule, size: 56, color: AppColors.adminOrange),
                  const SizedBox(height: 16),
                  const Text("Ingen kamper planlagt enda.",
                      style: TextStyle(color: AppColors.adminText, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    "Generer grupper og sett kamptider via Auto-skjema.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.adminTextSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('tournaments').doc(widget.tournamentId).snapshots(),
                    builder: (ctx2, tSnap) {
                      final td = tSnap.data?.data() as Map<String, dynamic>? ?? {};
                      return ElevatedButton.icon(
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text("Auto-skjema"),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => TournamentSchedulePage(
                            tournamentId: widget.tournamentId,
                            tournamentName: widget.tournamentName,
                            courtsCount: (td['courts_count'] as num?)?.toInt() ?? 4,
                            matchDurationMinutes: (td['match_duration_minutes'] as num?)?.toInt() ?? 60,
                          ),
                        )),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }

        final sorted = List<DocumentSnapshot>.from(allMatches)
          ..sort((a, b) {
            final am = (a.data() as Map)['scheduled_minutes'] as int? ?? 9999;
            final bm = (b.data() as Map)['scheduled_minutes'] as int? ?? 9999;
            if (am != bm) return am.compareTo(bm);
            final ac = (a.data() as Map)['court'] as String? ?? '';
            final bc = (b.data() as Map)['court'] as String? ?? '';
            return ac.compareTo(bc);
          });

        final Map<String, List<DocumentSnapshot>> byDate = {};
        for (final m in sorted) {
          final date = (m.data() as Map)['match_date'] as String? ?? 'Kampdag';
          byDate.putIfAbsent(date, () => []).add(m);
        }
        final sortedDates = byDate.keys.toList()..sort();

        return Column(
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('tournaments').doc(widget.tournamentId).snapshots(),
              builder: (ctx2, tSnap) {
                final td = tSnap.data?.data() as Map<String, dynamic>? ?? {};
                return Container(
                  color: AppColors.adminSurface,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Text("Kampprogram", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.adminText)),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.auto_fix_high, size: 16, color: AppColors.adminOrange),
                        label: const Text("Auto-skjema", style: TextStyle(color: AppColors.adminOrange, fontSize: 13)),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => TournamentSchedulePage(
                            tournamentId: widget.tournamentId,
                            tournamentName: widget.tournamentName,
                            courtsCount: (td['courts_count'] as num?)?.toInt() ?? 4,
                            matchDurationMinutes: (td['match_duration_minutes'] as num?)?.toInt() ?? 60,
                          ),
                        )),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: sortedDates.length,
                itemBuilder: (ctx, i) =>
                    _buildDaySection(sortedDates[i], byDate[sortedDates[i]]!),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDaySection(String date, List<DocumentSnapshot> matches) {
    final Map<String, List<DocumentSnapshot>> byTime = {};
    for (final m in matches) {
      final time = (m.data() as Map)['match_time'] as String? ?? '--:--';
      byTime.putIfAbsent(time, () => []).add(m);
    }
    final sortedTimes = byTime.keys.toList()..sort();

    final finished = matches.where((m) => (m.data() as Map)['status'] == 'finished').length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.adminText)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("$finished/${matches.length}",
                style: TextStyle(
                    fontSize: 12,
                    color: finished == matches.length ? AppColors.green : AppColors.adminTextSecondary)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, color: AppColors.adminTextSecondary),
          ],
        ),
        children: [
          for (final time in sortedTimes) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.adminSurfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(time,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.adminOrange)),
                  ),
                  Expanded(child: Container(height: 1, margin: const EdgeInsets.only(left: 10), color: AppColors.adminSurfaceElevated)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Wrap(
                spacing: 8, runSpacing: 8,
                children: byTime[time]!.map(_buildScheduleCard).toList(),
              ),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(DocumentSnapshot matchDoc) {
    final d = matchDoc.data() as Map<String, dynamic>;
    final stage = d['stage'] as String? ?? '';
    final group = d['group'] as String?;
    final bracket = d['bracket'] as String?;
    final round = d['round'] as String?;
    final court = d['court'] as String? ?? 'TBD';
    final status = d['status'] as String? ?? 'scheduled';
    final isFinished = status == 'finished';
    final isLive = status == 'live';
    final isPending = status == 'pending';
    final isWalkover = d['walkover'] as bool? ?? false;

    String stageLabel = '';
    if (stage == 'group') {
      final mType = d['match_type'] as String? ?? '';
      final matchLabel = {'group_match_1':' – K1','group_match_2':' – K2','group_match_3':' – K3','group_match_4':' – K4'}[mType] ?? '';
      stageLabel = 'Pulje $group$matchLabel';
    }
    if (stage == 'playoff') {
      final bl = bracket?.toUpperCase() ?? '';
      final rl = const {'r16':'R16','qf':'KF','sf':'SF','final':'Finale'}[round] ?? '';
      stageLabel = '$bl-Bracket $rl';
    }

    final teamA = d['team_a_name'] as String? ?? 'TBD';
    final teamB = d['team_b_name'] as String? ?? 'TBD';
    final homeScore = d['home_score'] as int? ?? 0;
    final awayScore = d['away_score'] as int? ?? 0;
    final homeWins = isFinished && homeScore > awayScore;
    final awayWins = isFinished && awayScore > homeScore;

    Color statusColor = AppColors.adminTextSecondary;
    String statusLabel = 'Planlagt';
    if (isLive) { statusColor = AppColors.coral; statusLabel = '● LIVE'; }
    else if (isFinished) { statusColor = AppColors.green; statusLabel = isWalkover ? 'Walkover' : 'Ferdig'; }
    else if (isPending) statusLabel = 'Venter...';

    Widget teamRow(String name, bool wins, int? score) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(children: [
        Icon(Icons.sports_volleyball, size: 12,
            color: wins ? AppColors.adminText : AppColors.adminTextSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(name,
              style: TextStyle(
                  fontSize: 12, fontWeight: wins ? FontWeight.bold : FontWeight.normal,
                  color: wins ? AppColors.adminText : AppColors.adminTextSecondary),
              overflow: TextOverflow.ellipsis),
        ),
        if (score != null)
          Text('$score', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold,
              color: wins ? AppColors.adminText : AppColors.adminTextSecondary)),
      ]),
    );

    return GestureDetector(
      onTap: () => _showMatchEditDialog(matchDoc),
      child: Container(
        width: 215,
        decoration: BoxDecoration(
          color: AppColors.adminSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isLive ? AppColors.coral.withOpacity(0.6)
                : isFinished ? AppColors.green.withOpacity(0.25)
                : AppColors.adminSurfaceElevated,
            width: isLive ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 5),
              child: Row(children: [
                Expanded(
                  child: Text(stageLabel,
                      style: const TextStyle(fontSize: 10, color: AppColors.adminTextSecondary, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.adminSurfaceElevated, borderRadius: BorderRadius.circular(4)),
                  child: Text(court,
                      style: const TextStyle(fontSize: 9, color: AppColors.adminOrange, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
            Container(height: 1, color: AppColors.adminSurfaceElevated),
            teamRow(teamA, homeWins, isFinished ? homeScore : null),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(
                isFinished ? '$homeScore  –  $awayScore' : (d['match_time'] as String? ?? ''),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isFinished ? 13 : 11, fontWeight: FontWeight.bold,
                  color: isFinished ? AppColors.green : AppColors.adminOrange,
                ),
              ),
            ),
            teamRow(teamB, awayWins, isFinished ? awayScore : null),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: const BoxDecoration(
                color: AppColors.adminSurfaceElevated,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(statusLabel, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                const Icon(Icons.edit, size: 10, color: AppColors.adminTextSecondary),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ─── UI shell ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin: ${widget.tournamentName}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.how_to_reg),
            tooltip: "Påmeldinger",
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => RegistrationsPage(
                tournamentId: widget.tournamentId,
                tournamentName: widget.tournamentName,
                tournamentType: 'nt_master',
              ),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: "Rediger turnering",
            onPressed: () async {
              final doc = await FirebaseFirestore.instance
                  .collection('tournaments').doc(widget.tournamentId).get();
              if (!mounted) return;
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => EditTournamentPage(
                  tournamentId: widget.tournamentId,
                  initialData: doc.data() ?? {},
                ),
              ));
            },
          ),
          PopupMenuButton<String>(
            tooltip: "Avanserte handlinger",
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'sync') _resolvePendingMatches().then((_) => _snack("Synkronisert."));
              if (v == 'reset') _resetTournament();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'sync',
                child: ListTile(
                  leading: Icon(Icons.sync, color: AppColors.adminOrange),
                  title: Text("Sync bracket"),
                  subtitle: Text("Oppdater kryssninger manuelt", style: TextStyle(fontSize: 11)),
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'reset',
                child: ListTile(
                  leading: Icon(Icons.restart_alt, color: AppColors.adminOrange),
                  title: Text("Nullstill hele turneringen"),
                  subtitle: Text("Sletter alle kamper, beholder lag", style: TextStyle(fontSize: 11)),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.adminText,
          labelColor: AppColors.adminText,
          unselectedLabelColor: AppColors.adminTextSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.groups), text: "Lag"),
            Tab(icon: Icon(Icons.grid_view), text: "Grupper"),
            Tab(icon: Icon(Icons.emoji_events), text: "Sluttspill"),
            Tab(icon: Icon(Icons.schedule), text: "Program"),
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
                _buildScheduleTab(),
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
            )
          : null,
    );
  }

  // ─── Category selector ────────────────────────────────────────────────────

  Widget _buildCategorySelector() {
    return Container(
      color: AppColors.adminSurfaceElevated,
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
              child: Text("Ingen klasser funnet.", style: TextStyle(color: AppColors.adminOrange)),
            );
          }

          if (_selectedCategoryId == null && cats.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() { _selectedCategoryId = cats.first.id; });
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
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.adminOrangeHover, foregroundColor: AppColors.adminText),
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
              if (teams.isEmpty) return const Center(
                  child: Text("Ingen lag registrert enda.\nTrykk + for å legge til lag.",
                      textAlign: TextAlign.center));

              final sorted = List<DocumentSnapshot>.from(teams)
                ..sort((a, b) {
                  final as_ = (a.data() as Map)['seed'] as int? ?? 999;
                  final bs  = (b.data() as Map)['seed'] as int? ?? 999;
                  final ap  = (a.data() as Map)['team_points'] as num? ?? 0;
                  final bp  = (b.data() as Map)['team_points'] as num? ?? 0;
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
                        backgroundColor: seed != null ? AppColors.adminSurfaceElevated : AppColors.adminTextSecondary,
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
                              backgroundColor: AppColors.adminSurfaceElevated,
                              visualDensity: VisualDensity.compact,
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: AppColors.adminOrange),
                            tooltip: "Rediger / Flytt",
                            onPressed: () => _showTeamEditDialog(sorted[i]),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: AppColors.adminOrange),
                            onPressed: () => _confirmDeleteTeam(
                                sorted[i].id, d['team_name'] ?? 'laget'),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.emoji_events, size: 16),
              label: const Text("Generer Grupper + Sluttspill"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              onPressed: _generateGroupStage,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: const Text(
            "Trykk én gang – setter opp grupper, runde 2 og sluttspillkryssninger automatisk.",
            style: TextStyle(fontSize: 11, color: AppColors.adminTextSecondary),
            textAlign: TextAlign.center,
          ),
        ),
        const Divider(height: 1),
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

        final groupNames = allTeams
            .map((t) => (t.data() as Map)['group'] as String?)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();

        if (groupNames.isEmpty) {
          return const Center(
            child: Text("Ingen grupper ennå.\nTrykk \"Generer Grupper + Sluttspill\" over.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.adminTextSecondary)),
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
                final gn = groupNames[i];
                final groupTeams = allTeams
                    .where((t) => (t.data() as Map)['group'] == gn)
                    .toList()
                  ..sort((a, b) {
                    final ap = (a.data() as Map)['group_placement'] as int? ?? 99;
                    final bp = (b.data() as Map)['group_placement'] as int? ?? 99;
                    if (ap != 99 || bp != 99) return ap.compareTo(bp);
                    final as_ = (a.data() as Map)['seed'] as int? ?? 99;
                    final bs  = (b.data() as Map)['seed'] as int? ?? 99;
                    return as_.compareTo(bs);
                  });

                final groupMatches = allMatches
                    .where((m) => (m.data() as Map)['group'] == gn)
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
                        decoration: const BoxDecoration(
                          color: AppColors.adminSurfaceElevated,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: Text("Pulje $gn",
                            style: const TextStyle(color: AppColors.adminText,
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      ...groupTeams.asMap().entries.map((e) {
                        final idx = e.key;
                        final d = e.value.data() as Map<String, dynamic>;
                        final placement = d['group_placement'] as int?;
                        final seed = d['seed'] as int?;
                        final placeBgColors = [
                          Colors.amber[700]!, AppColors.adminTextSecondary,
                          Colors.brown[400]!, AppColors.adminTextSecondary
                        ];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: placement != null && placement <= 4
                                ? placeBgColors[placement - 1]
                                : AppColors.adminSurfaceElevated,
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: Text("KAMPER",
                            style: TextStyle(fontSize: 11, color: AppColors.adminTextSecondary,
                                fontWeight: FontWeight.bold)),
                      ),
                      if (groupMatches.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text("Ingen kamper enda.",
                              style: TextStyle(color: AppColors.adminTextSecondary)),
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
    final isPending  = status == 'pending';
    final isPlaceholder = d['team_a_id'] == 'placeholder' || d['team_b_id'] == 'placeholder';

    const labels = {
      'group_match_1': 'Kamp 1 (S1 vs S4)',
      'group_match_2': 'Kamp 2 (S2 vs S3)',
      'group_match_3': 'Vinnerkamp → 1./2.',
      'group_match_4': 'Taperkamp → 3./4.',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(labels[mType] ?? mType,
                    style: const TextStyle(fontSize: 10, color: AppColors.adminTextSecondary,
                        fontWeight: FontWeight.bold)),
                Text(
                  "${d['team_a_name'] ?? 'TBD'} vs ${d['team_b_name'] ?? 'TBD'}",
                  style: TextStyle(
                    fontSize: 13,
                    color: isPending ? AppColors.adminTextSecondary : AppColors.adminText,
                    fontStyle: isPending ? FontStyle.italic : FontStyle.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (isFinished)
                  Text("${d['home_score']} – ${d['away_score']}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.green)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isFinished ? AppColors.green.withOpacity(0.2)
                  : status == 'live' ? AppColors.adminOrange.withOpacity(0.2)
                  : isPending ? Colors.transparent
                  : AppColors.adminSurfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: isPending ? Border.all(color: AppColors.adminSurfaceElevated) : null,
            ),
            child: Text(
              isFinished ? 'Ferdig' : status == 'live' ? 'LIVE' : isPending ? 'Venter' : 'Planlagt',
              style: TextStyle(
                fontSize: 10,
                color: isFinished ? AppColors.green
                    : status == 'live' ? AppColors.adminOrangeHover
                    : AppColors.adminTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (!isPending) ...[
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: AppColors.adminTextSecondary),
              tooltip: "Rediger kamp",
              onPressed: () => _showMatchEditDialog(matchDoc),
            ),
            IconButton(
              icon: const Icon(Icons.qr_code, size: 20),
              tooltip: "Vis QR",
              onPressed: () => _showQrDialog(
                  matchDoc.id, d['team_a_name'] ?? 'A', d['team_b_name'] ?? 'B'),
            ),
            IconButton(
              icon: Icon(Icons.sports_esports, size: 20,
                  color: isPlaceholder ? AppColors.adminTextSecondary : AppColors.green),
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
        ],
      ),
    );
  }
}

// ─── Bracket line painter ──────────────────────────────────────────────────

class _BracketPainter extends CustomPainter {
  final Map<int, Offset> pos;
  final Map<String, List<DocumentSnapshot>> byRound;
  final List<String> allRounds;
  final double cardW, cardH, colGap;

  const _BracketPainter({
    required this.pos,
    required this.byRound,
    required this.allRounds,
    required this.cardW,
    required this.cardH,
    required this.colGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E2E54)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int ri = 0; ri < allRounds.length - 1; ri++) {
      final curMs  = byRound[allRounds[ri]]!;
      final nextMs = byRound[allRounds[ri + 1]]!;
      final midXOffset = cardW + colGap / 2;

      for (int mi = 0; mi < curMs.length; mi += 2) {
        final n1 = (curMs[mi].data() as Map)['match_number'] as int? ?? 0;
        final p1 = pos[n1];
        if (p1 == null) continue;
        final cy1 = p1.dy + cardH / 2;
        final midX = p1.dx + midXOffset;

        canvas.drawLine(Offset(p1.dx + cardW, cy1), Offset(midX, cy1), paint);

        if (mi + 1 < curMs.length) {
          final n2 = (curMs[mi + 1].data() as Map)['match_number'] as int? ?? 0;
          final p2 = pos[n2];
          if (p2 == null) continue;
          final cy2 = p2.dy + cardH / 2;

          canvas.drawLine(Offset(p2.dx + cardW, cy2), Offset(midX, cy2), paint);
          canvas.drawLine(Offset(midX, cy1), Offset(midX, cy2), paint);

          final nextIdx = mi ~/ 2;
          if (nextIdx < nextMs.length) {
            final nN = (nextMs[nextIdx].data() as Map)['match_number'] as int? ?? 0;
            final pN = pos[nN];
            if (pN != null) {
              final cyN = pN.dy + cardH / 2;
              canvas.drawLine(Offset(midX, cyN), Offset(pN.dx, cyN), paint);
            }
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
