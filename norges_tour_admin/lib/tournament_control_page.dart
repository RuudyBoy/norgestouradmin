import 'dart:async';
import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'match_control_page.dart';
import 'registrations_page.dart';
import 'edit_tournament_page.dart';
import 'schedule_logic.dart';

import 'theme/app_colors.dart';
import 'theme/responsive_layout.dart';

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

class _TournamentControlPageState extends State<TournamentControlPage> {
  String? _selectedCategoryId;

  // Filtre for Kamper-fanen
  String _selectedStatusFilter = 'alle';
  String _selectedRoundFilter = 'alle';
  String _selectedCourtFilter = 'alle';

  // Filtre for Oppsett-fanen
  String _oppsettStageFilter = 'alle';
  String _oppsettGroupFilter = 'alle';
  String _oppsettCourtFilter = 'alle';
  String _selectedOppsettTab = 'Gruppespill';

  // Lytter på Firestore – oppdager når livescore-appen registrerer resultater
  StreamSubscription<QuerySnapshot>? _finishedMatchListener;
  Set<String> _knownFinishedIds = {};
  bool _listenerReady = false;

  // NavigationRail-indeks: 0=Oversikt 1=Kampprogram 2=Oppsett 3=Lag
  int _selectedNavIndex = 2;

  // Seeding-bytte: lagrer det valgte laget (første klikk)
  DocumentSnapshot? _swapSelectionDoc;

  @override
  void initState() {
    super.initState();
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
        // En eller flere kamper ble nettopp avsluttet av livescore-appen.
        // Resolve for klassene kampene tilhører – ikke bare valgt klasse.
        final affectedCategories = snapshot.docs
            .where((d) => newlyFinished.contains(d.id))
            .map((d) => d.data()['category_id'] as String?)
            .whereType<String>()
            .toSet();
        for (final catId in affectedCategories) {
          _resolvePendingMatches(categoryId: catId);
        }
      }
    });
  }

  @override
  void dispose() {
    _finishedMatchListener?.cancel();
    super.dispose();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.adminPrimaryHover : null,
    ));
  }

  Query<Map<String, dynamic>> _matchesQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('matches').where('tournament_id', isEqualTo: widget.tournamentId);
    if (_selectedCategoryId != 'all' && _selectedCategoryId != null) {
      q = q.where('category_id', isEqualTo: _selectedCategoryId);
    }
    return q;
  }

  Query<Map<String, dynamic>> _teamsQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('teams').where('tournament_id', isEqualTo: widget.tournamentId);
    if (_selectedCategoryId != 'all' && _selectedCategoryId != null) {
      q = q.where('category_id', isEqualTo: _selectedCategoryId);
    }
    return q;
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
    if (_selectedCategoryId == null || _selectedCategoryId == 'all') { _snack("Velg en spesifikk klasse."); return; }

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
                onPressed: () async {
                  if (p1Id == null || p2Id == null) { _snack("Velg begge spillere!"); return; }
                  if (p1Id == p2Id) { _snack("Velg to forskjellige spillere!"); return; }
                  
                  final p1Data = docs.firstWhere((d) => d.id == p1Id).data() as Map<String, dynamic>;
                  final p2Data = docs.firstWhere((d) => d.id == p2Id).data() as Map<String, dynamic>;
                  
                  // Validate gender
                  if (_selectedCategoryId != null) {
                    final catSnap = await FirebaseFirestore.instance.collection('categories').doc(_selectedCategoryId).get();
                    if (catSnap.exists) {
                      final catData = catSnap.data() as Map<String, dynamic>;
                      final catGender = catData['gender'] ?? 'Mix';
                      if (catGender != 'Mix') {
                        final g1 = p1Data['gender'] ?? 'M';
                        final g2 = p2Data['gender'] ?? 'M';
                        if (g1 != catGender || g2 != catGender) {
                          _snack("Feil: Begge spillere må være ${catGender == 'M' ? 'menn' : 'kvinner'} for denne klassen!", isError: true);
                          return;
                        }
                      }
                    }
                  }

                  final messenger = ScaffoldMessenger.of(context);
                  if (ctx.mounted) Navigator.pop(ctx);

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
    if (_selectedCategoryId == null || _selectedCategoryId == 'all') { _snack("Velg en spesifikk klasse."); return; }
    
    final catSnap = await FirebaseFirestore.instance.collection('categories').doc(_selectedCategoryId).get();
    final catGender = catSnap.data()?['gender'] ?? 'Mix';

    final snap = await FirebaseFirestore.instance.collection('players').get();
    var players = snap.docs.toList();
    
    if (catGender != 'Mix') {
      players = players.where((p) => (p.data()['gender'] ?? 'M') == catGender).toList();
    }
    players.shuffle();

    if (players.length < 32) {
      _snack("Trenger minst 32 spillere av riktig kjønn i databasen (har ${players.length}).", isError: true);
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
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminPrimary, foregroundColor: AppColors.adminText),
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              SizedBox(height: 200, width: 200, child: QrImageView(data: url, version: QrVersions.auto, size: 200)),
              const SizedBox(height: 12),
              SelectableText(url, style: const TextStyle(fontSize: 10, color: AppColors.adminSurface)),
            ],
          ),
        ),
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

    // Auto-schedule if tournament has start_time configured
    final tourDoc = await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .get();
    final td = tourDoc.data() ?? {};
    final startTimeStr = td['start_time'] as String?;
    if (startTimeStr != null && _selectedCategoryId != null) {
      final parts = startTimeStr.split(':');
      if (parts.length == 2) {
        final startMinutes = (int.tryParse(parts[0]) ?? 9) * 60 + (int.tryParse(parts[1]) ?? 0);
        final duration = (td['match_duration_minutes'] as num?)?.toInt() ?? 60;
        final courts = (td['courts_count'] as num?)?.toInt() ?? 4;
        final startDate = td['start_date'] as String? ?? 'Kampdag';
        final endDate = td['end_date'] as String? ?? startDate;
        await _autoScheduleForCategory(
          _selectedCategoryId!,
          startMinutes: startMinutes,
          matchDurationMinutes: duration,
          courtsCount: courts,
          startDate: startDate,
          endDate: endDate,
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

  // ─── Auto-schedule helpers ────────────────────────────────────────────────

  static int _matchRoundOrder(Map d) {
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

  static String _fmtMinutes(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

    Future<void> _autoScheduleForCategory(
    String categoryId, {
    required int startMinutes,
    required int matchDurationMinutes,
    required int courtsCount,
    required String startDate,
    required String endDate,
    int breakBetweenRounds = 5,
  }) =>
      autoScheduleCategory(
        tournamentId: widget.tournamentId,
        categoryId: categoryId,
        startMinutes: startMinutes,
        matchDurationMinutes: matchDurationMinutes,
        courtsCount: courtsCount,
        startDate: startDate,
        endDate: endDate,
        breakBetweenRounds: breakBetweenRounds,
      );

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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminPrimary, foregroundColor: AppColors.adminText),
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
                icon: const Icon(Icons.flag, color: AppColors.adminPrimary),
                label: const Text("Walkover – Lag A vinner",
                    style: TextStyle(color: AppColors.adminPrimary)),
                onPressed: () async {
                  await matchDoc.reference.update({
                    'status': 'finished', 'home_score': 1, 'away_score': 0, 'walkover': true,
                  });
                  await _resolvePendingMatches(categoryId: d['category_id'] as String?);
                  if (ctx.mounted) { Navigator.pop(ctx); _snack("Walkover – Lag A vinner."); }
                },
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                icon: const Icon(Icons.flag, color: AppColors.adminPrimary),
                label: const Text("Walkover – Lag B vinner",
                    style: TextStyle(color: AppColors.adminPrimary)),
                onPressed: () async {
                  await matchDoc.reference.update({
                    'status': 'finished', 'home_score': 0, 'away_score': 1, 'walkover': true,
                  });
                  await _resolvePendingMatches(categoryId: d['category_id'] as String?);
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
              if (isFinished) await _resolvePendingMatches(categoryId: d['category_id'] as String?);
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

    final groupsSnap = await _teamsQuery()
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
                initialValue: selectedGroup != null && allGroups.contains(selectedGroup) ? selectedGroup : null,
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
                updates['group'] = selectedGroup ?? FieldValue.delete();
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

  String _resolveTeamDisplayName(Map<String, dynamic> d, String prefix, Map<String, int> matchNumById) {
    final id = d['${prefix}_id'] as String? ?? '';
    final name = d['${prefix}_name'] as String? ?? 'TBD';
    if (id != 'placeholder') return name;
    final fromMatchId = d['${prefix}_from_match_id'] as String?;
    final fromSlot = d['${prefix}_from_slot'] as String?;
    if (fromMatchId != null && fromSlot != null) {
      final num = matchNumById[fromMatchId];
      if (num != null) {
        return fromSlot == 'winner' ? 'Vinner kamp $num' : 'Taper kamp $num';
      }
    }
    return name;
  }

  // (Visual bracket removed — see _buildOppsettWrapper for the new unified view)
  Widget _buildPlayoffsTab_UNUSED() {
    if (_selectedCategoryId == null) {
      return const Center(child: Text("Velg en klasse i menyen over."));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _matchesQuery()
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
                  const Icon(Icons.emoji_events, size: 64, color: AppColors.adminPrimary),
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

        const bracketOrder = ['A', 'B', 'C', 'D'];
        final brackets = matches
            .map((m) => (m.data() as Map)['bracket'] as String?)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort((a, b) {
            final ai = bracketOrder.indexOf(a);
            final bi = bracketOrder.indexOf(b);
            if (ai < 0 && bi < 0) return a.compareTo(b);
            if (ai < 0) return 1;
            if (bi < 0) return -1;
            return ai.compareTo(bi);
          });

        final matchNumById = <String, int>{};
        for (final m in matches) {
          final num = (m.data() as Map)['match_number'] as int?;
          if (num != null) matchNumById[m.id] = num;
        }

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
                    Expanded(
                      child: const Text("Oppdateres automatisk etter hvert som kamper spilles",
                          style: TextStyle(fontSize: 11, color: AppColors.adminTextSecondary)),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.sync, size: 15, color: AppColors.adminPrimary),
                      label: const Text("Sync", style: TextStyle(color: AppColors.adminPrimary, fontSize: 12)),
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
                  indicatorColor: AppColors.adminPrimary,
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
                    return _buildVisualBracket(b, bMatches, matchNumById);
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisualBracket(String bracket, List<DocumentSnapshot> matches, Map<String, int> matchNumById) {
    if (matches.isEmpty) {
      return const Center(child: Text("Ingen kamper.", style: TextStyle(color: AppColors.adminTextSecondary)));
    }

    const double cardW = 210.0;
    const double cardH = 92.0;
    const double colGap = 14.0;   // horizontal gap between sibling cards
    const double rowGap = 36.0;   // vertical gap between rounds
    const double pad    = 16.0;
    const double labelH = 24.0;   // height of round label above each row

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

    // Rounds from earliest to latest (r16 → final)
    const orderList = ['omspill', 'r16', 'r8', 'qf', 'sf', 'final'];
    final bottomToTop = orderList.where((r) => byRound.containsKey(r)).toList();
    if (bottomToTop.isEmpty) return const SizedBox.shrink();

    // Display order: final at row 0 (top), earliest round at last row (bottom)
    final topToBottom = bottomToTop.reversed.toList();

    // Widest round determines total width
    final M = byRound.values.map((l) => l.length).reduce(max);
    final innerW = M * cardW + (M - 1) * colGap;
    final totalW = innerW + 2 * pad;
    final totalH = pad + topToBottom.length * (labelH + cardH) +
        (topToBottom.length - 1) * rowGap + pad;

    // Position each card (top-left corner)
    final Map<int, Offset> pos = {};
    for (int ri = 0; ri < topToBottom.length; ri++) {
      final round = topToBottom[ri];
      final n = byRound[round]!.length;
      final slotW = innerW / n;
      for (int mi = 0; mi < n; mi++) {
        final cx = pad + (mi + 0.5) * slotW - cardW / 2;
        final cy = pad + ri * (labelH + cardH + rowGap) + labelH;
        final num = (byRound[round]![mi].data() as Map)['match_number'] as int? ?? 0;
        pos[num] = Offset(cx, cy);
      }
    }

    const roundLabels = {
      'omspill': 'PLAYOFF', 'r16': '1/16', 'r8': '1/8',
      'qf': 'KVARTFINALE', 'sf': 'SEMIFINALE', 'final': 'FINALE',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SizedBox(
          width: totalW,
          height: totalH,
          child: Stack(
            children: [
              // Connector lines
              Positioned.fill(
                child: CustomPaint(
                  painter: _BracketPainterTopDown(
                    pos: pos, byRound: byRound, topToBottom: topToBottom,
                    cardW: cardW, cardH: cardH, innerW: innerW,
                    pad: pad, labelH: labelH, rowGap: rowGap,
                  ),
                ),
              ),
              // Round labels (above each row, centered)
              for (int ri = 0; ri < topToBottom.length; ri++)
                Positioned(
                  left: 0, right: 0,
                  top: pad + ri * (labelH + cardH + rowGap),
                  height: labelH,
                  child: Center(
                    child: Text(
                      roundLabels[topToBottom[ri]] ?? topToBottom[ri].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10,
                          color: AppColors.adminPrimary, letterSpacing: 0.8),
                    ),
                  ),
                ),
              // Match cards
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
                      child: _bracketCard(d, matchNumById),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bracketCard(Map<String, dynamic> d, Map<String, int> matchNumById) {
    final num = d['match_number'] as int?;
    final matchTime = d['match_time'] as String?;
    final status = d['status'] as String? ?? 'pending';
    final isFinished = status == 'finished';
    final isAPH = (d['team_a_id'] as String? ?? '') == 'placeholder';
    final isBPH = (d['team_b_id'] as String? ?? '') == 'placeholder';
    final isPending = isAPH || isBPH || status == 'pending';
    final homeScore = d['home_score'] as int? ?? 0;
    final awayScore = d['away_score'] as int? ?? 0;
    final homeWins = isFinished && homeScore > awayScore;
    final awayWins = isFinished && awayScore > homeScore;

    Widget teamRow(String name, bool wins, int score, bool isPH) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        color: wins ? AppColors.green.withValues(alpha: 0.12) : Colors.transparent,
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
              maxLines: 1,
            ),
          ),
          if (isFinished)
            Text('$score', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold,
              color: wins ? AppColors.green : AppColors.adminTextSecondary,
            )),
        ]),
      ),
    );

    final statusText = isPending ? 'Venter...' : (isFinished ? 'Ferdig' : 'Planlagt');
    final statusColor = isFinished ? AppColors.green
        : isPending ? AppColors.adminTextSecondary
        : AppColors.adminPrimary;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.adminSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isFinished ? AppColors.green.withValues(alpha: 0.4)
              : isPending ? AppColors.adminSurfaceElevated.withValues(alpha: 0.5)
              : AppColors.adminSurfaceElevated,
          width: isFinished ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 3, offset: const Offset(0, 1))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Column(
          children: [
            // Header: match number + time
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              color: AppColors.adminSurfaceElevated,
              child: Row(
                children: [
                  Text(
                    num != null ? 'Kamp $num' : '–',
                    style: const TextStyle(fontSize: 9, color: AppColors.adminPrimary, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (isFinished)
                    Text('$homeScore – $awayScore',
                        style: const TextStyle(fontSize: 9, color: AppColors.green, fontWeight: FontWeight.bold))
                  else if (matchTime != null)
                    Row(children: [
                      const Icon(Icons.access_time, size: 8, color: AppColors.adminTextSecondary),
                      const SizedBox(width: 2),
                      Text(matchTime, style: const TextStyle(fontSize: 9, color: AppColors.adminTextSecondary)),
                    ])
                  else
                    Text(isPending ? 'Venter...' : '–',
                        style: TextStyle(fontSize: 9, color: statusColor)),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.adminSurfaceElevated),
            teamRow(_resolveTeamDisplayName(d, 'team_a', matchNumById), homeWins, homeScore, isAPH),
            Container(height: 1, color: AppColors.adminSurfaceElevated),
            teamRow(_resolveTeamDisplayName(d, 'team_b', matchNumById), awayWins, awayScore, isBPH),
            Container(height: 1, color: AppColors.adminSurfaceElevated),
            Container(
              color: AppColors.adminSurfaceElevated,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                statusText,
                style: TextStyle(fontSize: 9, color: statusColor, fontWeight: FontWeight.w500),
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
      stream: FirebaseFirestore.instance.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
      builder: (ctx, catSnap) {
        if (!catSnap.hasData) return const Center(child: CircularProgressIndicator());
        final Map<String, String> catIdToName = {};
        for (var c in catSnap.data!.docs) {
          final data = c.data() as Map<String, dynamic>;
          catIdToName[c.id] = data['name'] ?? 'Ukjent';
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('matches')
              .where('tournament_id', isEqualTo: widget.tournamentId)
              .snapshots(),
          builder: (ctx2, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            var allMatches = snap.data!.docs;

            if (_selectedCategoryId != null && _selectedCategoryId != 'all') {
              allMatches = allMatches.where((m) => (m.data() as Map)['category_id'] == _selectedCategoryId).toList();
            }



        // Pakk ut unike runder og baner for filter-boblene
        final Set<String> rounds = {};
        final Set<String> courts = {};
        for (var m in allMatches) {
           final d = m.data() as Map<String, dynamic>;
           final court = d['court'] as String? ?? '';
           if (court.isNotEmpty) courts.add(court);
           
           final stage = d['stage'] as String? ?? '';
           if (stage == 'group') {
             final g = d['group'] as String? ?? '';
             if (g.isNotEmpty) rounds.add('Pulje $g');
           } else if (stage == 'playoff') {
             final r = d['round'] as String? ?? '';
             if (r == 'r16') {
               rounds.add('1/16');
             } else if (r == 'r8') rounds.add('1/8');
             else if (r == 'qf') rounds.add('Kvart');
             else if (r == 'sf') rounds.add('Semi');
             else if (r == 'final') rounds.add('Finale');
             else rounds.add('Playoff');
           }
        }
        final sortedRounds = rounds.toList()..sort();
        final sortedCourts = courts.toList()..sort((a, b) => a.compareTo(b));

        // Bruk filtrene
        if (_selectedStatusFilter != 'alle') {
           allMatches = allMatches.where((m) => (m.data() as Map)['status'] == _selectedStatusFilter).toList();
        }
        if (_selectedRoundFilter != 'alle') {
           allMatches = allMatches.where((m) {
             final d = m.data() as Map<String, dynamic>;
             final stage = d['stage'] as String? ?? '';
             String roundLabel = '';
             if (stage == 'group') {
               final g = d['group'] as String? ?? '';
               roundLabel = 'Pulje $g';
             } else if (stage == 'playoff') {
               final r = d['round'] as String? ?? '';
               if (r == 'r16') {
                 roundLabel = '1/16';
               } else if (r == 'r8') roundLabel = '1/8';
               else if (r == 'qf') roundLabel = 'Kvart';
               else if (r == 'sf') roundLabel = 'Semi';
               else if (r == 'final') roundLabel = 'Finale';
               else roundLabel = 'Playoff';
             }
             return roundLabel == _selectedRoundFilter;
           }).toList();
        }
        if (_selectedCourtFilter != 'alle') {
           allMatches = allMatches.where((m) => (m.data() as Map)['court'] == _selectedCourtFilter).toList();
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

        final matchNumById = <String, int>{};
        for (final m in allMatches) {
          final num = (m.data() as Map)['match_number'] as int?;
          if (num != null) matchNumById[m.id] = num;
        }

        final Map<String, List<DocumentSnapshot>> byDate = {};
        for (final m in sorted) {
          final date = (m.data() as Map)['match_date'] as String? ?? 'Kampdag';
          byDate.putIfAbsent(date, () => []).add(m);
        }
        final sortedDates = byDate.keys.toList()..sort();

        Widget filterChip(String label, String id, String currentVal, Function(String) onSelect) {
           final isSelected = id == currentVal;
           return Padding(
             padding: const EdgeInsets.only(right: 8),
             child: ChoiceChip(
               label: Text(label),
               selected: isSelected,
               onSelected: (v) { if(v) onSelect(id); },
               selectedColor: AppColors.coral,
               labelStyle: TextStyle(
                 color: isSelected ? Colors.white : AppColors.adminTextSecondary,
                 fontWeight: FontWeight.bold,
               ),
               backgroundColor: AppColors.adminSurface,
               side: BorderSide(color: isSelected ? AppColors.coral : AppColors.adminSurfaceElevated),
             ),
           );
        }

        return Column(
          children: [
            Container(
               color: AppColors.adminSurface,
               width: double.infinity,
               child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          _buildInlineCategoryFilter(),
                          const SizedBox(width: 8),
                          filterChip('Alle', 'alle', _selectedStatusFilter, (v) => setState(() => _selectedStatusFilter = v)),
                          filterChip('Live', 'live', _selectedStatusFilter, (v) => setState(() => _selectedStatusFilter = v)),
                          filterChip('Kommende', 'scheduled', _selectedStatusFilter, (v) => setState(() => _selectedStatusFilter = v)),
                          filterChip('Ferdig', 'finished', _selectedStatusFilter, (v) => setState(() => _selectedStatusFilter = v)),
                        ],
                      ),
                    ),
                    if (sortedRounds.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            filterChip('Alle runder', 'alle', _selectedRoundFilter, (v) => setState(() => _selectedRoundFilter = v)),
                            for (var r in sortedRounds)
                              filterChip(r, r, _selectedRoundFilter, (v) => setState(() => _selectedRoundFilter = v)),
                          ],
                        ),
                      ),
                    if (sortedCourts.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            filterChip('Alle baner', 'alle', _selectedCourtFilter, (v) => setState(() => _selectedCourtFilter = v)),
                            for (var c in sortedCourts)
                              filterChip(c, c, _selectedCourtFilter, (v) => setState(() => _selectedCourtFilter = v)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
               ),
            ),
            const Divider(height: 1),
            Expanded(
              child: sortedDates.isEmpty 
                  ? const Center(child: Text("Ingen kamper matcher filteret", style: TextStyle(color: AppColors.adminTextSecondary)))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: sortedDates.length,
                itemBuilder: (ctx, i) =>
                    _buildDaySection(sortedDates[i], byDate[sortedDates[i]]!, matchNumById, catIdToName),
              ),
            ),
          ],
        );
      },
    );
      },
    );
  }

  Widget _buildDaySection(String date, List<DocumentSnapshot> matches, Map<String, int> matchNumById, Map<String, String> catIdToName) {
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.adminPrimary)),
                  ),
                  Expanded(child: Container(height: 1, margin: const EdgeInsets.only(left: 10), color: AppColors.adminSurfaceElevated)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                children: byTime[time]!.map((m) => _buildScheduleCard(m, matchNumById, catIdToName)).toList(),
              ),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

    Widget _buildScheduleCard(DocumentSnapshot matchDoc, Map<String, int> matchNumById, Map<String, String> catIdToName) {
    final d = matchDoc.data() as Map<String, dynamic>;
    final matchNum = matchNumById[matchDoc.id] ?? (d['match_number'] as int?);
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
    
    final catId = d['category_id'] as String? ?? '';
    final catName = catIdToName[catId] ?? '';

    String stageLabel = catName.isNotEmpty ? '$catName - ' : '';
    if (stage == 'group') {
      final mType = d['match_type'] as String? ?? '';
      final matchLabel = {'group_match_1':' - K1','group_match_2':' - K2','group_match_3':' - K3','group_match_4':' - K4'}[mType] ?? '';
      stageLabel += 'Pulje $group$matchLabel';
    }
    if (stage == 'playoff') {
      final bl = bracket?.toUpperCase() ?? '';
      final rl = const {'r16':'R16','qf':'KF','sf':'SF','final':'Finale'}[round] ?? '';
      stageLabel += '$bl-Bracket $rl';
    }

    final teamA = _resolveTeamDisplayName(d, 'team_a', matchNumById);
    final teamB = _resolveTeamDisplayName(d, 'team_b', matchNumById);
    final homeScore = d['home_score'] as int? ?? 0;
    final awayScore = d['away_score'] as int? ?? 0;
    final homeWins = isFinished && homeScore > awayScore;
    final awayWins = isFinished && awayScore > homeScore;

    final matchTime = d['match_time'] as String? ?? '';
    final matchDate = d['match_date'] as String? ?? '';
    int? delayMinutes;
    if (status == 'scheduled' && matchTime.isNotEmpty && matchDate.isNotEmpty) {
      final parts = matchDate.split('.');
      final timeParts = matchTime.split(':');
      if (parts.length == 3 && timeParts.length == 2) {
        try {
          final scheduledDt = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]), int.parse(timeParts[0]), int.parse(timeParts[1]));
          final diff = DateTime.now().difference(scheduledDt).inMinutes;
          if (diff > 0) delayMinutes = diff;
        } catch (_) {}
      }
    }

    Color statusColor = AppColors.adminTextSecondary;
    String statusLabel = 'Planlagt';
    if (isLive) { statusColor = AppColors.coral; statusLabel = 'LIVE'; }
    else if (isFinished) { statusColor = AppColors.green; statusLabel = isWalkover ? 'Walkover' : 'Ferdig'; }
    else if (isPending) { statusLabel = 'Venter...'; }
    else if (delayMinutes != null && delayMinutes > 0) { statusColor = AppColors.adminPrimaryHover; statusLabel = '+${delayMinutes}min'; }

    Widget teamLine(String name, bool wins, int? score) => Row(children: [
      Expanded(child: Text(name, style: TextStyle(fontSize: 14, fontWeight: wins ? FontWeight.bold : FontWeight.w600, color: wins ? AppColors.adminText : AppColors.adminTextSecondary), overflow: TextOverflow.ellipsis)),
      if (score != null) Text('$score', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: wins ? AppColors.green : AppColors.adminTextSecondary)),
    ]);

    Widget infoChip(String text, {Color? color, bool filled = true}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: filled ? AppColors.adminSurfaceElevated : Colors.transparent, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 11, color: color ?? AppColors.adminTextSecondary, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
    );

    final accent = isLive ? AppColors.coral : isFinished ? AppColors.green : AppColors.adminSurfaceElevated;
    final qrUrl = "https://spikedunk.web.app/?matchId=${matchDoc.id}";

    final Widget qrBox = isPending
        ? SizedBox(width: 108, child: Center(child: Text('QR når lagene\ner klare', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.adminTextSecondary))))
        : InkWell(
            onTap: () => _showQrDialog(matchDoc.id, teamA, teamB),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.adminSurfaceElevated)),
                    child: QrImageView(data: qrUrl, version: QrVersions.auto, size: 92, padding: EdgeInsets.zero, backgroundColor: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  const Text('Scan for dommer', style: TextStyle(fontSize: 10, color: AppColors.adminTextSecondary)),
                ],
              ),
            ),
          );

    return GestureDetector(
      onTap: () => _showMatchEditDialog(matchDoc),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.adminSurfaceElevated.withOpacity(0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isLive ? AppColors.coral.withOpacity(0.6) : isFinished ? AppColors.green.withOpacity(0.25) : AppColors.adminSurfaceElevated, width: isLive ? 1.5 : 1),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 170,
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                decoration: BoxDecoration(border: Border(left: BorderSide(color: accent, width: 4))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(children: [
                      if (matchNum != null) ...[Text('#$matchNum', style: const TextStyle(fontSize: 12, color: AppColors.adminPrimary, fontWeight: FontWeight.bold)), const SizedBox(width: 6)],
                      Flexible(child: infoChip(statusLabel, color: statusColor)),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, size: 12, color: AppColors.adminTextSecondary),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.access_time, size: 12, color: AppColors.adminTextSecondary),
                      const SizedBox(width: 4),
                      Flexible(child: Text(matchTime.isEmpty ? '--:--' : (matchDate.isEmpty ? matchTime : '$matchTime – $matchDate'), style: const TextStyle(fontSize: 11, color: AppColors.adminTextSecondary), overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 6),
                    infoChip(stageLabel.isEmpty ? '-' : stageLabel),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.location_on, size: 12, color: AppColors.adminTextSecondary),
                      const SizedBox(width: 4),
                      Flexible(child: Text(court, style: const TextStyle(fontSize: 11, color: AppColors.adminPrimary, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    ]),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: AppColors.adminSurface,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              teamLine(teamA, homeWins, isFinished ? homeScore : null),
                              Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 8), color: AppColors.adminSurfaceElevated),
                              teamLine(teamB, awayWins, isFinished ? awayScore : null),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.adminSurfaceElevated))),
                        child: qrBox,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
            onPressed: () async {
              final doc = await FirebaseFirestore.instance
                  .collection('tournaments').doc(widget.tournamentId).get();
              if (!context.mounted) return;
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => RegistrationsPage(
                  tournamentId: widget.tournamentId,
                  tournamentName: widget.tournamentName,
                  tournamentType:
                      (doc.data()?['tournament_type'] as String?) ?? 'nt_master',
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
                  leading: Icon(Icons.sync, color: AppColors.adminPrimary),
                  title: Text("Sync bracket"),
                  subtitle: Text("Oppdater kryssninger manuelt", style: TextStyle(fontSize: 11)),
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'reset',
                child: ListTile(
                  leading: Icon(Icons.restart_alt, color: AppColors.adminPrimary),
                  title: Text("Nullstill hele turneringen"),
                  subtitle: Text("Sletter alle kamper, beholder lag", style: TextStyle(fontSize: 11)),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                if (ResponsiveLayout.getBreakpoint(context).index >= ResponsiveBreakpoint.tablet.index)
                  NavigationRail(
                    backgroundColor: AppColors.adminSurface,
                    selectedIndex: _selectedNavIndex,
                    onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
                    labelType: NavigationRailLabelType.all,
                    selectedIconTheme: const IconThemeData(color: AppColors.adminPrimary),
                    selectedLabelTextStyle: const TextStyle(
                      color: AppColors.adminPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                    unselectedIconTheme: const IconThemeData(color: AppColors.adminTextSecondary),
                    unselectedLabelTextStyle: const TextStyle(
                      color: AppColors.adminTextSecondary, fontSize: 12),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.dashboard),
                        label: Text("Oversikt"),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.schedule),
                        label: Text("Kampprogram"),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.account_tree),
                        label: Text("Oppsett"),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.groups),
                        label: Text("Lag"),
                      ),
                    ],
                  ),
                if (ResponsiveLayout.getBreakpoint(context).index >= ResponsiveBreakpoint.tablet.index)
                  const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: _buildNavContent()),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: ResponsiveLayout.getBreakpoint(context).index < ResponsiveBreakpoint.tablet.index
          ? BottomNavigationBar(
              currentIndex: _selectedNavIndex,
              onTap: (i) => setState(() => _selectedNavIndex = i),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppColors.adminPrimary,
              unselectedItemColor: AppColors.adminTextSecondary,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Oversikt"),
                BottomNavigationBarItem(icon: Icon(Icons.schedule), label: "Program"),
                BottomNavigationBarItem(icon: Icon(Icons.account_tree), label: "Oppsett"),
                BottomNavigationBarItem(icon: Icon(Icons.groups), label: "Lag"),
              ],
            )
          : null,
      floatingActionButton: _selectedNavIndex == 3
          ? FloatingActionButton.extended(
              onPressed: _showAddTeamDialog,
              label: const Text("Nytt Lag"),
              icon: const Icon(Icons.group_add),
            )
          : null,
    );
  }

  Widget _buildNavContent() {
    switch (_selectedNavIndex) {
      case 0: return _buildDashboardTab();
      case 1: return _buildScheduleTab();
      case 2: return _buildOppsettSection();
      case 3: return _buildTeamsTab();
      default: return _buildOppsettSection();
    }
  }

  // ─── Oversikt (Dashboard) ─────────────────────────────────────────────────

  Widget _buildDashboardTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('matches').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
      builder: (ctx, matchSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('teams').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
          builder: (ctx2, teamSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
              builder: (ctx3, catSnap) {
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('tournaments').doc(widget.tournamentId).snapshots(),
                  builder: (ctx4, tourSnap) {
                    if (!matchSnap.hasData || !teamSnap.hasData || !catSnap.hasData || !tourSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var matches = matchSnap.data!.docs;
                    var teams = teamSnap.data!.docs;
                    
                    if (_selectedCategoryId != null && _selectedCategoryId != 'all') {
                      matches = matches.where((m) => (m.data() as Map)['category_id'] == _selectedCategoryId).toList();
                      teams = teams.where((t) => (t.data() as Map)['category_id'] == _selectedCategoryId).toList();
                    }

                    final categories = catSnap.data!.docs;
                    final tourData = tourSnap.data?.data() as Map<String, dynamic>? ?? {};

                    final courtsCount = (tourData['courts_count'] as num?)?.toInt() ?? 4;
                    final totalMatches = matches.length;
                    final totalTeams = teams.length;

                    Map<String, int> matchesPerGender = {'Herrer': 0, 'Damer': 0, 'Annet': 0};
                    Map<String, int> matchesPerLevel = {};

                    Map<String, String> catIdToName = {};
                    for (var c in categories) {
                      final d = c.data() as Map<String, dynamic>;
                      final name = d['name'] as String? ?? '';
                      catIdToName[c.id] = name;
                    }

                    for (var m in matches) {
                      final d = m.data() as Map<String, dynamic>;
                      final catId = d['category_id'] as String? ?? '';
                      final catName = catIdToName[catId] ?? '';
                      
                      if (catName.toLowerCase().contains('menn') || catName.toLowerCase().contains('herrer')) {
                        matchesPerGender['Herrer'] = (matchesPerGender['Herrer'] ?? 0) + 1;
                      } else if (catName.toLowerCase().contains('damer')) {
                        matchesPerGender['Damer'] = (matchesPerGender['Damer'] ?? 0) + 1;
                      } else {
                        matchesPerGender['Annet'] = (matchesPerGender['Annet'] ?? 0) + 1;
                      }

                      String level = 'Ukjent';
                      final parts = catName.split(' ');
                      if (parts.length > 1) {
                        level = parts.sublist(1).join(' ');
                      }
                      matchesPerLevel[level] = (matchesPerLevel[level] ?? 0) + 1;
                    }

                    Widget statCard(String title, String value, IconData icon, Color color) {
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(icon, color: color, size: 20),
                                  const SizedBox(width: 8),
                                  Text(title, style: const TextStyle(fontSize: 14, color: AppColors.adminTextSecondary)),
                                ],
                              ),
                              const Spacer(),
                              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.adminText)),
                            ],
                          ),
                        ),
                      );
                    }

                    return ResponsiveContainer.dashboard(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Turnerings-Oversikt", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.adminText)),
                                _buildInlineCategoryFilter(),
                              ],
                            ),
                            const SizedBox(height: 16),
                            GridView.count(
                              crossAxisCount: ResponsiveLayout.gridColumns(context, mobile: 2, tablet: 4, desktop: 4, ultrawide: 4),
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 1.5,
                              children: [
                                statCard("Påmeldte lag", "$totalTeams", Icons.groups, Colors.blue),
                                statCard("Antall baner", "$courtsCount", Icons.sports_tennis, Colors.green),
                                statCard("Kamper totalt", "$totalMatches", Icons.sports_volleyball, Colors.orange),
                                statCard("Ferdigspilte", "${matches.where((m) => (m.data() as Map)['status'] == 'finished').length}", Icons.check_circle, Colors.teal),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Text("Kamper per Klasse (Kjønn)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adminText)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: matchesPerGender.entries.where((e) => e.value > 0).map((e) {
                                return Chip(
                                  label: Text("${e.key}: ${e.value} kamper", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  backgroundColor: AppColors.coral,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                            const Text("Kamper per Nivå", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adminText)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: matchesPerLevel.entries.where((e) => e.value > 0).map((e) {
                                return Chip(
                                  label: Text("${e.key}: ${e.value} kamper", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  backgroundColor: AppColors.adminSurfaceElevated,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildOppsettWrapper() {
    if (_selectedCategoryId == null) {
      return const Center(child: Text("Velg en klasse i menyen over."));
    }
    if (_selectedCategoryId == 'all') {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("Ingen klasser funnet."));
          return ListView(
            children: docs.map((doc) => SizedBox(height: 800, child: _buildOppsettWrapperForCategory(doc.id, (doc.data() as Map)['name']))).toList(),
          );
        }
      );
    }
    return _buildOppsettWrapperForCategory(_selectedCategoryId!, null);
  }
  Widget _buildOppsettWrapperForCategory(String categoryId, String? categoryName) {

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('matches').where('tournament_id', isEqualTo: widget.tournamentId).where('category_id', isEqualTo: categoryId).snapshots(),

      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final allMatches = snap.data!.docs;

        final matchNumById = <String, int>{};
        for (final m in allMatches) {
          final num = (m.data() as Map)['match_number'] as int?;
          if (num != null) matchNumById[m.id] = num;
        }

        final groups = allMatches
            .map((m) => (m.data() as Map)['group'] as String?)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();

        final brackets = allMatches
            .where((m) => (m.data() as Map)['stage'] == 'playoff')
            .map((m) => (m.data() as Map)['bracket'] as String?)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort((a, b) {
            const o = ['A', 'B', 'C', 'D'];
            final ai = o.indexOf(a); final bi = o.indexOf(b);
            if (ai < 0 && bi < 0) return a.compareTo(b);
            if (ai < 0) return 1; if (bi < 0) return -1;
            return ai.compareTo(bi);
          });

        final courts = allMatches
            .map((m) => (m.data() as Map)['court'] as String?)
            .whereType<String>()
            .where((c) => c.isNotEmpty && c != 'TBD')
            .toSet()
            .toList()
          ..sort();

        var filtered = allMatches.toList();

        if (_oppsettStageFilter == 'grupper') {
          filtered = filtered.where((m) => (m.data() as Map)['stage'] == 'group').toList();
        } else if (_oppsettStageFilter != 'alle') {
          filtered = filtered.where((m) {
            final d = m.data() as Map;
            return d['stage'] == 'playoff' && d['bracket'] == _oppsettStageFilter;
          }).toList();
        }

        if (_oppsettGroupFilter != 'alle') {
          filtered = filtered.where((m) => (m.data() as Map)['group'] == _oppsettGroupFilter).toList();
        }

        if (_oppsettCourtFilter != 'alle') {
          filtered = filtered.where((m) => (m.data() as Map)['court'] == _oppsettCourtFilter).toList();
        }

        final groupSections = <String, List<DocumentSnapshot>>{};
        final playoffSections = <String, Map<String, List<DocumentSnapshot>>>{};
        for (final m in filtered) {
          final d = m.data() as Map;
          if (d['stage'] == 'group') {
            groupSections.putIfAbsent(d['group'] as String? ?? '?', () => []).add(m);
          } else if (d['stage'] == 'playoff') {
            final b = d['bracket'] as String? ?? '?';
            final r = d['round'] as String? ?? '?';
            playoffSections.putIfAbsent(b, () => {}).putIfAbsent(r, () => []).add(m);
          }
        }

        for (final list in groupSections.values) {
          list.sort((a, b) {
            final ta = (a.data() as Map)['match_type'] as String? ?? '';
            final tb = (b.data() as Map)['match_type'] as String? ?? '';
            return ta.compareTo(tb);
          });
        }
        for (final bMap in playoffSections.values) {
          for (final list in bMap.values) {
            list.sort((a, b) =>
                ((a.data() as Map)['match_number'] as int? ?? 0)
                    .compareTo((b.data() as Map)['match_number'] as int? ?? 0));
          }
        }

        final sortedGroups = groupSections.keys.toList()..sort();
        final sortedBrackets = playoffSections.keys.toList()
          ..sort((a, b) {
            const o = ['A', 'B', 'C', 'D'];
            final ai = o.indexOf(a); final bi = o.indexOf(b);
            if (ai < 0 && bi < 0) return a.compareTo(b);
            if (ai < 0) return 1; if (bi < 0) return -1;
            return ai.compareTo(bi);
          });

        const roundOrder = ['omspill', 'r16', 'r8', 'qf', 'sf', 'final'];

        Widget chip(String label, String id, String cur, void Function(String) onTap) {
          final sel = id == cur;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(label),
              selected: sel,
              onSelected: (v) { if (v) onTap(id); },
              selectedColor: AppColors.coral,
              labelStyle: TextStyle(
                color: sel ? Colors.white : AppColors.adminTextSecondary,
                fontWeight: FontWeight.bold, fontSize: 12,
              ),
              backgroundColor: AppColors.adminSurface,
              side: BorderSide(color: sel ? AppColors.coral : AppColors.adminSurfaceElevated),
              visualDensity: VisualDensity.compact,
            ),
          );
        }

        return Column(
          children: [
            if (categoryName != null) Padding(padding: const EdgeInsets.all(16), child: Text(categoryName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.adminPrimary))),
            // ── Generer-knapp ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
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

            if (allMatches.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  "Trykk én gang – setter opp grupper, runde 2 og sluttspillkryssninger automatisk.",
                  style: TextStyle(fontSize: 11, color: AppColors.adminTextSecondary),
                  textAlign: TextAlign.center,
                ),
              ),

            // ── Filter-rader ─────────────────────────────────────────
            if (allMatches.isNotEmpty)
              Container(
                color: AppColors.adminSurface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fase / bracket
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(children: [
                        chip('Alle', 'alle', _oppsettStageFilter, (v) => setState(() {
                          _oppsettStageFilter = v;
                          _oppsettGroupFilter = 'alle';
                        })),
                        chip('Grupper', 'grupper', _oppsettStageFilter, (v) => setState(() => _oppsettStageFilter = v)),
                        for (final b in brackets)
                          chip('$b-Bracket', b, _oppsettStageFilter, (v) => setState(() {
                            _oppsettStageFilter = v;
                            _oppsettGroupFilter = 'alle';
                          })),
                      ]),
                    ),
                    // Gruppe-filter
                    if ((_oppsettStageFilter == 'alle' || _oppsettStageFilter == 'grupper') && groups.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: Row(children: [
                          chip('Alle grupper', 'alle', _oppsettGroupFilter, (v) => setState(() => _oppsettGroupFilter = v)),
                          for (final g in groups)
                            chip('Pulje $g', g, _oppsettGroupFilter, (v) => setState(() => _oppsettGroupFilter = v)),
                        ]),
                      ),
                    // Bane-filter
                    if (courts.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(children: [
                          chip('Alle baner', 'alle', _oppsettCourtFilter, (v) => setState(() => _oppsettCourtFilter = v)),
                          for (final c in courts)
                            chip(c, c, _oppsettCourtFilter, (v) => setState(() => _oppsettCourtFilter = v)),
                        ]),
                      ),
                    const Divider(height: 1),
                  ],
                ),
              ),

            // ── Kampeliste ───────────────────────────────────────────
            Expanded(
              child: (allMatches.isNotEmpty && filtered.isEmpty)
                  ? const Center(
                      child: Text("Ingen kamper matcher filteret.",
                          style: TextStyle(color: AppColors.adminTextSecondary)))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      children: [
                        for (final g in sortedGroups) ...[
                          _oppsettSectionHeader("Pulje $g"),
                          ...groupSections[g]!.map((m) => _buildOppsettMatchRow(m, matchNumById)),
                          const SizedBox(height: 6),
                        ],
                        for (final b in sortedBrackets)
                          for (final r in roundOrder.where((r) => playoffSections[b]!.containsKey(r))) ...[
                            _oppsettSectionHeader('$b-Bracket · ${_oppsettRoundLabel(r)}'),
                            ...playoffSections[b]![r]!.map((m) => _buildOppsettMatchRow(m, matchNumById)),
                            const SizedBox(height: 6),
                          ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInlineCategoryFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('categories')
          .where('tournament_id', isEqualTo: widget.tournamentId)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final cats = snap.data!.docs;
        if (cats.isEmpty) return const SizedBox.shrink();

        if (_selectedCategoryId == null && cats.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() { _selectedCategoryId = 'all'; });
          });
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.adminSurfaceElevated),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategoryId,
              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              isDense: true,
              items: [
                const DropdownMenuItem<String>(
                  value: 'all',
                  child: Text('Begge kjønn / Alle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
                ...cats.map((c) {
                  final data = c.data() as Map<String, dynamic>;
                  return DropdownMenuItem<String>(
                    value: c.id,
                    child: Text(data['name'] ?? 'Klasse', style: const TextStyle(fontSize: 14)),
                  );
                }),
              ],
              onChanged: (v) => setState(() => _selectedCategoryId = v),
            ),
          ),
        );
      },
    );
  }

  // ─── Lag-fanen ────────────────────────────────────────────────────────────

  Widget _buildTeamsTab() {
    Widget content;
    if (_selectedCategoryId == null) {
      content = const Center(child: Text("Velg en klasse i menyen over."));
    } else if (_selectedCategoryId == 'all') {
      content = StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("Ingen klasser funnet."));
          return ListView(
            children: docs.map((doc) => SizedBox(height: 600, child: _buildTeamsTabForCategory(doc.id, (doc.data() as Map)['name']))).toList(),
          );
        }
      );
    } else {
      content = _buildTeamsTabForCategory(_selectedCategoryId!, null);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
          child: _buildInlineCategoryFilter(),
        ),
        Expanded(child: content),
      ],
    );
  }
  Widget _buildTeamsTabForCategory(String categoryId, String? categoryName) {
    return Column(
      children: [
            if (categoryName != null) Padding(padding: const EdgeInsets.all(16), child: Text(categoryName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.adminPrimary))),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text("Auto-generer 16 testlag (fra spillerdatabase)"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.adminPrimaryHover, foregroundColor: AppColors.adminText),
                onPressed: _autoGenerateTeams,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('teams').where('tournament_id', isEqualTo: widget.tournamentId).where('category_id', isEqualTo: categoryId).snapshots(),

            builder: (ctx, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final teams = snap.data!.docs;
              if (teams.isEmpty) {
                return const Center(
                  child: Text("Ingen lag registrert enda.\nTrykk + for å legge til lag.",
                      textAlign: TextAlign.center));
              }

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
                            icon: const Icon(Icons.edit, color: AppColors.adminPrimary),
                            tooltip: "Rediger / Flytt",
                            onPressed: () => _showTeamEditDialog(sorted[i]),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: AppColors.adminPrimary),
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

  // ─── NY Oppsett-seksjon (kortbasert, ingen sub-tabs) ──────────────────────

  Widget _buildOppsettSection() {
    Widget content;
    if (_selectedCategoryId == null) {
      content = const Center(child: Text("Velg en klasse."));
    } else if (_selectedCategoryId == 'all') {
      content = StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("Ingen klasser funnet."));
          return ListView(
            children: docs.map((doc) => SizedBox(height: 1000, child: _buildOppsettSectionForCategory(doc.id, (doc.data() as Map)['name']))).toList(),
          );
        }
      );
    } else {
      content = _buildOppsettSectionForCategory(_selectedCategoryId!, null);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
          child: _buildInlineCategoryFilter(),
        ),
        Expanded(child: content),
      ],
    );
  }
  Widget _buildOppsettSectionForCategory(String categoryId, String? categoryName) {

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('teams').where('tournament_id', isEqualTo: widget.tournamentId).where('category_id', isEqualTo: categoryId).snapshots(),

      builder: (ctx, teamSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('matches').where('tournament_id', isEqualTo: widget.tournamentId).where('category_id', isEqualTo: categoryId).snapshots(),

          builder: (ctx2, matchSnap) {
            if (!teamSnap.hasData || !matchSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final teams      = teamSnap.data!.docs;
            final allMatches = matchSnap.data!.docs;
            final hasMatches = allMatches.isNotEmpty;

            final matchNumById = <String, int>{};
            for (final m in allMatches) {
              final num = (m.data() as Map)['match_number'] as int?;
              if (num != null) matchNumById[m.id] = num;
            }

            final sortedTeams = List<DocumentSnapshot>.from(teams)
              ..sort((a, b) {
                final as_ = (a.data() as Map)['seed'] as int? ?? 999;
                final bs  = (b.data() as Map)['seed'] as int? ?? 999;
                if (as_ != bs) return as_.compareTo(bs);
                final ap = (a.data() as Map)['team_points'] as num? ?? 0;
                final bp = (b.data() as Map)['team_points'] as num? ?? 0;
                return bp.compareTo(ap);
              });

            // Grupper for preview-kortet
            final Map<String, List<DocumentSnapshot>> groupTeams = {};
            for (final t in sortedTeams) {
              final g = (t.data() as Map)['group'] as String?;
              if (g != null) groupTeams.putIfAbsent(g, () => []).add(t);
            }
            final sortedGroups = groupTeams.keys.toList()..sort();

            final hasPlayoffs = allMatches.any((m) => (m.data() as Map)['stage'] == 'playoff');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            if (categoryName != null) Padding(padding: const EdgeInsets.all(16), child: Text(categoryName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.adminPrimary))),
                // Top sub-menu bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    color: AppColors.adminSurfaceElevated,
                  ),
                  child: Row(
                    children: [
                      _buildOppsettSubTab('Gruppespill'),
                      const SizedBox(width: 8),
                      _buildOppsettSubTab('Sluttspill'),
                      const SizedBox(width: 8),
                      _buildOppsettSubTab('Seeding'),
                      
                      const Spacer(),
                      

                      
                      if (hasMatches) ...[
                        _buildPublishButtonInline(),
                        const SizedBox(width: 12),
                      ],
                      
                      ElevatedButton.icon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text("Rediger turnering"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.adminSurface,
                          foregroundColor: AppColors.adminPrimary,
                          elevation: 0,
                          side: const BorderSide(color: AppColors.adminPrimary),
                        ),
                        onPressed: () async {
                          final doc = await FirebaseFirestore.instance
                              .collection('tournaments').doc(widget.tournamentId).get();
                          if (!context.mounted) return;
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => EditTournamentPage(
                              tournamentId: widget.tournamentId,
                              initialData: doc.data() ?? {},
                            ),
                          ));
                        },
                      ),
                    ],
                  ),
                ),
                // Tab content
                Expanded(
                  child: (_selectedCategoryId == 'all')
                    ? const Center(child: Text("Velg en spesifikk klasse for å se puljeoppsett og sluttspill.", style: TextStyle(color: AppColors.adminTextSecondary, fontSize: 16)))
                    : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!hasMatches) ...[
                          _buildSeedingCard(sortedTeams, hasMatches),
                          const SizedBox(height: 16),
                          _buildGenerateCard(),
                        ] else ...[
                          if (_selectedOppsettTab == 'Seeding')
                            _buildSeedingCard(sortedTeams, hasMatches),
                            
                          if (_selectedOppsettTab == 'Gruppespill' && sortedGroups.isNotEmpty)
                            _buildGroupPreviewCard(groupTeams, sortedGroups),
                            
                          if (_selectedOppsettTab == 'Sluttspill' && hasPlayoffs)
                            _buildPlayoffPreviewCard(allMatches, matchNumById),
                            
                          if (_selectedOppsettTab != 'Seeding' && _selectedOppsettTab != 'Gruppespill' && _selectedOppsettTab != 'Sluttspill')
                            const Center(child: Text("Ingen kamper i denne visningen.")),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSeedingCard(List<DocumentSnapshot> sortedTeams, bool hasMatches) {
    final numTeams = sortedTeams.length;
    final numGroups = numTeams >= 4 ? (numTeams / 4).ceil().clamp(1, 26) : 1;

    String serpentineGroup(int seed) {
      final idx = (seed - 1).clamp(0, 999);
      final row = idx ~/ numGroups;
      final col = idx % numGroups;
      final gIdx = (row % 2 == 0 ? col : numGroups - 1 - col).clamp(0, 25);
      return String.fromCharCode(65 + gIdx);
    }

    final swapName = _swapSelectionDoc != null
        ? (_swapSelectionDoc!.data() as Map)['team_name'] as String? ?? ''
        : null;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            color: AppColors.adminSurfaceElevated,
            child: Row(children: [
              const Icon(Icons.format_list_numbered, color: AppColors.adminPrimary, size: 20),
              const SizedBox(width: 10),
              const Text("Seeding-oversikt",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.adminText)),
              const Spacer(),
              if (swapName != null) ...[
                const Icon(Icons.swap_vert, size: 14, color: AppColors.adminPrimary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text("Velg lag å bytte med «$swapName»",
                      style: const TextStyle(fontSize: 12, color: AppColors.adminPrimary, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _swapSelectionDoc = null),
                  child: const Icon(Icons.close, size: 16, color: AppColors.adminPrimary),
                ),
              ] else
                Text("$numTeams lag · $numGroups ${numGroups == 1 ? 'pulje' : 'puljer'}",
                    style: const TextStyle(fontSize: 12, color: AppColors.adminTextSecondary)),
            ]),
          ),

          // Kolonneoverskrifter
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            color: AppColors.adminSurface,
            child: const Row(children: [
              SizedBox(width: 52, child: Text("Seed", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.adminTextSecondary))),
              Expanded(child: Text("Lag", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.adminTextSecondary))),
              SizedBox(width: 70, child: Center(child: Text("Poeng", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.adminTextSecondary)))),
              SizedBox(width: 90, child: Center(child: Text("Pulje", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.adminTextSecondary)))),
              SizedBox(width: 72),
            ]),
          ),
          const Divider(height: 1),

          // Lagrekker
          ...sortedTeams.map((teamDoc) {
            final d        = teamDoc.data() as Map<String, dynamic>;
            final seed     = (d['seed'] as num?)?.toInt();
            final points   = (d['team_points'] as num?)?.toInt() ?? 0;
            final curGroup = d['group'] as String?;

            final isSelected  = _swapSelectionDoc?.id == teamDoc.id;
            final inSwapMode  = _swapSelectionDoc != null && !isSelected;

            final displayGroup  = curGroup ?? (seed != null ? serpentineGroup(seed) : '?');
            final isExpected    = curGroup == null && seed != null;

            return Column(children: [
              Container(
                color: isSelected ? AppColors.adminPrimary.withValues(alpha: 0.08) : null,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(children: [
                  // Seed badge
                  SizedBox(
                    width: 52,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.adminPrimary.withValues(alpha: 0.15)
                            : AppColors.adminSurfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text('${seed ?? '–'}',
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold,
                              color: isSelected ? AppColors.adminPrimary : AppColors.adminText,
                            )),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Lagnavn + spillere
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d['team_name'] ?? 'Ukjent',
                        style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13,
                          color: isSelected ? AppColors.adminPrimary : AppColors.adminText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "${d['player1_name'] ?? ''} & ${d['player2_name'] ?? ''}",
                        style: const TextStyle(fontSize: 11, color: AppColors.adminTextSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )),

                  // Poeng
                  SizedBox(
                    width: 70,
                    child: Center(child: Text('$points',
                        style: const TextStyle(fontSize: 12, color: AppColors.adminTextSecondary))),
                  ),

                  // Puljebadge
                  SizedBox(
                    width: 90,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isExpected
                              ? Colors.transparent
                              : AppColors.adminSurfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                          border: isExpected
                              ? Border.all(color: AppColors.adminSurfaceElevated)
                              : null,
                        ),
                        child: Text('Pulje $displayGroup',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold,
                            color: isExpected
                                ? AppColors.adminTextSecondary
                                : AppColors.adminPrimary,
                            fontStyle: isExpected ? FontStyle.italic : FontStyle.normal,
                          )),
                      ),
                    ),
                  ),

                  // Handlingsknapp
                  SizedBox(
                    width: 72,
                    child: isSelected
                        ? TextButton(
                            onPressed: () => setState(() => _swapSelectionDoc = null),
                            child: const Text("Avbryt", style: TextStyle(fontSize: 11)),
                          )
                        : inSwapMode
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.adminPrimary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  minimumSize: const Size(60, 32),
                                ),
                                onPressed: () => _confirmAndSwap(_swapSelectionDoc!, teamDoc),
                                child: const Text("Velg"),
                              )
                            : TextButton(
                                style: TextButton.styleFrom(foregroundColor: AppColors.adminTextSecondary),
                                onPressed: () => setState(() => _swapSelectionDoc = teamDoc),
                                child: const Text("Bytt", style: TextStyle(fontSize: 11)),
                              ),
                  ),
                ]),
              ),
              const Divider(height: 1),
            ]);
          }),

          // Bunntekst
          if (sortedTeams.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text("Ingen lag registrert enda.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.adminTextSecondary)),
            ),
        ],
      ),
    );
  }

  Widget _buildGenerateCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(children: [
              Icon(Icons.emoji_events, color: AppColors.adminPrimary, size: 24),
              SizedBox(width: 12),
              Text("Generer turneringsoppsett",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.adminText)),
            ]),
            const SizedBox(height: 8),
            const Text(
              "Setter opp grupper, runde 2 og sluttspillkryssninger automatisk basert på seeding. "
              "Etter generering kan du publisere oppsettet for deltakere.",
              style: TextStyle(fontSize: 13, color: AppColors.adminTextSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text("Generer Grupper + Sluttspill"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              onPressed: _generateGroupStage,
            ),
          ],
        ),
      ),
    );
  }

    Widget _buildPublishButtonInline() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).limit(1).snapshots(),
      builder: (ctx, snap) {
        bool isPub = false;
        if (snap.hasData && snap.data!.docs.isNotEmpty) {
          isPub = (snap.data!.docs.first.data() as Map)['published'] == true;
        }
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: isPub ? AppColors.adminSurfaceElevated : AppColors.coral,
            foregroundColor: isPub ? AppColors.adminTextSecondary : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          icon: Icon(isPub ? Icons.visibility_off : Icons.visibility, size: 20),
          label: Text(isPub ? "Skjul turnering" : "Publiser turnering offentlig"),
          onPressed: () { if (isPub) _unpublishCategory(); else _publishCategory(); },
        );
      },
    );
  }

  Widget _buildOppsettSubTab(String title) {
    final isSelected = _selectedOppsettTab == title;
    return InkWell(
      onTap: () => setState(() => _selectedOppsettTab = title),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.adminPrimary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.adminPrimary : Colors.transparent,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.adminPrimary : AppColors.adminTextSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupPreviewCard(
      Map<String, List<DocumentSnapshot>> groupTeams, List<String> sortedGroups) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            color: AppColors.adminSurfaceElevated,
            child: const Row(children: [
              Icon(Icons.grid_view, color: AppColors.adminPrimary, size: 20),
              SizedBox(width: 10),
              Text("Puljeoversikt",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.adminText)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: sortedGroups.map((g) {
                final gTeams = List<DocumentSnapshot>.from(groupTeams[g] ?? [])
                  ..sort((a, b) {
                    final as_ = (a.data() as Map)['seed'] as int? ?? 999;
                    final bs  = (b.data() as Map)['seed'] as int? ?? 999;
                    return as_.compareTo(bs);
                  });

                final placeBg = [
                  Colors.amber[700]!, AppColors.adminTextSecondary,
                  Colors.brown[400]!, AppColors.adminSurfaceElevated,
                ];

                return Container(
                  width: 210,
                  decoration: BoxDecoration(
                    color: AppColors.adminSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.adminSurfaceElevated),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: const BoxDecoration(
                          color: AppColors.adminSurfaceElevated,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                        ),
                        child: Text("Pulje $g",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, color: AppColors.adminText, fontSize: 14)),
                      ),
                      ...gTeams.asMap().entries.map((e) {
                        final idx = e.key;
                        final td = e.value.data() as Map<String, dynamic>;
                        final seed = (td['seed'] as num?)?.toInt();
                        final placement = (td['group_placement'] as num?)?.toInt();
                        final rank = placement ?? (idx + 1);
                        final bgColor = (rank >= 1 && rank <= 4) ? placeBg[rank - 1] : AppColors.adminSurfaceElevated;

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: bgColor,
                              child: Text('$rank',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(
                              td['team_name'] ?? 'Ukjent',
                              style: const TextStyle(fontSize: 12, color: AppColors.adminText),
                              overflow: TextOverflow.ellipsis,
                            )),
                            if (seed != null)
                              Text('S$seed',
                                  style: const TextStyle(fontSize: 10, color: AppColors.adminTextSecondary)),
                          ]),
                        );
                      }),
                      const SizedBox(height: 4),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sluttspillsoversikt-kort ─────────────────────────────────────────────

  Widget _buildPlayoffPreviewCard(
      List<DocumentSnapshot> allMatches, Map<String, int> matchNumById) {
    final playoffMatches =
        allMatches.where((m) => (m.data() as Map)['stage'] == 'playoff').toList();
    if (playoffMatches.isEmpty) return const SizedBox.shrink();

    const roundOrder  = ['omspill', 'r16', 'r8', 'qf', 'sf', 'final'];
    const roundLabels = {
      'omspill': 'Omspill',
      'r16':     '1/16-finale',
      'r8':      '1/8-finale',
      'qf':      'Kvartfinale',
      'sf':      'Semifinale',
      'final':   'Finale',
    };

    const bracketOrder = ['A', 'B', 'C', 'D'];
    final brackets = playoffMatches
        .map((m) => (m.data() as Map)['bracket'] as String?)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort((a, b) {
        final ai = bracketOrder.indexOf(a);
        final bi = bracketOrder.indexOf(b);
        if (ai < 0 && bi < 0) return a.compareTo(b);
        if (ai < 0) return 1;
        if (bi < 0) return -1;
        return ai.compareTo(bi);
      });

    if (brackets.isEmpty) return const SizedBox.shrink();

    // Bygger én kolonne per bracket, rader per runde
    Widget bracketColumn(String bracket) {
      final bMatches = playoffMatches
          .where((m) => (m.data() as Map)['bracket'] == bracket)
          .toList();

      final Map<String, List<DocumentSnapshot>> byRound = {};
      for (final m in bMatches) {
        final r = (m.data() as Map)['round'] as String? ?? '';
        byRound.putIfAbsent(r, () => []).add(m);
      }
      for (final list in byRound.values) {
        list.sort((a, b) =>
            ((a.data() as Map)['match_number'] as int? ?? 0)
                .compareTo((b.data() as Map)['match_number'] as int? ?? 0));
      }

      final usedRounds = roundOrder.where((r) => byRound.containsKey(r)).toList();

      Widget matchRow(DocumentSnapshot m) {
        final d        = m.data() as Map<String, dynamic>;
        final status   = d['status'] as String? ?? 'pending';
        final isFinished = status == 'finished';
        final isPending  = status == 'pending' ||
            (d['team_a_id'] as String? ?? '') == 'placeholder' ||
            (d['team_b_id'] as String? ?? '') == 'placeholder';
        final num      = d['match_number'] as int?;
        final teamA    = _resolveTeamDisplayName(d, 'team_a', matchNumById);
        final teamB    = _resolveTeamDisplayName(d, 'team_b', matchNumById);
        final court    = d['court'] as String?;
        final time     = d['match_time'] as String?;
        final homeS    = d['home_score'] as int? ?? 0;
        final awayS    = d['away_score'] as int? ?? 0;
        final homeWin  = isFinished && homeS > awayS;
        final awayWin  = isFinished && awayS > homeS;

        final statusColor = isFinished
            ? AppColors.green
            : isPending
                ? AppColors.adminTextSecondary
                : AppColors.adminPrimary;

        return InkWell(
          onTap: () => _showMatchEditDialog(m),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: AppColors.adminSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isFinished
                    ? AppColors.green.withValues(alpha: 0.3)
                    : isPending
                        ? AppColors.adminSurfaceElevated
                        : AppColors.adminSurfaceElevated,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kamp-nummer + tid/bane + status
                Row(children: [
                  if (num != null) ...[
                    Text('K$num',
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.adminPrimary,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                  ],
                  if (time != null && !isPending) ...[
                    const Icon(Icons.access_time,
                        size: 10, color: AppColors.adminTextSecondary),
                    const SizedBox(width: 2),
                    Text(time,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.adminTextSecondary)),
                    const SizedBox(width: 4),
                  ],
                  if (court != null && court != 'TBD' && !isPending)
                    Text(court,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.adminTextSecondary)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isFinished
                          ? '$homeS–$awayS'
                          : isPending
                              ? 'Venter'
                              : 'Planlagt',
                      style: TextStyle(
                          fontSize: 10,
                          color: statusColor,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ]),
                const SizedBox(height: 5),
                // Lag A
                Row(children: [
                  Expanded(
                    child: Text(
                      teamA,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: homeWin ? FontWeight.bold : FontWeight.normal,
                        color: isPending
                            ? AppColors.adminTextSecondary
                            : homeWin
                                ? AppColors.green
                                : AppColors.adminText,
                        fontStyle: isPending ? FontStyle.italic : FontStyle.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                // Versus-linje
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 1),
                  child: Text('vs',
                      style: TextStyle(
                          fontSize: 9,
                          color: AppColors.adminTextSecondary)),
                ),
                // Lag B
                Row(children: [
                  Expanded(
                    child: Text(
                      teamB,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: awayWin ? FontWeight.bold : FontWeight.normal,
                        color: isPending
                            ? AppColors.adminTextSecondary
                            : awayWin
                                ? AppColors.green
                                : AppColors.adminText,
                        fontStyle: isPending ? FontStyle.italic : FontStyle.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ],
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bracket-header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.adminPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.adminPrimary.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(
                bracket == 'A'
                    ? Icons.emoji_events
                    : bracket == 'B'
                        ? Icons.workspace_premium
                        : Icons.military_tech,
                size: 14,
                color: AppColors.adminPrimary,
              ),
              const SizedBox(width: 6),
              Text('$bracket-Bracket',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.adminPrimary)),
            ]),
          ),
          // Runde-seksjoner
          ...usedRounds.map((r) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rundetittel
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
                child: Text(
                  roundLabels[r] ?? r.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.adminTextSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              // Kamper i denne runden
              ...byRound[r]!.map(matchRow),
              const SizedBox(height: 8),
            ],
          )),
        ],
      );
    }

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            color: AppColors.adminSurfaceElevated,
            child: Row(children: [
              const Icon(Icons.emoji_events, color: AppColors.adminPrimary, size: 20),
              const SizedBox(width: 10),
              const Text("Sluttspillsoversikt",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.adminText)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.sync, size: 15, color: AppColors.adminPrimary),
                label: const Text("Sync",
                    style: TextStyle(color: AppColors.adminPrimary, fontSize: 12)),
                onPressed: () async {
                  await _resolvePendingMatches();
                  _snack("Bracket synkronisert.");
                },
              ),
            ]),
          ),
          // Bracket-kolonner side om side
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: brackets
                  .map((b) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              right: b != brackets.last ? 16 : 0),
                          child: bracketColumn(b),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Seeding-bytte ──────────────────────────────────────────────────────────

  Future<void> _confirmAndSwap(DocumentSnapshot teamA, DocumentSnapshot teamB) async {
    final dataA = teamA.data() as Map<String, dynamic>;
    final dataB = teamB.data() as Map<String, dynamic>;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Bytt seeding?"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.adminSurfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: AppColors.adminPrimary.withValues(alpha: 0.2),
                child: Text('${(dataA['seed'] as num?)?.toInt() ?? '?'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.adminPrimary)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(dataA['team_name'] ?? 'Ukjent',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.adminText)),
                Text(
                  "${dataA['player1_name'] ?? ''} & ${dataA['player2_name'] ?? ''}",
                  style: const TextStyle(fontSize: 11, color: AppColors.adminTextSecondary),
                ),
              ])),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Icon(Icons.swap_vert, size: 28, color: AppColors.adminPrimary),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.adminSurfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: AppColors.adminPrimary.withValues(alpha: 0.2),
                child: Text('${(dataB['seed'] as num?)?.toInt() ?? '?'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.adminPrimary)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(dataB['team_name'] ?? 'Ukjent',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.adminText)),
                Text(
                  "${dataB['player1_name'] ?? ''} & ${dataB['player2_name'] ?? ''}",
                  style: const TextStyle(fontSize: 11, color: AppColors.adminTextSecondary),
                ),
              ])),
            ]),
          ),
          const SizedBox(height: 12),
          const Text(
            "Begge lagets seeding, pulje og kampdata oppdateres automatisk.",
            style: TextStyle(fontSize: 12, color: AppColors.adminTextSecondary),
            textAlign: TextAlign.center,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Avbryt")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Bytt seeding"),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await _swapSeedsBetween(teamA, teamB);
  }

  Future<void> _swapSeedsBetween(DocumentSnapshot teamA, DocumentSnapshot teamB) async {
    final dataA = teamA.data() as Map<String, dynamic>;
    final dataB = teamB.data() as Map<String, dynamic>;

    final seedA  = (dataA['seed']  as num?)?.toInt();
    final seedB  = (dataB['seed']  as num?)?.toInt();
    final groupA = dataA['group']  as String?;
    final groupB = dataB['group']  as String?;

    final batch = FirebaseFirestore.instance.batch();

    // Bytt seed og gruppe på begge lagdokumenter
    final Map<String, dynamic> updA = {};
    final Map<String, dynamic> updB = {};
    if (seedB  != null) {
      updA['seed']  = seedB;
    } else {
      updA['seed']  = FieldValue.delete();
    }
    if (seedA  != null) {
      updB['seed']  = seedA;
    } else {
      updB['seed']  = FieldValue.delete();
    }
    if (groupB != null) {
      updA['group'] = groupB;
    } else {
      updA['group'] = FieldValue.delete();
    }
    if (groupA != null) {
      updB['group'] = groupA;
    } else {
      updB['group'] = FieldValue.delete();
    }

    batch.update(teamA.reference, updA);
    batch.update(teamB.reference, updB);

    // Oppdater kampdata som refererer til enten lagA eller lagB
    final matchSnap = await _matchesQuery()
        .get();

    for (final m in matchSnap.docs) {
      final d   = m.data();
      final upd = <String, dynamic>{};

      final aId = d['team_a_id'] as String? ?? '';
      final bId = d['team_b_id'] as String? ?? '';

      if (aId == teamA.id) {
        upd['team_a_id']      = teamB.id;
        upd['team_a_name']    = dataB['team_name']    ?? '';
        upd['team_a_p1_name'] = dataB['player1_name'] ?? '';
        upd['team_a_p1_id']   = dataB['player1_id']   ?? '';
        upd['team_a_p2_name'] = dataB['player2_name'] ?? '';
        upd['team_a_p2_id']   = dataB['player2_id']   ?? '';
      } else if (aId == teamB.id) {
        upd['team_a_id']      = teamA.id;
        upd['team_a_name']    = dataA['team_name']    ?? '';
        upd['team_a_p1_name'] = dataA['player1_name'] ?? '';
        upd['team_a_p1_id']   = dataA['player1_id']   ?? '';
        upd['team_a_p2_name'] = dataA['player2_name'] ?? '';
        upd['team_a_p2_id']   = dataA['player2_id']   ?? '';
      }

      if (bId == teamA.id) {
        upd['team_b_id']      = teamB.id;
        upd['team_b_name']    = dataB['team_name']    ?? '';
        upd['team_b_p1_name'] = dataB['player1_name'] ?? '';
        upd['team_b_p1_id']   = dataB['player1_id']   ?? '';
        upd['team_b_p2_name'] = dataB['player2_name'] ?? '';
        upd['team_b_p2_id']   = dataB['player2_id']   ?? '';
      } else if (bId == teamB.id) {
        upd['team_b_id']      = teamA.id;
        upd['team_b_name']    = dataA['team_name']    ?? '';
        upd['team_b_p1_name'] = dataA['player1_name'] ?? '';
        upd['team_b_p1_id']   = dataA['player1_id']   ?? '';
        upd['team_b_p2_name'] = dataA['player2_name'] ?? '';
        upd['team_b_p2_id']   = dataA['player2_id']   ?? '';
      }

      if (upd.isNotEmpty) batch.update(m.reference, upd);
    }

    await batch.commit();
    if (mounted) setState(() => _swapSelectionDoc = null);
    _snack("Byttet: ${dataA['team_name']} (S${seedA ?? '?'}) ↔ ${dataB['team_name']} (S${seedB ?? '?'})");
  }

  // ─── Publisering ───────────────────────────────────────────────────────────

    Future<void> _publishCategory() async {
    final snap = await FirebaseFirestore.instance.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snap.docs) { batch.update(doc.reference, {'published': true}); }
    await batch.commit();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hele turneringen er nå publisert offentlig')));
  }

  Future<void> _unpublishCategory() async {
    final snap = await FirebaseFirestore.instance.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snap.docs) { batch.update(doc.reference, {'published': false}); }
    await batch.commit();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hele turneringen er nå skjult')));
  }

  String _oppsettRoundLabel(String r) => const {
    'omspill': 'Playoff', 'r16': '1/16', 'r8': '1/8',
    'qf': 'Kvartfinale', 'sf': 'Semifinale', 'final': 'Finale',
  }[r] ?? r;

  Widget _oppsettSectionHeader(String title) => Container(
    margin: const EdgeInsets.only(bottom: 4, top: 4),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.adminSurfaceElevated,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(title, style: const TextStyle(
      color: AppColors.adminText, fontWeight: FontWeight.bold, fontSize: 14)),
  );

  Widget _buildOppsettMatchRow(DocumentSnapshot matchDoc, Map<String, int> matchNumById) {
    final d = matchDoc.data() as Map<String, dynamic>;
    final matchNum = d['match_number'] as int?;
    final status = d['status'] as String? ?? 'scheduled';
    final isFinished = status == 'finished';
    final isLive = status == 'live';
    final isPending = status == 'pending';
    final court = d['court'] as String? ?? '';
    final matchTime = d['match_time'] as String? ?? '';
    final isAPH = (d['team_a_id'] as String? ?? '') == 'placeholder';
    final isBPH = (d['team_b_id'] as String? ?? '') == 'placeholder';
    final isPlaceholder = isAPH || isBPH;
    final teamA = _resolveTeamDisplayName(d, 'team_a', matchNumById);
    final teamB = _resolveTeamDisplayName(d, 'team_b', matchNumById);
    final homeScore = d['home_score'] as int? ?? 0;
    final awayScore = d['away_score'] as int? ?? 0;

    Color statusColor = AppColors.adminTextSecondary;
    String statusLabel = 'Planlagt';
    if (isLive) { statusColor = AppColors.adminPrimaryHover; statusLabel = 'LIVE'; }
    if (isFinished) { statusColor = AppColors.green; statusLabel = 'Ferdig'; }
    if (isPending) statusLabel = 'Venter';

    return Card(
      margin: const EdgeInsets.only(bottom: 5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            if (matchNum != null)
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.adminSurfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('$matchNum',
                    style: const TextStyle(fontSize: 11, color: AppColors.adminPrimary, fontWeight: FontWeight.bold)),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$teamA vs $teamB',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: isPending ? AppColors.adminTextSecondary : AppColors.adminText,
                      fontStyle: isPending ? FontStyle.italic : FontStyle.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isFinished)
                    Text('$homeScore – $awayScore',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.green, fontSize: 12))
                  else if (matchTime.isNotEmpty || (court.isNotEmpty && court != 'TBD'))
                    Row(children: [
                      if (matchTime.isNotEmpty) ...[
                        const Icon(Icons.access_time, size: 11, color: AppColors.adminTextSecondary),
                        const SizedBox(width: 3),
                        Text(matchTime, style: const TextStyle(fontSize: 11, color: AppColors.adminTextSecondary)),
                      ],
                      if (matchTime.isNotEmpty && court.isNotEmpty && court != 'TBD')
                        const Text(' · ', style: TextStyle(color: AppColors.adminTextSecondary, fontSize: 11)),
                      if (court.isNotEmpty && court != 'TBD')
                        Text(court, style: const TextStyle(fontSize: 11, color: AppColors.adminTextSecondary)),
                    ]),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isFinished ? AppColors.green.withValues(alpha: 0.2)
                    : isLive ? AppColors.adminPrimary.withValues(alpha: 0.2)
                    : isPending ? Colors.transparent
                    : AppColors.adminSurfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: isPending ? Border.all(color: AppColors.adminSurfaceElevated) : null,
              ),
              child: Text(statusLabel,
                  style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600)),
            ),
            if (!isPending)
              IconButton(
                icon: const Icon(Icons.edit, size: 17, color: AppColors.adminTextSecondary),
                tooltip: "Rediger kamp",
                onPressed: () => _showMatchEditDialog(matchDoc),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsTab_DELME() {
    // DELME – dead code kept for reference only
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
      stream: _teamsQuery()
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
          stream: _matchesQuery()
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

                // ── Beregn V/P/T fra ferdige kamper ──────────────────────────
                final statsMap = <String, Map<String, int>>{};
                for (final m in groupMatches) {
                  final md = m.data() as Map;
                  if (md['status'] != 'finished') continue;
                  final aId = md['team_a_id'] as String? ?? '';
                  final bId = md['team_b_id'] as String? ?? '';
                  if (aId.isEmpty || aId == 'placeholder') continue;
                  if (bId.isEmpty || bId == 'placeholder') continue;
                  final aSets = md['home_score'] as int? ?? 0;
                  final bSets = md['away_score'] as int? ?? 0;
                  statsMap.putIfAbsent(aId, () => {'v': 0, 'p': 0, 't': 0});
                  statsMap.putIfAbsent(bId, () => {'v': 0, 'p': 0, 't': 0});
                  statsMap[aId]!['p'] = statsMap[aId]!['p']! + aSets;
                  statsMap[bId]!['p'] = statsMap[bId]!['p']! + bSets;
                  if (aSets > bSets) {
                    statsMap[aId]!['v'] = statsMap[aId]!['v']! + 1;
                    statsMap[bId]!['t'] = statsMap[bId]!['t']! + 1;
                  } else {
                    statsMap[bId]!['v'] = statsMap[bId]!['v']! + 1;
                    statsMap[aId]!['t'] = statsMap[aId]!['t']! + 1;
                  }
                }

                final placeBg = [
                  Colors.amber[700]!, AppColors.adminTextSecondary,
                  Colors.brown[400]!, AppColors.adminSurfaceElevated,
                ];

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Header ────────────────────────────────────────────
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

                      // ── Stillingstabell header ────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                        child: Row(children: [
                          const SizedBox(width: 32),
                          const SizedBox(width: 8),
                          const Expanded(child: Text("LAG",
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                                  color: AppColors.adminTextSecondary, letterSpacing: 0.5))),
                          _statHeader("V"),
                          _statHeader("P"),
                          _statHeader("T"),
                        ]),
                      ),
                      const Divider(height: 1, indent: 12, endIndent: 12),

                      // ── Lagrekke per lag ──────────────────────────────────
                      ...groupTeams.asMap().entries.map((e) {
                        final idx = e.key;
                        final teamDoc = e.value;
                        final d = teamDoc.data() as Map<String, dynamic>;
                        final placement = d['group_placement'] as int?;
                        final rank = placement ?? (idx + 1);
                        final rankBg = (rank >= 1 && rank <= 4)
                            ? placeBg[rank - 1] : AppColors.adminSurfaceElevated;
                        final st = statsMap[teamDoc.id];
                        final v = st?['v'] ?? 0;
                        final p = st?['p'] ?? 0;
                        final t = st?['t'] ?? 0;
                        final hasStats = statsMap.containsKey(teamDoc.id);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: rankBg,
                              child: Text('$rank',
                                  style: const TextStyle(fontSize: 11,
                                      fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d['team_name'] ?? 'Ukjent',
                                    style: const TextStyle(fontWeight: FontWeight.w600,
                                        fontSize: 13, color: AppColors.adminText),
                                    overflow: TextOverflow.ellipsis),
                                Text(
                                  "${d['player1_name'] ?? ''} & ${d['player2_name'] ?? ''}",
                                  style: const TextStyle(fontSize: 10,
                                      color: AppColors.adminTextSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            )),
                            _statCell(hasStats ? '$v' : '–',
                                bold: hasStats && v > 0, color: hasStats && v > 0 ? AppColors.green : null),
                            _statCell(hasStats ? '$p' : '–'),
                            _statCell(hasStats ? '$t' : '–',
                                color: hasStats && t > 0 ? AppColors.adminTextSecondary : null),
                          ]),
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

  Widget _statHeader(String label) => SizedBox(
    width: 32,
    child: Center(
      child: Text(label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
              color: AppColors.adminTextSecondary, letterSpacing: 0.5)),
    ),
  );

  Widget _statCell(String value, {bool bold = false, Color? color}) => SizedBox(
    width: 32,
    child: Center(
      child: Text(value,
          style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ?? AppColors.adminText)),
    ),
  );

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
              color: isFinished ? AppColors.green.withValues(alpha: 0.2)
                  : status == 'live' ? AppColors.adminPrimary.withValues(alpha: 0.2)
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
                    : status == 'live' ? AppColors.adminPrimaryHover
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

class _BracketPainterTopDown extends CustomPainter {
  final Map<int, Offset> pos;
  final Map<String, List<DocumentSnapshot>> byRound;
  final List<String> topToBottom; // final at index 0, earliest round at last index
  final double cardW, cardH, innerW, pad, labelH, rowGap;

  const _BracketPainterTopDown({
    required this.pos,
    required this.byRound,
    required this.topToBottom,
    required this.cardW,
    required this.cardH,
    required this.innerW,
    required this.pad,
    required this.labelH,
    required this.rowGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF1E2E54)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int ri = 0; ri < topToBottom.length - 1; ri++) {
      final parentMs = byRound[topToBottom[ri]]!;
      final childMs  = byRound[topToBottom[ri + 1]]!;
      final np = parentMs.length;
      final nc = childMs.length;

      if (np == nc) {
        // 1:1 — same count (bye round): straight vertical line child→parent
        for (int mi = 0; mi < np; mi++) {
          final pNum = (parentMs[mi].data() as Map)['match_number'] as int? ?? 0;
          final cNum = (childMs[mi].data() as Map)['match_number'] as int? ?? 0;
          final pp = pos[pNum];
          final cp = pos[cNum];
          if (pp == null || cp == null) continue;
          canvas.drawLine(
            Offset(pp.dx + cardW / 2, pp.dy + cardH),
            Offset(cp.dx + cardW / 2, cp.dy),
            linePaint,
          );
        }
      } else {
        // 1:2 — each parent branches to two children
        for (int mi = 0; mi < np; mi++) {
          final pNum = (parentMs[mi].data() as Map)['match_number'] as int? ?? 0;
          final pp = pos[pNum];
          if (pp == null) continue;
          final pCX   = pp.dx + cardW / 2;
          final pBotY = pp.dy + cardH;

          final ci1 = mi * 2;
          final ci2 = mi * 2 + 1;
          if (ci1 >= nc) continue;

          final c1Num = (childMs[ci1].data() as Map)['match_number'] as int? ?? 0;
          final c1p   = pos[c1Num];
          if (c1p == null) continue;
          final c1CX   = c1p.dx + cardW / 2;
          final c1TopY = c1p.dy;
          final midY = (pBotY + c1TopY) / 2;

          // trunk from parent bottom to midY
          canvas.drawLine(Offset(pCX, pBotY), Offset(pCX, midY), linePaint);

          // left child branch
          canvas.drawLine(Offset(pCX, midY), Offset(c1CX, midY), linePaint);
          canvas.drawLine(Offset(c1CX, midY), Offset(c1CX, c1TopY), linePaint);

          // right child branch
          if (ci2 < nc) {
            final c2Num = (childMs[ci2].data() as Map)['match_number'] as int? ?? 0;
            final c2p   = pos[c2Num];
            if (c2p != null) {
              final c2CX = c2p.dx + cardW / 2;
              canvas.drawLine(Offset(pCX, midY), Offset(c2CX, midY), linePaint);
              canvas.drawLine(Offset(c2CX, midY), Offset(c2CX, c2p.dy), linePaint);
            }
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


