import 'dart:async';
import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'match_control_page.dart';
import 'registrations_page.dart';
import 'edit_tournament_page.dart';
import 'schedule_logic.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'admin_shell.dart';
import 'theme/app_colors.dart';
import 'theme/admin_ui.dart';
import 'theme/responsive_layout.dart';

class TournamentControlPage extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;

  /// Valgfri startfane (0=Oversikt 1=Kampprogram 2=Oppsett 3=Lag). Standard: Oppsett.
  final int? initialNavIndex;

  const TournamentControlPage({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    this.initialNavIndex,
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

  // Rene visningsvalg (påvirker ikke data)
  String? _selectedScheduleDate;
  String _scheduleQuery = '';
  String _teamQuery = '';
  String _teamGroupFilter = 'alle';
  String _teamSort = 'seed';

  @override
  void initState() {
    super.initState();
    if (widget.initialNavIndex != null) _selectedNavIndex = widget.initialNavIndex!;
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
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminDanger, foregroundColor: Colors.white),
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
              SelectableText(url, style: const TextStyle(fontSize: 10, color: AppColors.adminTextSecondary)),
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
  }) async {
    // Hent interleave-innstilling fra turneringen
    final tourDoc = await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .get();
    final interleave = (tourDoc.data()?['interleave_rounds'] as num?)?.toInt() ?? 0;
    return autoScheduleTournament(
      tournamentId: widget.tournamentId,
      startMinutes: startMinutes,
      matchDurationMinutes: matchDurationMinutes,
      courtsCount: courtsCount,
      startDate: startDate,
      endDate: endDate,
      breakBetweenRounds: breakBetweenRounds,
      interleaveRounds: interleave,
    );
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

        // Kampnummer (fra alle kamper i valgt klasse, før filtrering)
        final matchNumById = <String, int>{};
        for (final m in allMatches) {
          final num = (m.data() as Map)['match_number'] as int?;
          if (num != null) matchNumById[m.id] = num;
        }

        // ── Kampdager ──
        final Map<String, List<DocumentSnapshot>> byDateAll = {};
        for (final m in allMatches) {
          final date = (m.data() as Map)['match_date'] as String? ?? 'Kampdag';
          byDateAll.putIfAbsent(date, () => []).add(m);
        }
        int dateKey(String s) {
          final p = s.split('.');
          if (p.length != 3) return 99999999;
          return (int.tryParse(p[2]) ?? 9999) * 10000 + (int.tryParse(p[1]) ?? 99) * 100 + (int.tryParse(p[0]) ?? 99);
        }
        final sortedDates = byDateAll.keys.toList()..sort((a, b) => dateKey(a).compareTo(dateKey(b)));
        final now = DateTime.now();
        final todayStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
        String? activeDate = _selectedScheduleDate;
        if (activeDate == null || !byDateAll.containsKey(activeDate)) {
          activeDate = byDateAll.containsKey(todayStr) ? todayStr : (sortedDates.isNotEmpty ? sortedDates.first : null);
        }
        var dayMatches = activeDate == null ? <DocumentSnapshot>[] : List<DocumentSnapshot>.from(byDateAll[activeDate]!);

        // Pakk ut unike runder og baner for filtrene
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

        // Bruk filtrene (runde/bane/søk) – teller status før statusfilter
        if (_selectedRoundFilter != 'alle') {
           dayMatches = dayMatches.where((m) {
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
           dayMatches = dayMatches.where((m) => (m.data() as Map)['court'] == _selectedCourtFilter).toList();
        }
        final q = _scheduleQuery.trim().toLowerCase();
        if (q.isNotEmpty) {
          dayMatches = dayMatches.where((m) {
            final d = m.data() as Map<String, dynamic>;
            final num = matchNumById[m.id] ?? (d['match_number'] as int?);
            final hay = '${d['team_a_name'] ?? ''} ${d['team_b_name'] ?? ''} ${num ?? ''} #${num ?? ''}'.toLowerCase();
            return hay.contains(q);
          }).toList();
        }
        int countStatus(String s) => dayMatches.where((m) => (m.data() as Map)['status'] == s).length;
        final statusCounts = {
          'alle': dayMatches.length,
          'live': countStatus('live'),
          'scheduled': countStatus('scheduled'),
          'finished': countStatus('finished'),
        };
        if (_selectedStatusFilter != 'alle') {
           dayMatches = dayMatches.where((m) => (m.data() as Map)['status'] == _selectedStatusFilter).toList();
        }

        final sorted = List<DocumentSnapshot>.from(dayMatches)
          ..sort((a, b) {
            final am = (a.data() as Map)['scheduled_minutes'] as int? ?? 9999;
            final bm = (b.data() as Map)['scheduled_minutes'] as int? ?? 9999;
            if (am != bm) return am.compareTo(bm);
            final ac = (a.data() as Map)['court'] as String? ?? '';
            final bc = (b.data() as Map)['court'] as String? ?? '';
            return ac.compareTo(bc);
          });

        // ── Dagvelger ──
        Widget dayCard(String date) {
          final list = byDateAll[date]!;
          final fin = list.where((m) => (m.data() as Map)['status'] == 'finished').length;
          final live = list.where((m) => (m.data() as Map)['status'] == 'live').length;
          final on = date == activeDate;
          String title = date;
          final p = date.split('.');
          if (p.length == 3) {
            final dt = DateTime.tryParse('${p[2]}-${p[1].padLeft(2, '0')}-${p[0].padLeft(2, '0')}');
            if (dt != null) {
              const wd = ['Man', 'Tir', 'Ons', 'Tor', 'Fre', 'Lør', 'Søn'];
              title = '${wd[dt.weekday - 1]} ${p[0]}.${p[1]}';
            }
          }
          if (date == todayStr) title += ' · i dag';
          final allDone = fin == list.length && list.isNotEmpty;
          return InkWell(
            onTap: () => setState(() => _selectedScheduleDate = date),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(minWidth: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.adminSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: on ? AppColors.adminPrimary : AppColors.adminOutline, width: on ? 2 : 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AdminText.ui(size: 14, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('$fin / ${list.length} ferdig${live > 0 ? ' · $live LIVE' : ''}',
                      style: AdminText.ui(size: 12, color: allDone ? AppColors.green : AppColors.adminTextMuted)),
                ],
              ),
            ),
          );
        }

        // ── Tabell, gruppert per tidspunkt ──
        final Map<String, List<DocumentSnapshot>> byTime = {};
        for (final m in sorted) {
          final time = (m.data() as Map)['match_time'] as String? ?? '--:--';
          byTime.putIfAbsent(time, () => []).add(m);
        }
        final sortedTimes = byTime.keys.toList()..sort();

        final toolbar = Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AdminSearchField(
                hint: 'Søk lag eller kampnr',
                maxWidth: 280,
                onChanged: (v) => setState(() => _scheduleQuery = v),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: AdminSegmented<String>(
                  selected: _selectedStatusFilter,
                  onChanged: (v) => setState(() => _selectedStatusFilter = v),
                  items: [
                    AdminSegmentItem(value: 'alle', label: 'Alle', count: '${statusCounts['alle']}'),
                    AdminSegmentItem(value: 'live', label: 'LIVE', count: '${statusCounts['live']}'),
                    AdminSegmentItem(value: 'scheduled', label: 'Kommende', count: '${statusCounts['scheduled']}'),
                    AdminSegmentItem(value: 'finished', label: 'Ferdig', count: '${statusCounts['finished']}'),
                  ],
                ),
              ),
              if (sortedRounds.isNotEmpty)
                AdminSelect<String>(
                  label: 'Runde',
                  value: _selectedRoundFilter,
                  onChanged: (v) => setState(() => _selectedRoundFilter = v),
                  options: [
                    const AdminSegmentItem(value: 'alle', label: 'Alle'),
                    for (final r in sortedRounds) AdminSegmentItem(value: r, label: r),
                  ],
                ),
              if (sortedCourts.isNotEmpty)
                AdminSelect<String>(
                  label: 'Bane',
                  value: _selectedCourtFilter,
                  onChanged: (v) => setState(() => _selectedCourtFilter = v),
                  options: [
                    const AdminSegmentItem(value: 'alle', label: 'Alle'),
                    for (final c in sortedCourts) AdminSegmentItem(value: c, label: c),
                  ],
                ),
            ],
          ),
        );

        Widget table() {
          const minW = 1000.0;
          return LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth < minW ? minW : c.maxWidth;
            final content = SizedBox(
              width: w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: AppColors.adminTableHead,
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                    child: Row(
                      children: const [
                        SizedBox(width: 48, child: AdminTh('#')),
                        SizedBox(width: 70, child: AdminTh('Bane')),
                        Expanded(flex: 3, child: AdminTh('Klasse · runde')),
                        Expanded(flex: 2, child: AdminTh('Lag A', align: TextAlign.right)),
                        SizedBox(width: 110, child: AdminTh('Resultat', align: TextAlign.center)),
                        Expanded(flex: 2, child: AdminTh('Lag B')),
                        SizedBox(width: 100, child: AdminTh('Status')),
                        SizedBox(width: 110, child: AdminTh('Handlinger', align: TextAlign.right)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  for (final time in sortedTimes) ...[
                    _scheduleTimeHeader(time, byTime[time]!),
                    for (final m in byTime[time]!) _buildScheduleRow(m, matchNumById, catIdToName),
                  ],
                ],
              ),
            );
            if (c.maxWidth >= minW) return content;
            return SingleChildScrollView(scrollDirection: Axis.horizontal, child: content);
          });
        }

        return SingleChildScrollView(
          child: AdminPageBody(
            top: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInlineCategoryFilter(countBy: 'matches'),
                if (sortedDates.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(spacing: 10, runSpacing: 10, children: [for (final d in sortedDates) dayCard(d)]),
                ],
                const SizedBox(height: 16),
                AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      toolbar,
                      const Divider(height: 1),
                      if (allMatches.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(48),
                          child: Text("Ingen kamper satt opp ennå.",
                              textAlign: TextAlign.center,
                              style: AdminText.ui(size: 14, color: AppColors.adminTextSecondary)),
                        )
                      else if (sorted.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(48),
                          child: Text("Ingen kamper matcher filteret",
                              textAlign: TextAlign.center,
                              style: AdminText.ui(size: 14, color: AppColors.adminTextSecondary)),
                        )
                      else
                        table(),
                      Container(
                        color: AppColors.adminTableHead,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 16,
                          runSpacing: 4,
                          children: [
                            Text('Klikk på en kamp for å endre bane, tid, resultat, bytte lag eller sette walkover',
                                style: AdminText.ui(size: 13, color: AppColors.adminTextSecondary)),
                            Text('QR vises når begge lag er klare',
                                style: AdminText.ui(size: 13, color: AppColors.adminTextSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
      },
    );
  }

  Widget _scheduleTimeHeader(String time, List<DocumentSnapshot> matches) {
    final fin = matches.where((m) => (m.data() as Map)['status'] == 'finished').length;
    final live = matches.where((m) => (m.data() as Map)['status'] == 'live').length;
    final summary = '${matches.length} ${matches.length == 1 ? 'kamp' : 'kamper'} · $fin ferdig${live > 0 ? ' · $live LIVE' : ''}';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      decoration: const BoxDecoration(
        color: AppColors.adminSurface,
        border: Border(bottom: BorderSide(color: AppColors.adminDivider)),
      ),
      child: Row(
        children: [
          Text(time, style: AdminText.mono(size: 15, weight: FontWeight.w600)),
          const SizedBox(width: 12),
          Text(summary, style: AdminText.ui(size: 12, color: AppColors.adminTextSecondary)),
          const SizedBox(width: 12),
          const Expanded(child: Divider(height: 1, color: AppColors.adminOutline)),
        ],
      ),
    );
  }

  Widget _buildScheduleRow(DocumentSnapshot matchDoc, Map<String, int> matchNumById, Map<String, String> catIdToName) {
    final d = matchDoc.data() as Map<String, dynamic>;
    final matchNum = matchNumById[matchDoc.id] ?? (d['match_number'] as int?);
    final court = d['court'] as String? ?? 'TBD';
    final status = d['status'] as String? ?? 'scheduled';
    final isFinished = status == 'finished';
    final isLive = status == 'live';
    final isPending = status == 'pending';

    final catName = catIdToName[d['category_id'] as String? ?? ''] ?? '';
    final round = _roundLabel(d);
    final stageLabel = [catName, round].where((s) => s.isNotEmpty).join(' · ');

    final teamA = _resolveTeamDisplayName(d, 'team_a', matchNumById);
    final teamB = _resolveTeamDisplayName(d, 'team_b', matchNumById);
    final aPlaceholder = (d['team_a_id'] as String? ?? '') == 'placeholder';
    final bPlaceholder = (d['team_b_id'] as String? ?? '') == 'placeholder';
    final homeScore = d['home_score'] as int? ?? 0;
    final awayScore = d['away_score'] as int? ?? 0;
    final homeWins = isFinished && homeScore > awayScore;
    final awayWins = isFinished && awayScore > homeScore;

    String result = '–';
    if (isFinished) {
      result = '$homeScore – $awayScore';
    } else if (isLive) {
      result = '${d['home_sets'] ?? 0} – ${d['away_sets'] ?? 0}';
    }

    TextStyle teamStyle(bool wins, bool placeholder) => AdminText.ui(
          size: 14,
          weight: wins ? FontWeight.w700 : FontWeight.w600,
          color: wins ? AppColors.green : (placeholder ? AppColors.adminTextSecondary : AppColors.adminText),
          style: placeholder ? FontStyle.italic : null,
        );

    return AdminHoverRow(
      onTap: () => _showMatchEditDialog(matchDoc),
      background: isLive ? const Color(0xFFFEF4F3) : AppColors.adminSurface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
        child: Row(
          children: [
            SizedBox(width: 48, child: Text(matchNum != null ? '$matchNum' : '', style: AdminText.mono(size: 12, weight: FontWeight.w600, color: AppColors.adminPrimary))),
            SizedBox(width: 70, child: Text(_courtShort(court), style: AdminText.mono(size: 13, weight: FontWeight.w600))),
            Expanded(flex: 3, child: Text(stageLabel.isEmpty ? '-' : stageLabel, style: AdminText.ui(size: 13, color: AppColors.adminTextMuted), overflow: TextOverflow.ellipsis)),
            Expanded(flex: 2, child: Text(teamA, textAlign: TextAlign.right, style: teamStyle(homeWins, aPlaceholder), overflow: TextOverflow.ellipsis)),
            SizedBox(width: 110, child: Text(result, textAlign: TextAlign.center, style: AdminText.mono(size: 15, weight: FontWeight.w600))),
            Expanded(flex: 2, child: Text(teamB, style: teamStyle(awayWins, bPlaceholder), overflow: TextOverflow.ellipsis)),
            SizedBox(width: 100, child: Align(alignment: Alignment.centerLeft, child: AdminMatchStatusPill(_matchStatusLabel(d)))),
            SizedBox(
              width: 110,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AdminGhostIconButton(
                    icon: Icons.qr_code_2,
                    tooltip: isPending ? 'QR når lagene er klare' : 'Vis dommer-QR',
                    color: isPending ? AppColors.adminOutline : null,
                    onPressed: isPending ? null : () => _showQrDialog(matchDoc.id, teamA, teamB),
                  ),
                  AdminGhostIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Rediger kamp',
                    onPressed: () => _showMatchEditDialog(matchDoc),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── UI shell ─────────────────────────────────────────────────────────────

  /// Visningshjelper: kampstatus-ord (samme regler som før: LIVE, Ferdig,
  /// Walkover, Venter..., +Nmin, Planlagt).
  String _matchStatusLabel(Map<String, dynamic> d) {
    final status = d['status'] as String? ?? 'scheduled';
    if (status == 'live') return 'LIVE';
    if (status == 'finished') return (d['walkover'] as bool? ?? false) ? 'Walkover' : 'Ferdig';
    if (status == 'pending') return 'Venter...';
    final matchTime = d['match_time'] as String? ?? '';
    final matchDate = d['match_date'] as String? ?? '';
    if (status == 'scheduled' && matchTime.isNotEmpty && matchDate.isNotEmpty) {
      final parts = matchDate.split('.');
      final timeParts = matchTime.split(':');
      if (parts.length == 3 && timeParts.length == 2) {
        try {
          final scheduledDt = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]), int.parse(timeParts[0]), int.parse(timeParts[1]));
          final diff = DateTime.now().difference(scheduledDt).inMinutes;
          if (diff > 0) return '+${diff}min';
        } catch (_) {}
      }
    }
    return 'Planlagt';
  }

  /// Visningshjelper: «Pulje A – K4» / «A-Bracket KF».
  String _roundLabel(Map<String, dynamic> d) {
    final stage = d['stage'] as String? ?? '';
    if (stage == 'group') {
      final mType = d['match_type'] as String? ?? '';
      final matchLabel = {'group_match_1':' – K1','group_match_2':' – K2','group_match_3':' – K3','group_match_4':' – K4'}[mType] ?? '';
      return 'Pulje ${d['group'] ?? '?'}$matchLabel';
    }
    if (stage == 'playoff') {
      final bl = (d['bracket'] as String?)?.toUpperCase() ?? '';
      final rl = const {'r16':'R16','r8':'R8','qf':'KF','sf':'SF','final':'Finale','omspill':'Omspill'}[d['round']] ?? '';
      return '$bl-Bracket $rl'.trim();
    }
    return '';
  }

  String _liveScoreLine(Map<String, dynamic> d, bool home) {
    final past = (d['past_sets'] as List?) ?? const [];
    final parts = <String>[];
    for (final s in past) {
      if (s is Map) parts.add('${s[home ? 'home' : 'away']}');
    }
    parts.add('${d[home ? 'home_score' : 'away_score'] ?? 0}');
    return parts.join(' · ');
  }

  String _courtShort(String? court) {
    final c = (court ?? '').trim();
    if (c.isEmpty || c == 'TBD') return '–';
    return c.toLowerCase().startsWith('bane ') ? c.substring(5) : c;
  }

  Future<void> _openRegistrations() async {
    final doc = await FirebaseFirestore.instance
        .collection('tournaments').doc(widget.tournamentId).get();
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => RegistrationsPage(
        tournamentId: widget.tournamentId,
        tournamentName: widget.tournamentName,
        tournamentType:
            (doc.data()?['tournament_type'] as String?) ?? 'nt_master',
      ),
    ));
  }

  Future<void> _openEditTournament() async {
    final doc = await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .get();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditTournamentPage(
          tournamentId: widget.tournamentId,
          initialData: doc.data() ?? {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.getBreakpoint(context).index < ResponsiveBreakpoint.tablet.index;
    final isDesktop = Responsive.isDesktopOrLarger(context);

    final page = Column(
      children: [
        _buildHeader(context, showTabs: !isMobile),
        Expanded(child: _buildNavContent()),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.adminBg,
      body: isDesktop
          ? Row(
              children: [
                AdminSidebar(
                  selectedIndex: 0,
                  showLiveCounts: true,
                  onDestinationSelected: (index) {
                    if (index == 3) {
                      FirebaseAuth.instance.signOut();
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    } else {
                      AdminShell.navRequest.value = index;
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    }
                  },
                ),
                Expanded(child: page),
              ],
            )
          : SafeArea(bottom: false, child: page),
      bottomNavigationBar: isMobile
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
    );
  }

  // ─── Turneringshode: brødsmuler, tittel, status, handlinger, faner ──────────

  Widget _buildHeader(BuildContext context, {required bool showTabs}) {
    final db = FirebaseFirestore.instance;
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('tournaments').doc(widget.tournamentId).snapshots(),
      builder: (ctx, tourSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: db.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
          builder: (ctx, catSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: db.collection('matches').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
              builder: (ctx, matchSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: db.collection('teams').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
                  builder: (ctx, teamSnap) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: db.collection('registrations').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
                      builder: (ctx, regSnap) {
                        final t = tourSnap.data?.data() as Map<String, dynamic>? ?? {};
                        final cats = catSnap.data?.docs ?? const [];
                        final matches = matchSnap.data?.docs ?? const [];
                        final teamCount = teamSnap.data?.docs.length ?? 0;
                        final pendingRegs = (regSnap.data?.docs ?? const [])
                            .where((d) => (d.data() as Map)['status'] == 'pending')
                            .length;
                        final isPub = cats.isNotEmpty && (cats.first.data() as Map)['published'] == true;
                        final liveCount = matches.where((m) => (m.data() as Map)['status'] == 'live').length;
                        final regOpen = (t['registration_status'] as String? ?? 'open') == 'open';
                        return _buildHeaderContent(
                          context,
                          data: t,
                          isPublished: isPub,
                          hasMatches: matches.isNotEmpty,
                          matchCount: matches.length,
                          teamCount: teamCount,
                          liveCount: liveCount,
                          pendingRegs: pendingRegs,
                          registrationOpen: regOpen,
                          showTabs: showTabs,
                        );
                      },
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

  String _headerDateRange(String? s, String? e) {
    DateTime? p(String? v) {
      final parts = (v ?? '').split('.');
      if (parts.length != 3) return null;
      final d = int.tryParse(parts[0]), m = int.tryParse(parts[1]), y = int.tryParse(parts[2]);
      if (d == null || m == null || y == null) return null;
      return DateTime(y, m, d);
    }
    String two(int n) => n.toString().padLeft(2, '0');
    final a = p(s), b = p(e);
    if (a == null || b == null) return [s, e].whereType<String>().where((x) => x.isNotEmpty).join(' – ');
    if (a == b) return '${two(a.day)}.${two(a.month)}.${a.year}';
    if (a.year == b.year && a.month == b.month) return '${two(a.day)}.–${two(b.day)}.${two(b.month)}.${b.year}';
    return '${two(a.day)}.${two(a.month)}.–${two(b.day)}.${two(b.month)}.${b.year}';
  }

  Widget _buildHeaderContent(
    BuildContext context, {
    required Map<String, dynamic> data,
    required bool isPublished,
    required bool hasMatches,
    required int matchCount,
    required int teamCount,
    required int liveCount,
    required int pendingRegs,
    required bool registrationOpen,
    required bool showTabs,
  }) {
    final pad = AdminPageBody.padFor(context);
    final name = (data['name'] as String?) ?? widget.tournamentName;
    final typeLabel = (data['tournament_type_label'] as String?) ?? '';
    final location = (data['location'] as String?) ?? '';
    final courts = (data['courts_count'] as num?)?.toInt();
    final dates = _headerDateRange(data['start_date'] as String?, data['end_date'] as String?);
    final isMobile = !showTabs;

    final metaParts = <InlineSpan>[];
    void addMeta(InlineSpan s) {
      if (metaParts.isNotEmpty) metaParts.add(const TextSpan(text: ' · '));
      metaParts.add(s);
    }
    if (typeLabel.isNotEmpty) addMeta(TextSpan(text: typeLabel));
    if (location.isNotEmpty) addMeta(TextSpan(text: location));
    if (dates.isNotEmpty) addMeta(TextSpan(text: dates, style: AdminText.mono(size: 13, color: AppColors.adminTextSecondary)));
    if (courts != null) addMeta(TextSpan(text: '$courts baner'));

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        AdminButton(
          label: 'Påmeldinger',
          icon: Icons.how_to_reg_outlined,
          badge: pendingRegs > 0 ? AdminPill.count('$pendingRegs') : null,
          onPressed: _openRegistrations,
        ),
        AdminButton(
          label: 'Rediger turnering',
          icon: Icons.edit_outlined,
          onPressed: _openEditTournament,
        ),
        if (hasMatches)
          AdminButton(
            label: isPublished ? 'Skjul turnering' : 'Publiser turnering',
            icon: isPublished ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            onPressed: () { if (isPublished) { _unpublishCategory(); } else { _publishCategory(); } },
          ),
        PopupMenuButton<String>(
          tooltip: "Avanserte handlinger",
          position: PopupMenuPosition.under,
          onSelected: (v) {
            if (v == 'sync') _resolvePendingMatches().then((_) => _snack("Synkronisert."));
            if (v == 'reset') _resetTournament();
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'sync',
              child: ListTile(
                leading: const Icon(Icons.sync, color: AppColors.adminPrimary),
                title: Text("Sync bracket", style: AdminText.ui(size: 14, weight: FontWeight.w600)),
                subtitle: Text("Oppdater kryssninger manuelt", style: AdminText.ui(size: 12, color: AppColors.adminTextSecondary)),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'reset',
              child: ListTile(
                leading: const Icon(Icons.restart_alt, color: AppColors.adminDanger),
                title: Text("Nullstill hele turneringen", style: AdminText.ui(size: 14, weight: FontWeight.w600, color: AppColors.adminDangerText)),
                subtitle: Text("Sletter alle kamper, beholder lag", style: AdminText.ui(size: 12, color: AppColors.adminTextSecondary)),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.adminSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.adminOutline),
            ),
            child: const Icon(Icons.more_horiz, size: 20, color: AppColors.adminTextMuted),
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.adminSurface,
        border: Border(bottom: BorderSide(color: AppColors.adminOutline)),
      ),
      padding: EdgeInsets.fromLTRB(pad, isMobile ? 12 : 20, pad, showTabs ? 0 : 16),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Brødsmuler
              Row(
                children: [
                  if (isMobile) ...[
                    AdminGhostIconButton(
                      icon: Icons.arrow_back,
                      size: 36,
                      tooltip: 'Tilbake',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 4),
                  ],
                  InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Text('Turneringer', style: AdminText.ui(size: 13, color: AppColors.adminTextSecondary)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('›', style: AdminText.ui(size: 13, color: AppColors.adminTextSecondary)),
                  ),
                  Flexible(
                    child: Text(name, style: AdminText.ui(size: 13), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, hc) => Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isMobile) ...[
                        const AdminIconTile(icon: Icons.emoji_events_outlined, size: 56, iconSize: 26, radius: 12),
                        const SizedBox(width: 16),
                      ],
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: (hc.maxWidth - (isMobile ? 0 : 72)).clamp(120.0, 640.0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(name, style: AdminText.ui(size: isMobile ? 22 : 26, weight: FontWeight.w700)),
                                if (liveCount > 0) const AdminPill.live(dot: true),
                                if (hasMatches)
                                  isPublished ? const AdminPill.success('Publisert') : const AdminPill.neutral('Skjult'),
                                registrationOpen
                                    ? const AdminPill.success('Påmelding åpen')
                                    : const AdminPill.neutral('Påmelding stengt'),
                              ],
                            ),
                            if (metaParts.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text.rich(
                                TextSpan(children: metaParts),
                                style: AdminText.ui(size: 14, color: AppColors.adminTextSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions,
                ],
              )),
              if (showTabs) ...[
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      AdminTab(label: 'Oversikt', selected: _selectedNavIndex == 0, onTap: () => setState(() => _selectedNavIndex = 0)),
                      AdminTab(label: 'Kampprogram', count: matchCount > 0 ? '$matchCount' : null, selected: _selectedNavIndex == 1, onTap: () => setState(() => _selectedNavIndex = 1)),
                      AdminTab(label: 'Oppsett', selected: _selectedNavIndex == 2, onTap: () => setState(() => _selectedNavIndex = 2)),
                      AdminTab(label: 'Lag', count: teamCount > 0 ? '$teamCount' : null, selected: _selectedNavIndex == 3, onTap: () => setState(() => _selectedNavIndex = 3)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('registrations').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
                      builder: (ctx5, regSnap) {
                    if (!matchSnap.hasData || !teamSnap.hasData || !catSnap.hasData || !tourSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allMatches = matchSnap.data!.docs;
                    final allTeams = teamSnap.data!.docs;
                    var matches = allMatches;
                    var teams = allTeams;

                    if (_selectedCategoryId != null && _selectedCategoryId != 'all') {
                      matches = matches.where((m) => (m.data() as Map)['category_id'] == _selectedCategoryId).toList();
                      teams = teams.where((t) => (t.data() as Map)['category_id'] == _selectedCategoryId).toList();
                    }

                    final categories = catSnap.data!.docs;
                    final tourData = tourSnap.data?.data() as Map<String, dynamic>? ?? {};

                    final courtsCount = (tourData['courts_count'] as num?)?.toInt() ?? 4;
                    final totalMatches = matches.length;
                    final totalTeams = teams.length;
                    final finishedCount = matches.where((m) => (m.data() as Map)['status'] == 'finished').length;

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

                    // ── Avledede visningstall ──
                    final liveMatches = matches.where((m) => (m.data() as Map)['status'] == 'live').toList()
                      ..sort((a, b) => '${(a.data() as Map)['court'] ?? ''}'.compareTo('${(b.data() as Map)['court'] ?? ''}'));
                    final courtsInUse = liveMatches
                        .map((m) => (m.data() as Map)['court'] as String?)
                        .whereType<String>()
                        .toSet()
                        .length;
                    final groupCount = matches.where((m) => (m.data() as Map)['stage'] == 'group').length;
                    final playoffCount = matches.where((m) => (m.data() as Map)['stage'] == 'playoff').length;
                    final classCount = (_selectedCategoryId != null && _selectedCategoryId != 'all') ? 1 : categories.length;

                    // Neste kamper: tidligste tidspunkt blant kamper som ikke er startet
                    final upcoming = matches.where((m) {
                      final s = (m.data() as Map)['status'];
                      return s == 'scheduled' || s == 'pending';
                    }).toList();
                    int sortKey(DocumentSnapshot m) {
                      final d = m.data() as Map;
                      final date = (d['match_date'] as String? ?? '').split('.');
                      final time = (d['match_time'] as String? ?? '').split(':');
                      if (date.length != 3 || time.length != 2) return 999999999999;
                      return ((int.tryParse(date[2]) ?? 9999) * 10000 + (int.tryParse(date[1]) ?? 99) * 100 + (int.tryParse(date[0]) ?? 99)) * 10000 +
                          (int.tryParse(time[0]) ?? 99) * 100 + (int.tryParse(time[1]) ?? 99);
                    }
                    upcoming.sort((a, b) => sortKey(a).compareTo(sortKey(b)));
                    String? nextTime;
                    String? nextDate;
                    List<DocumentSnapshot> nextMatches = [];
                    if (upcoming.isNotEmpty) {
                      final first = upcoming.first.data() as Map;
                      nextTime = first['match_time'] as String?;
                      nextDate = first['match_date'] as String?;
                      nextMatches = upcoming.where((m) {
                        final d = m.data() as Map;
                        return d['match_time'] == nextTime && d['match_date'] == nextDate;
                      }).toList()
                        ..sort((a, b) => '${(a.data() as Map)['court'] ?? ''}'.compareTo('${(b.data() as Map)['court'] ?? ''}'));
                    }

                    // Trenger oppmerksomhet
                    final pendingRegs = (regSnap.data?.docs ?? const [])
                        .where((d) => (d.data() as Map)['status'] == 'pending')
                        .length;
                    final delayed = <String, String>{}; // bane -> +Nmin
                    for (final m in matches) {
                      final d = m.data() as Map<String, dynamic>;
                      final label = _matchStatusLabel(d);
                      if (label.startsWith('+')) {
                        final court = d['court'] as String? ?? '';
                        delayed.putIfAbsent(court.isEmpty ? 'Ukjent bane' : court, () => label);
                      }
                    }
                    final notGenerated = categories.where((c) {
                      if (_selectedCategoryId != null && _selectedCategoryId != 'all' && c.id != _selectedCategoryId) return false;
                      final hasTeams = allTeams.any((t) => (t.data() as Map)['category_id'] == c.id);
                      final hasM = allMatches.any((m) => (m.data() as Map)['category_id'] == c.id);
                      return hasTeams && !hasM;
                    }).toList();

                    final attention = <Widget>[
                      for (final e in delayed.entries.take(3))
                        _attentionRow(AdminPill.delayed(e.value), '${e.key} ligger etter skjema', onTap: () => setState(() => _selectedNavIndex = 1)),
                      if (pendingRegs > 0)
                        _attentionRow(AdminPill.info('$pendingRegs'),
                            pendingRegs == 1 ? 'Påmelding venter godkjenning' : 'Påmeldinger venter godkjenning',
                            onTap: _openRegistrations),
                      for (final c in notGenerated.take(3))
                        _attentionRow(const AdminPill.neutral('Venter...'),
                            'Oppsett ikke generert for ${(c.data() as Map)['name'] ?? 'klasse'}',
                            onTap: () => setState(() { _selectedCategoryId = c.id; _selectedNavIndex = 2; })),
                    ];

                    // Fremdrift per klasse
                    final classRows = <Widget>[];
                    for (final c in categories) {
                      if (_selectedCategoryId != null && _selectedCategoryId != 'all' && c.id != _selectedCategoryId) continue;
                      final cm = allMatches.where((m) => (m.data() as Map)['category_id'] == c.id).toList();
                      final ct = allTeams.where((t) => (t.data() as Map)['category_id'] == c.id).length;
                      final done = cm.where((m) => (m.data() as Map)['status'] == 'finished').length;
                      String phase;
                      if (cm.isEmpty) {
                        phase = 'Oppsett ikke generert';
                      } else if (done == cm.length) {
                        phase = 'Ferdig';
                      } else if (cm.any((m) {
                        final d = m.data() as Map;
                        return d['stage'] == 'playoff' && (d['status'] == 'live' || d['status'] == 'finished');
                      })) {
                        phase = 'Sluttspill pågår';
                      } else {
                        phase = 'Gruppespill';
                      }
                      classRows.add(Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.adminDivider))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              Expanded(child: Text('${(c.data() as Map)['name'] ?? 'Klasse'}', style: AdminText.ui(size: 14, weight: FontWeight.w600))),
                              Text('$done / ${cm.length}', style: AdminText.mono(size: 12, color: AppColors.adminTextMuted)),
                            ]),
                            const SizedBox(height: 8),
                            AdminProgressBar(value: cm.isEmpty ? 0 : done / cm.length, color: AppColors.green, height: 6),
                            const SizedBox(height: 6),
                            Text('$ct lag · $phase', style: AdminText.ui(size: 12, color: AppColors.adminTextSecondary)),
                          ],
                        ),
                      ));
                    }

                    Widget statCard(String title, Widget value, Widget? sub) {
                      return AdminCard(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(title, style: AdminText.ui(size: 13, color: AppColors.adminTextSecondary)),
                            const SizedBox(height: 6),
                            value,
                            if (sub != null) sub,
                          ],
                        ),
                      );
                    }
                    final bigNum = AdminText.ui(size: 30, weight: FontWeight.w700);
                    final subStyle = AdminText.ui(size: 12, color: AppColors.adminTextSecondary);

                    final stats = [
                      statCard("Påmeldte lag", Text("$totalTeams", style: bigNum),
                          Text(classCount == 1 ? '1 klasse' : '$classCount klasser', style: subStyle)),
                      statCard("Antall baner", Text("$courtsCount", style: bigNum),
                          Text('$courtsInUse i bruk nå', style: subStyle)),
                      statCard("Kamper totalt", Text("$totalMatches", style: bigNum),
                          Text('$groupCount gruppespill · $playoffCount sluttspill', style: subStyle, overflow: TextOverflow.ellipsis)),
                      statCard(
                        "Ferdigspilte",
                        Text.rich(TextSpan(children: [
                          TextSpan(text: '$finishedCount', style: bigNum),
                          TextSpan(text: ' / $totalMatches', style: AdminText.ui(size: 15, weight: FontWeight.w500, color: AppColors.adminTextSecondary)),
                        ])),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: AdminProgressBar(value: totalMatches == 0 ? 0 : finishedCount / totalMatches, color: AppColors.green, height: 6),
                        ),
                      ),
                    ];

                    Widget barGroup(String title, Map<String, int> values, Color color) {
                      final entries = values.entries.where((e) => e.value > 0).toList();
                      final total = entries.fold<int>(0, (a, e) => a + e.value);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(title, style: AdminText.ui(size: 14, weight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          if (entries.isEmpty)
                            Text('Ingen kamper', style: AdminText.ui(size: 13, color: AppColors.adminTextSecondary)),
                          for (final e in entries) ...[
                            Row(children: [
                              Expanded(child: Text(e.key, style: AdminText.ui(size: 13))),
                              Text('${e.value}', style: AdminText.mono(size: 13)),
                            ]),
                            const SizedBox(height: 6),
                            AdminProgressBar(value: total == 0 ? 0 : e.value / total, color: color, height: 6),
                            const SizedBox(height: 10),
                          ],
                        ],
                      );
                    }

                    final liveCard = AdminCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AdminCardHeader(
                            title: 'LIVE nå',
                            count: Text('${liveMatches.length}', style: AdminText.mono(size: 13, color: AppColors.adminTextSecondary)),
                            trailing: InkWell(
                              onTap: () => setState(() => _selectedNavIndex = 1),
                              child: Text('Se kampprogram', style: AdminText.ui(size: 14, weight: FontWeight.w600, color: AppColors.adminPrimary)),
                            ),
                          ),
                          if (liveMatches.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text('Ingen kamper pågår akkurat nå.', style: AdminText.ui(size: 14, color: AppColors.adminTextSecondary)),
                            ),
                          for (final m in liveMatches) _overviewLiveRow(m, catIdToName),
                        ],
                      ),
                    );

                    final nextCard = AdminCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AdminCardHeader(
                            title: nextTime == null ? 'Neste kamper' : 'Neste kamper · $nextTime',
                            trailing: Text(nextMatches.length == 1 ? '1 kamp' : '${nextMatches.length} kamper',
                                style: AdminText.ui(size: 13, color: AppColors.adminTextSecondary)),
                          ),
                          if (nextMatches.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text('Ingen kommende kamper.', style: AdminText.ui(size: 14, color: AppColors.adminTextSecondary)),
                            ),
                          for (final m in nextMatches) _overviewNextRow(m, catIdToName),
                        ],
                      ),
                    );

                    final attentionCard = AdminCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AdminCardHeader(title: 'Trenger oppmerksomhet'),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                            child: attention.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Row(children: [
                                      const Icon(Icons.check_circle_outline, size: 18, color: AppColors.green),
                                      const SizedBox(width: 8),
                                      Text('Alt ser bra ut', style: AdminText.ui(size: 14)),
                                    ]),
                                  )
                                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: attention),
                          ),
                        ],
                      ),
                    );

                    final progressCard = AdminCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AdminCardHeader(title: 'Fremdrift per klasse'),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                            child: classRows.isEmpty
                                ? Text('Ingen klasser funnet.', style: AdminText.ui(size: 14, color: AppColors.adminTextSecondary))
                                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: classRows),
                          ),
                        ],
                      ),
                    );

                    final splitCard = AdminCard(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: LayoutBuilder(builder: (context, c) {
                        final gender = barGroup('Kamper per kjønn', matchesPerGender, AppColors.adminPrimary);
                        final level = barGroup('Kamper per nivå', matchesPerLevel, AppColors.adminSidebarBg);
                        if (c.maxWidth < 300) {
                          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [gender, const SizedBox(height: 8), level]);
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [Expanded(child: gender), const SizedBox(width: 20), Expanded(child: level)],
                        );
                      }),
                    );

                    return SingleChildScrollView(
                      child: AdminPageBody(
                        top: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildInlineCategoryFilter(countBy: 'teams'),
                            const SizedBox(height: 20),
                            LayoutBuilder(builder: (context, c) {
                              const gap = 16.0;
                              final cols = c.maxWidth >= 860 ? 4 : 2;
                              final w = (c.maxWidth - gap * (cols - 1)) / cols - 0.1;
                              return Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: [for (final s in stats) SizedBox(width: w, child: s)],
                              );
                            }),
                            const SizedBox(height: 20),
                            LayoutBuilder(builder: (context, c) {
                              final left = Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [liveCard, const SizedBox(height: 20), nextCard],
                              );
                              final right = Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [attentionCard, const SizedBox(height: 20), progressCard, const SizedBox(height: 20), splitCard],
                              );
                              if (c.maxWidth < 900) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [left, const SizedBox(height: 20), right],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 7, child: left),
                                  const SizedBox(width: 20),
                                  Expanded(flex: 5, child: right),
                                ],
                              );
                            }),
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
      },
    );
  }

  Widget _attentionRow(Widget pill, String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            pill,
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: AdminText.ui(size: 14))),
          ],
        ),
      ),
    );
  }

  Widget _overviewLiveRow(DocumentSnapshot m, Map<String, String> catIdToName) {
    final d = m.data() as Map<String, dynamic>;
    final num = d['match_number'] as int?;
    final cat = catIdToName[d['category_id'] as String? ?? ''] ?? '';
    final round = _roundLabel(d);
    final label = [cat, round].where((s) => s.isNotEmpty).join(' · ');
    final teamStyle = AdminText.ui(size: 14, weight: FontWeight.w600);
    return InkWell(
      onTap: () => _showMatchEditDialog(m),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.adminDivider))),
        child: Row(
          children: [
            SizedBox(
              width: 74,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BANE ${_courtShort(d['court'] as String?)}', style: AdminText.mono(size: 12, weight: FontWeight.w600, color: AppColors.adminPrimary)),
                  if (num != null) Text('#$num', style: AdminText.ui(size: 12, color: AppColors.adminTextSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (label.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(label, style: AdminText.ui(size: 12, color: AppColors.adminTextSecondary), overflow: TextOverflow.ellipsis),
                    ),
                  Row(children: [
                    Expanded(child: Text('${d['team_a_name'] ?? 'TBD'}', style: teamStyle, overflow: TextOverflow.ellipsis)),
                    Text(_liveScoreLine(d, true), style: AdminText.mono(size: 14, weight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    Expanded(child: Text('${d['team_b_name'] ?? 'TBD'}', style: teamStyle, overflow: TextOverflow.ellipsis)),
                    Text(_liveScoreLine(d, false), style: AdminText.mono(size: 14, weight: FontWeight.w600)),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const AdminPill.live(),
          ],
        ),
      ),
    );
  }

  Widget _overviewNextRow(DocumentSnapshot m, Map<String, String> catIdToName) {
    final d = m.data() as Map<String, dynamic>;
    final cat = catIdToName[d['category_id'] as String? ?? ''] ?? '';
    final round = _roundLabel(d);
    final label = [cat, round].where((s) => s.isNotEmpty).join(' · ');
    final numById = <String, int>{};
    final a = _resolveTeamDisplayName(d, 'team_a', numById);
    final b = _resolveTeamDisplayName(d, 'team_b', numById);
    final isPending = (d['status'] as String? ?? '') == 'pending';
    final teamStyle = AdminText.ui(size: 14, style: isPending ? FontStyle.italic : null,
        color: isPending ? AppColors.adminTextSecondary : AppColors.adminText);
    return InkWell(
      onTap: () => _showMatchEditDialog(m),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.adminDivider))),
        child: Row(
          children: [
            SizedBox(
              width: 74,
              child: Text('BANE ${_courtShort(d['court'] as String?)}', style: AdminText.mono(size: 12, weight: FontWeight.w600, color: AppColors.adminPrimary)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: a, style: teamStyle),
                  TextSpan(text: '  vs  ', style: AdminText.ui(size: 14, color: AppColors.adminTextSecondary)),
                  TextSpan(text: b, style: teamStyle),
                ]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (label.isNotEmpty && Responsive.isTabletOrLarger(context)) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: 170,
                child: Text(label, style: AdminText.ui(size: 12, color: AppColors.adminTextSecondary), overflow: TextOverflow.ellipsis),
              ),
            ],
            const SizedBox(width: 12),
            AdminMatchStatusPill(_matchStatusLabel(d)),
          ],
        ),
      ),
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

  /// Klasse-filter som avrundede knapper (Alle klasser + hver klasse med antall).
  /// [countBy] = 'teams' | 'matches' – hva tallet ved hver klasse viser.
  Widget _buildInlineCategoryFilter({String countBy = 'teams'}) {
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

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(countBy == 'matches' ? 'matches' : 'teams')
              .where('tournament_id', isEqualTo: widget.tournamentId)
              .snapshots(),
          builder: (ctx, countSnap) {
            final counts = <String, int>{};
            for (final d in countSnap.data?.docs ?? const <QueryDocumentSnapshot>[]) {
              final cid = (d.data() as Map)['category_id'] as String? ?? '';
              counts[cid] = (counts[cid] ?? 0) + 1;
            }
            final total = countSnap.data?.docs.length;
            return AdminScopeChips<String>(
              label: 'Klasse',
              selected: _selectedCategoryId ?? 'all',
              onChanged: (v) => setState(() => _selectedCategoryId = v),
              items: [
                AdminSegmentItem(value: 'all', label: 'Alle klasser', count: total == null ? null : '$total'),
                ...cats.map((c) {
                  final data = c.data() as Map<String, dynamic>;
                  return AdminSegmentItem(
                    value: c.id,
                    label: data['name'] ?? 'Klasse',
                    count: countSnap.hasData ? '${counts[c.id] ?? 0}' : null,
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Lag-fanen ────────────────────────────────────────────────────────────

  Widget _buildTeamsTab() {
    Widget content;
    if (_selectedCategoryId == null) {
      content = const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text("Velg en klasse i menyen over.")),
      );
    } else if (_selectedCategoryId == 'all') {
      content = StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("Ingen klasser funnet."));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final doc in docs) ...[
                _buildTeamsTabForCategory(doc.id, (doc.data() as Map)['name']),
                const SizedBox(height: 16),
              ],
            ],
          );
        }
      );
    } else {
      content = _buildTeamsTabForCategory(_selectedCategoryId!, null);
    }

    return SingleChildScrollView(
      child: AdminPageBody(
        top: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInlineCategoryFilter(countBy: 'teams'),
            const SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }

  Widget _teamToolsMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Testverktøy',
      position: PopupMenuPosition.under,
      onSelected: (v) {
        if (v == 'auto') _autoGenerateTeams();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'auto',
          child: Row(children: [
            const Icon(Icons.auto_awesome, size: 18, color: AppColors.adminPrimaryHover),
            const SizedBox(width: 10),
            Text("Auto-generer 16 testlag (fra spillerdatabase)", style: AdminText.ui(size: 14)),
          ]),
        ),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.adminSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.adminOutline),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.auto_awesome, size: 18, color: AppColors.adminText),
          const SizedBox(width: 8),
          Text('Testverktøy', style: AdminText.ui(size: 14, weight: FontWeight.w600)),
          const SizedBox(width: 6),
          const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.adminTextSecondary),
        ]),
      ),
    );
  }

  Widget _buildTeamsTabForCategory(String categoryId, String? categoryName) {
    return AdminCard(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('teams').where('tournament_id', isEqualTo: widget.tournamentId).where('category_id', isEqualTo: categoryId).snapshots(),
        builder: (ctx, snap) {
          final teams = snap.data?.docs ?? const <QueryDocumentSnapshot>[];
          final groups = teams
              .map((t) => (t.data() as Map)['group'] as String?)
              .whereType<String>()
              .toSet()
              .toList()
            ..sort();

          // Visningsfiltre
          final q = _teamQuery.trim().toLowerCase();
          var shown = teams.where((t) {
            final d = t.data() as Map;
            if (_teamGroupFilter != 'alle' && d['group'] != _teamGroupFilter) return false;
            if (q.isEmpty) return true;
            final hay = '${d['team_name'] ?? ''} ${d['player1_name'] ?? ''} ${d['player2_name'] ?? ''}'.toLowerCase();
            return hay.contains(q);
          }).toList();

          shown = List<QueryDocumentSnapshot>.from(shown)
            ..sort((a, b) {
              final da = a.data() as Map, dbb = b.data() as Map;
              if (_teamSort == 'name') {
                return '${da['team_name'] ?? ''}'.toLowerCase().compareTo('${dbb['team_name'] ?? ''}'.toLowerCase());
              }
              final ap  = da['team_points'] as num? ?? 0;
              final bp  = dbb['team_points'] as num? ?? 0;
              if (_teamSort == 'points') return bp.compareTo(ap);
              final as_ = da['seed'] as int? ?? 999;
              final bs  = dbb['seed'] as int? ?? 999;
              if (as_ != 999 || bs != 999) return as_.compareTo(bs);
              return bp.compareTo(ap);
            });

          final toolbar = Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AdminSearchField(
                        hint: 'Søk lag eller spiller',
                        maxWidth: 300,
                        onChanged: (v) => setState(() => _teamQuery = v),
                      ),
                      if (groups.isNotEmpty)
                        AdminSelect<String>(
                          label: 'Pulje',
                          value: groups.contains(_teamGroupFilter) ? _teamGroupFilter : 'alle',
                          onChanged: (v) => setState(() => _teamGroupFilter = v),
                          options: [
                            const AdminSegmentItem(value: 'alle', label: 'Alle'),
                            for (final g in groups) AdminSegmentItem(value: g, label: 'Pulje $g'),
                          ],
                        ),
                      AdminSelect<String>(
                        label: 'Sorter',
                        value: _teamSort,
                        onChanged: (v) => setState(() => _teamSort = v),
                        options: const [
                          AdminSegmentItem(value: 'seed', label: 'Seed'),
                          AdminSegmentItem(value: 'points', label: 'Poeng'),
                          AdminSegmentItem(value: 'name', label: 'Navn'),
                        ],
                      ),
                      _teamToolsMenu(),
                      AdminButton.primary(
                        label: 'Nytt lag',
                        icon: Icons.group_add_outlined,
                        onPressed: _showAddTeamDialog,
                      ),
                    ],
                  ),
          );

          Widget body;
          if (!snap.hasData) {
            body = const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
          } else if (teams.isEmpty) {
            body = Padding(
              padding: const EdgeInsets.all(40),
              child: Text("Ingen lag registrert enda.\nTrykk «Nytt lag» for å legge til lag.",
                  textAlign: TextAlign.center,
                  style: AdminText.ui(size: 14, color: AppColors.adminTextSecondary)),
            );
          } else if (shown.isEmpty) {
            body = Padding(
              padding: const EdgeInsets.all(40),
              child: Text("Ingen lag matcher filteret.",
                  textAlign: TextAlign.center,
                  style: AdminText.ui(size: 14, color: AppColors.adminTextSecondary)),
            );
          } else {
            body = LayoutBuilder(builder: (context, c) {
              const minW = 820.0;
              final w = c.maxWidth < minW ? minW : c.maxWidth;
              final table = SizedBox(
                width: w,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: AppColors.adminTableHead,
                      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                      child: Row(children: const [
                        SizedBox(width: 60, child: AdminTh('Seed')),
                        Expanded(flex: 2, child: AdminTh('Lag')),
                        Expanded(flex: 3, child: AdminTh('Spillere')),
                        SizedBox(width: 80, child: AdminTh('Poeng', align: TextAlign.right)),
                        SizedBox(width: 24),
                        SizedBox(width: 130, child: AdminTh('Pulje')),
                        SizedBox(width: 100, child: AdminTh('Handlinger', align: TextAlign.right)),
                      ]),
                    ),
                    const Divider(height: 1),
                    for (final t in shown) _teamRow(t),
                  ],
                ),
              );
              if (c.maxWidth >= minW) return table;
              return SingleChildScrollView(scrollDirection: Axis.horizontal, child: table);
            });
          }

          final footerText = '${teams.length} lag${categoryName != null ? ' i $categoryName' : ''}'
              '${groups.isNotEmpty ? ' · ${groups.length} ${groups.length == 1 ? 'pulje' : 'puljer'}' : ''}';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (categoryName != null) AdminCardHeader(title: categoryName),
              toolbar,
              const Divider(height: 1),
              body,
              Container(
                color: AppColors.adminTableHead,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(footerText, style: AdminText.ui(size: 13, color: AppColors.adminTextSecondary)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _teamRow(DocumentSnapshot teamDoc) {
    final d = teamDoc.data() as Map<String, dynamic>;
    final seed = d['seed'] as int?;
    final group = d['group'] as String?;
    final placement = d['group_placement'] as int?;
    final points = (d['team_points'] as num?)?.toInt();
    final players = [d['player1_name'], d['player2_name']]
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .join(' · ');
    return AdminHoverRow(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: seed != null ? AppColors.adminMuted : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: seed != null ? null : Border.all(color: AppColors.adminOutline),
                  ),
                  child: Text(seed?.toString() ?? '-', style: AdminText.mono(size: 13, weight: FontWeight.w600)),
                ),
              ),
            ),
            Expanded(flex: 2, child: Text(d['team_name'] ?? 'Ukjent Lag', style: AdminText.ui(size: 14, weight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
            Expanded(flex: 3, child: Text(players, style: AdminText.ui(size: 13, color: AppColors.adminTextMuted), overflow: TextOverflow.ellipsis)),
            SizedBox(width: 80, child: Text(points?.toString() ?? '–', textAlign: TextAlign.right, style: AdminText.mono(size: 13))),
            const SizedBox(width: 24),
            SizedBox(
              width: 130,
              child: Align(
                alignment: Alignment.centerLeft,
                child: group != null
                    ? AdminPill(
                        label: "Pulje $group${placement != null ? ' · $placement.' : ''}",
                        background: AppColors.adminSurfaceElevated,
                        foreground: AppColors.adminTextBody,
                      )
                    : Text('–', style: AdminText.ui(size: 13, color: AppColors.adminTextSecondary)),
              ),
            ),
            SizedBox(
              width: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AdminGhostIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: "Rediger / Flytt",
                    onPressed: () => _showTeamEditDialog(teamDoc),
                  ),
                  AdminGhostIconButton(
                    icon: Icons.delete_outline,
                    color: AppColors.adminDanger,
                    tooltip: "Slett lag",
                    onPressed: () => _confirmDeleteTeam(teamDoc.id, d['team_name'] ?? 'laget'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Oppsett-seksjon (klasseliste + steg + kort) ───────────────────────────

  Widget _buildOppsettSection() {
    Widget content;
    if (_selectedCategoryId == null) {
      content = const Padding(padding: EdgeInsets.all(32), child: Center(child: Text("Velg en klasse.")));
    } else if (_selectedCategoryId == 'all') {
      content = StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("Ingen klasser funnet."));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildOppsettToolbar(),
              const SizedBox(height: 16),
              for (final doc in docs) ...[
                _buildOppsettSectionForCategory(doc.id, (doc.data() as Map)['name']),
                const SizedBox(height: 28),
              ],
            ],
          );
        }
      );
    } else {
      content = _buildOppsettSectionForCategory(_selectedCategoryId!, null);
    }

    return SingleChildScrollView(
      child: AdminPageBody(
        top: 24,
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < 900) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInlineCategoryFilter(countBy: 'teams'),
                const SizedBox(height: 16),
                content,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 260, child: _buildOppsettClassList()),
              const SizedBox(width: 20),
              Expanded(child: content),
            ],
          );
        }),
      ),
    );
  }

  /// Venstre kolonne i Oppsett: klasser med fase, lag, puljer og fremdrift.
  Widget _buildOppsettClassList() {
    final db = FirebaseFirestore.instance;
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
      builder: (ctx, catSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: db.collection('teams').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
          builder: (ctx, teamSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: db.collection('matches').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
              builder: (ctx, matchSnap) {
                final cats = catSnap.data?.docs ?? const <QueryDocumentSnapshot>[];
                if (catSnap.hasData && cats.isNotEmpty && _selectedCategoryId == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _selectedCategoryId == null) setState(() { _selectedCategoryId = 'all'; });
                  });
                }
                final teams = teamSnap.data?.docs ?? const <QueryDocumentSnapshot>[];
                final matches = matchSnap.data?.docs ?? const <QueryDocumentSnapshot>[];

                Widget classButton({required bool on, required VoidCallback onTap, required Widget child}) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: on ? AppColors.adminInfoBg : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: on ? AppColors.adminInfoBorder : Colors.transparent),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        hoverColor: AppColors.adminSurfaceElevated,
                        onTap: onTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: child,
                        ),
                      ),
                    ),
                  );
                }

                return AdminCard(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                        child: Text('KLASSER', style: AdminText.kicker()),
                      ),
                      if (!catSnap.hasData)
                        const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                      else if (cats.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text('Ingen klasser funnet.', style: AdminText.ui(size: 13, color: AppColors.adminTextSecondary)),
                        ),
                      for (final c in cats)
                        Builder(builder: (context) {
                          final cm = matches.where((m) => (m.data() as Map)['category_id'] == c.id).toList();
                          final ct = teams.where((t) => (t.data() as Map)['category_id'] == c.id).toList();
                          final groupsN = ct.map((t) => (t.data() as Map)['group']).whereType<String>().toSet().length;
                          final done = cm.where((m) => (m.data() as Map)['status'] == 'finished').length;
                          final hasPlayoffStarted = cm.any((m) {
                            final d = m.data() as Map;
                            return d['stage'] == 'playoff' && (d['status'] == 'live' || d['status'] == 'finished');
                          });
                          Widget phase;
                          if (cm.isEmpty) {
                            phase = const AdminPill.neutral('Ikke generert', height: 20);
                          } else if (done == cm.length) {
                            phase = const AdminPill.success('Ferdig', height: 20);
                          } else if (hasPlayoffStarted) {
                            phase = const AdminPill.info('Sluttspill', height: 20);
                          } else {
                            phase = const AdminPill.neutral('Gruppespill', height: 20);
                          }
                          final meta = [
                            '${ct.length} lag',
                            if (groupsN > 0) '$groupsN ${groupsN == 1 ? 'pulje' : 'puljer'}',
                            if (cm.isNotEmpty) '$done/${cm.length} ferdig',
                          ].join(' · ');
                          return classButton(
                            on: _selectedCategoryId == c.id,
                            onTap: () => setState(() => _selectedCategoryId = c.id),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Text('${(c.data() as Map)['name'] ?? 'Klasse'}',
                                        style: AdminText.ui(size: 14, weight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 6),
                                  phase,
                                ]),
                                const SizedBox(height: 4),
                                Text(meta, style: AdminText.ui(size: 12, color: AppColors.adminTextSecondary)),
                              ],
                            ),
                          );
                        }),
                      Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), color: AppColors.adminDivider),
                      classButton(
                        on: _selectedCategoryId == 'all',
                        onTap: () => setState(() => _selectedCategoryId = 'all'),
                        child: Text('Vis alle klasser samlet',
                            style: AdminText.ui(size: 14, weight: FontWeight.w600, color: AppColors.adminPrimary)),
                      ),
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

  Widget _buildOppsettSectionForCategory(String categoryId, String? categoryName) {

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('teams').where('tournament_id', isEqualTo: widget.tournamentId).where('category_id', isEqualTo: categoryId).snapshots(),

      builder: (ctx, teamSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('matches').where('tournament_id', isEqualTo: widget.tournamentId).where('category_id', isEqualTo: categoryId).snapshots(),

          builder: (ctx2, matchSnap) {
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('categories').doc(categoryId).snapshots(),
              builder: (ctx3, catDocSnap) {
            if (!teamSnap.hasData || !matchSnap.hasData) {
              return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
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

            // ── Visningstall for overskrift og steg ──
            final title = categoryName ?? ((catDocSnap.data?.data() as Map<String, dynamic>?)?['name'] as String?) ?? 'Klasse';
            final courts = allMatches
                .map((m) => (m.data() as Map)['court'] as String?)
                .whereType<String>()
                .where((c) => c.isNotEmpty && c != 'TBD')
                .map(_courtShort)
                .toSet()
                .toList()
              ..sort();
            final brackets = allMatches
                .where((m) => (m.data() as Map)['stage'] == 'playoff')
                .map((m) => (m.data() as Map)['bracket'] as String?)
                .whereType<String>()
                .toSet()
                .toList()
              ..sort();
            final meta = [
              '${teams.length} lag',
              if (sortedGroups.isNotEmpty) '${sortedGroups.length} ${sortedGroups.length == 1 ? 'pulje' : 'puljer'}',
              if (brackets.length == 1) '${brackets.first}-bracket',
              if (brackets.length > 1) '${brackets.sublist(0, brackets.length - 1).join('-, ')}- og ${brackets.last}-bracket',
              if (courts.isNotEmpty) 'baner ${courts.join(', ')}',
            ].join(' · ');

            final seeded = teams.where((t) => (t.data() as Map)['seed'] != null).length;
            final groupMatches = allMatches.where((m) => (m.data() as Map)['stage'] == 'group').toList();
            final groupDone = groupMatches.where((m) => (m.data() as Map)['status'] == 'finished').length;
            final playoffMatches = allMatches.where((m) => (m.data() as Map)['stage'] == 'playoff').toList();
            final playoffDone = playoffMatches.where((m) => (m.data() as Map)['status'] == 'finished').length;

            final steps = _buildOppsettToolbar(
              subs: {
                'Seeding': '$seeded lag seedet',
                'Gruppespill': groupMatches.isEmpty ? 'Ikke generert' : '$groupDone / ${groupMatches.length} kamper ferdig',
                'Sluttspill': playoffMatches.isEmpty
                    ? 'Ikke generert'
                    : '$playoffDone / ${playoffMatches.length}${brackets.isNotEmpty ? ' · ${brackets.join('/')}-bracket' : ''}',
              },
              done: {
                if (hasMatches && seeded == teams.length && teams.isNotEmpty) 'Seeding',
                if (groupMatches.isNotEmpty && groupDone == groupMatches.length) 'Gruppespill',
                if (playoffMatches.isNotEmpty && playoffDone == playoffMatches.length) 'Sluttspill',
              },
            );

            final single = _selectedCategoryId != 'all';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: AdminText.ui(size: 22, weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(meta, style: AdminText.ui(size: 13, color: AppColors.adminTextSecondary)),
                      ],
                    ),
                    if (single)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (hasMatches)
                            AdminButton(
                              label: 'Sync',
                              icon: Icons.sync,
                              onPressed: () async {
                                await _resolvePendingMatches();
                                _snack("Bracket synkronisert.");
                              },
                            ),
                          Tooltip(
                            message: hasMatches
                                ? 'Allerede generert – nullstill turneringen for å generere på nytt'
                                : 'Setter opp grupper, runde 2 og sluttspill automatisk',
                            child: AdminButton(
                              label: 'Generer grupper + sluttspill',
                              icon: Icons.auto_awesome,
                              primary: !hasMatches,
                              onPressed: hasMatches ? null : _generateGroupStage,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Steg-meny
                if (single) ...[
                  steps,
                  const SizedBox(height: 16),
                ],
                if (!hasMatches) ...[
                  _buildSeedingCard(sortedTeams, hasMatches),
                  const SizedBox(height: 16),
                  if (_selectedCategoryId != 'all') _buildGenerateCard(),
                ] else ...[
                  if (_selectedOppsettTab == 'Seeding')
                    _buildSeedingCard(sortedTeams, hasMatches),

                  if (_selectedOppsettTab == 'Gruppespill' && sortedGroups.isNotEmpty)
                    _buildGroupPreviewCard(groupTeams, sortedGroups, groupMatches, matchNumById),

                  if (_selectedOppsettTab == 'Sluttspill' && hasPlayoffs)
                    _buildPlayoffPreviewCard(allMatches, matchNumById),

                  if ((_selectedOppsettTab == 'Gruppespill' && sortedGroups.isEmpty) ||
                      (_selectedOppsettTab == 'Sluttspill' && !hasPlayoffs))
                    AdminCard(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text("Ingen kamper i denne visningen.", style: AdminText.ui(size: 14, color: AppColors.adminTextSecondary))),
                    ),

                  if (_selectedOppsettTab != 'Seeding' &&
                      _selectedOppsettTab != 'Gruppespill' &&
                      _selectedOppsettTab != 'Sluttspill')
                    AdminCard(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text("Ingen kamper i denne visningen.", style: AdminText.ui(size: 14, color: AppColors.adminTextSecondary))),
                    ),
                ]
              ],
            );
              },
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

    final swapData = _swapSelectionDoc != null ? (_swapSelectionDoc!.data() as Map) : null;
    final swapName = swapData != null ? swapData['team_name'] as String? ?? '' : null;
    final swapSeed = swapData != null ? (swapData['seed'] as num?)?.toInt() : null;

    final headStyle = AdminText.ui(size: 12, weight: FontWeight.w600, color: AppColors.adminTextSecondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (swapName != null) ...[
          AdminInfoBanner(
            icon: Icons.swap_vert,
            message: Text.rich(TextSpan(children: [
              const TextSpan(text: 'Velg lag å bytte med «'),
              TextSpan(text: swapName, style: AdminText.ui(size: 14, weight: FontWeight.w700)),
              TextSpan(text: '»${swapSeed != null ? ' (seed $swapSeed)' : ''}'),
            ])),
            action: AdminButton(
              label: 'Avbryt',
              height: 36,
              onPressed: () => setState(() => _swapSelectionDoc = null),
            ),
          ),
          const SizedBox(height: 12),
        ],
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminCardHeader(
                title: "Seeding-oversikt",
                leading: const Icon(Icons.format_list_numbered, color: AppColors.adminPrimary, size: 20),
                trailing: Text("$numTeams lag · $numGroups ${numGroups == 1 ? 'pulje' : 'puljer'}",
                    style: AdminText.ui(size: 13, color: AppColors.adminTextSecondary)),
              ),

              AdminHScroll(
                minWidth: 620,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              // Kolonneoverskrifter
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
                color: AppColors.adminTableHead,
                child: Row(children: [
                  SizedBox(width: 52, child: Text("Seed", style: headStyle)),
                  Expanded(child: Text("Lag", style: headStyle)),
                  SizedBox(width: 70, child: Text("Poeng", textAlign: TextAlign.right, style: headStyle)),
                  const SizedBox(width: 20),
                  SizedBox(width: 90, child: Text("Pulje", style: headStyle)),
                  const SizedBox(width: 96),
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

                return Container(
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.adminInfoBg : null,
                    border: const Border(bottom: BorderSide(color: AppColors.adminDivider)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
                  child: Row(children: [
                    // Seed badge
                    SizedBox(
                      width: 52,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.adminPrimary.withValues(alpha: 0.15) : AppColors.adminMuted,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${seed ?? '–'}',
                              style: AdminText.mono(
                                size: 13, weight: FontWeight.w600,
                                color: isSelected ? AppColors.adminPrimary : AppColors.adminText,
                              )),
                        ),
                      ),
                    ),

                    // Lagnavn + spillere
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d['team_name'] ?? 'Ukjent',
                          style: AdminText.ui(
                            size: 14, weight: FontWeight.w700,
                            color: isSelected ? AppColors.adminPrimary : AppColors.adminText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "${d['player1_name'] ?? ''} · ${d['player2_name'] ?? ''}",
                          style: AdminText.ui(size: 12, color: AppColors.adminTextSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    )),

                    // Poeng
                    SizedBox(
                      width: 70,
                      child: Text('$points', textAlign: TextAlign.right, style: AdminText.mono(size: 13)),
                    ),
                    const SizedBox(width: 20),

                    // Puljebadge
                    SizedBox(
                      width: 90,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isExpected ? Colors.transparent : AppColors.adminSurfaceElevated,
                            borderRadius: BorderRadius.circular(999),
                            border: isExpected ? Border.all(color: AppColors.adminOutline) : null,
                          ),
                          child: Text('Pulje $displayGroup',
                            style: AdminText.ui(
                              size: 12, weight: FontWeight.w600,
                              color: isExpected ? AppColors.adminTextSecondary : AppColors.adminTextBody,
                              style: isExpected ? FontStyle.italic : FontStyle.normal,
                            )),
                        ),
                      ),
                    ),

                    // Handlingsknapp
                    SizedBox(
                      width: 96,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: isSelected
                            ? TextButton(
                                onPressed: () => setState(() => _swapSelectionDoc = null),
                                child: const Text("Avbryt"),
                              )
                            : inSwapMode
                                ? AdminButton(
                                    label: 'Bytt hit',
                                    height: 36,
                                    foreground: AppColors.adminPrimary,
                                    borderColor: AppColors.adminInfoBorder,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    onPressed: () => _confirmAndSwap(_swapSelectionDoc!, teamDoc),
                                  )
                                : AdminGhostIconButton(
                                    icon: Icons.swap_vert,
                                    tooltip: 'Bytt seed',
                                    onPressed: () => setState(() => _swapSelectionDoc = teamDoc),
                                  ),
                      ),
                    ),
                  ]),
                );
              }),
                  ],
                ),
              ),

              // Bunntekst
              if (sortedTeams.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text("Ingen lag registrert enda.",
                      textAlign: TextAlign.center,
                      style: AdminText.ui(size: 14, color: AppColors.adminTextSecondary)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateCard() {
    return AdminCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const AdminIconTile(icon: Icons.emoji_events_outlined),
            const SizedBox(width: 12),
            Text("Generer turneringsoppsett",
                style: AdminText.ui(size: 16, weight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          Text(
            "Setter opp grupper, runde 2 og sluttspillkryssninger automatisk basert på seeding. "
            "Etter generering kan du publisere oppsettet for deltakere.",
            style: AdminText.ui(size: 13, color: AppColors.adminTextSecondary),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: AdminButton.primary(
              icon: Icons.auto_awesome,
              label: "Generer grupper + sluttspill",
              onPressed: _generateGroupStage,
            ),
          ),
        ],
      ),
    );
  }

  /// Steg-meny for Oppsett: Seeding → Gruppespill → Sluttspill.
  Widget _buildOppsettToolbar({Map<String, String> subs = const {}, Set<String> done = const {}}) {
    const order = ['Seeding', 'Gruppespill', 'Sluttspill'];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (int i = 0; i < order.length; i++)
          _buildOppsettSubTab(order[i], number: i + 1, subtitle: subs[order[i]], done: done.contains(order[i])),
      ],
    );
  }

  Widget _buildOppsettSubTab(String title, {int number = 1, String? subtitle, bool done = false}) {
    final isSelected = _selectedOppsettTab == title;
    final Color numBg = done ? AppColors.green : (isSelected ? AppColors.adminPrimary : AppColors.adminMuted);
    final Color numFg = (done || isSelected) ? Colors.white : AppColors.adminTextMuted;
    return InkWell(
      onTap: () => setState(() => _selectedOppsettTab = title),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.adminSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.adminPrimary : AppColors.adminOutline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: numBg, shape: BoxShape.circle),
              child: done
                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                  : Text('$number', style: AdminText.mono(size: 12, weight: FontWeight.w600, color: numFg)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AdminText.ui(size: 14, weight: FontWeight.w700)),
                if (subtitle != null)
                  Text(subtitle, style: AdminText.ui(size: 12, color: AppColors.adminTextSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupPreviewCard(
      Map<String, List<DocumentSnapshot>> groupTeams,
      List<String> sortedGroups,
      List<DocumentSnapshot> groupMatches,
      Map<String, int> matchNumById) {
    Widget groupCard(String g) {
      final gTeams = List<DocumentSnapshot>.from(groupTeams[g] ?? [])
        ..sort((a, b) {
          final as_ = (a.data() as Map)['seed'] as int? ?? 999;
          final bs  = (b.data() as Map)['seed'] as int? ?? 999;
          return as_.compareTo(bs);
        });

      final gMatches = groupMatches.where((m) => (m.data() as Map)['group'] == g).toList()
        ..sort((a, b) {
          final ta = (a.data() as Map)['match_type'] as String? ?? '';
          final tb = (b.data() as Map)['match_type'] as String? ?? '';
          return ta.compareTo(tb);
        });
      final gDone = gMatches.where((m) => (m.data() as Map)['status'] == 'finished').length;

      // Seire/tap og sett fra ferdigspilte puljekamper (kun visning)
      final wins = <String, int>{}, losses = <String, int>{}, setsW = <String, int>{}, setsL = <String, int>{};
      for (final m in gMatches) {
        final d = m.data() as Map;
        if (d['status'] != 'finished') continue;
        final a = d['team_a_id'] as String? ?? '';
        final b = d['team_b_id'] as String? ?? '';
        final hs = d['home_score'] as int? ?? 0;
        final as2 = d['away_score'] as int? ?? 0;
        setsW[a] = (setsW[a] ?? 0) + hs; setsL[a] = (setsL[a] ?? 0) + as2;
        setsW[b] = (setsW[b] ?? 0) + as2; setsL[b] = (setsL[b] ?? 0) + hs;
        if (hs > as2) {
          wins[a] = (wins[a] ?? 0) + 1; losses[b] = (losses[b] ?? 0) + 1;
        } else if (as2 > hs) {
          wins[b] = (wins[b] ?? 0) + 1; losses[a] = (losses[a] ?? 0) + 1;
        }
      }

      final head = AdminText.ui(size: 11, weight: FontWeight.w600, color: AppColors.adminTextSecondary);
      Widget gridRow(List<Widget> cells, {EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8)}) => Padding(
            padding: padding,
            child: Row(children: [
              SizedBox(width: 28, child: cells[0]),
              const SizedBox(width: 8),
              SizedBox(width: 40, child: cells[1]),
              const SizedBox(width: 8),
              Expanded(child: cells[2]),
              const SizedBox(width: 8),
              SizedBox(width: 44, child: cells[3]),
              const SizedBox(width: 8),
              SizedBox(width: 52, child: cells[4]),
            ]),
          );

      return AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.adminDivider))),
              child: Row(children: [
                Expanded(child: Text("Pulje $g", style: AdminText.ui(size: 16, weight: FontWeight.w700))),
                Text('$gDone / ${gMatches.length} ferdig', style: AdminText.ui(size: 12, color: AppColors.adminTextSecondary)),
              ]),
            ),
            gridRow([
              Text('#', style: head),
              Text('Seed', style: head),
              Text('Lag', style: head),
              Text('V–T', style: head, textAlign: TextAlign.center),
              Text('Sett', style: head, textAlign: TextAlign.right),
            ], padding: const EdgeInsets.fromLTRB(16, 10, 16, 4)),
            ...gTeams.asMap().entries.map((e) {
              final idx = e.key;
              final td = e.value.data() as Map<String, dynamic>;
              final tid = e.value.id;
              final seed = (td['seed'] as num?)?.toInt();
              final placement = (td['group_placement'] as num?)?.toInt();
              final rank = placement ?? (idx + 1);
              return gridRow([
                Text('$rank', style: AdminText.mono(size: 14, weight: FontWeight.w600)),
                Text(seed != null ? 'S$seed' : '–', style: AdminText.mono(size: 12, color: AppColors.adminTextMuted)),
                Text(td['team_name'] ?? 'Ukjent', style: AdminText.ui(size: 14, weight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                Text('${wins[tid] ?? 0}–${losses[tid] ?? 0}', style: AdminText.mono(size: 13), textAlign: TextAlign.center),
                Text('${setsW[tid] ?? 0}–${setsL[tid] ?? 0}', style: AdminText.mono(size: 13, color: AppColors.adminTextMuted), textAlign: TextAlign.right),
              ]);
            }),
            if (gMatches.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.adminDivider))),
                child: Column(
                  children: [
                    for (final m in gMatches) _groupMatchLine(m, matchNumById),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return LayoutBuilder(builder: (context, c) {
      const gap = 16.0;
      final cols = c.maxWidth >= 780 ? 2 : 1;
      final w = cols == 1 ? c.maxWidth : (c.maxWidth - gap) / 2 - 0.1;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final g in sortedGroups) SizedBox(width: w, child: groupCard(g))],
      );
    });
  }

  Widget _groupMatchLine(DocumentSnapshot m, Map<String, int> matchNumById) {
    final d = m.data() as Map<String, dynamic>;
    final mType = d['match_type'] as String? ?? '';
    final k = const {'group_match_1': 'K1', 'group_match_2': 'K2', 'group_match_3': 'K3', 'group_match_4': 'K4'}[mType]
        ?? (d['match_number'] != null ? '#${d['match_number']}' : '');
    final status = d['status'] as String? ?? 'scheduled';
    final isPending = status == 'pending';
    final a = _resolveTeamDisplayName(d, 'team_a', matchNumById);
    final b = _resolveTeamDisplayName(d, 'team_b', matchNumById);
    String score;
    if (status == 'finished') {
      score = (d['walkover'] as bool? ?? false) ? 'Walkover' : '${d['home_score'] ?? 0} – ${d['away_score'] ?? 0}';
    } else if (status == 'live') {
      score = 'LIVE';
    } else {
      score = (d['match_time'] as String?)?.isNotEmpty == true ? d['match_time'] as String : '–';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 26, child: Text(k, style: AdminText.mono(size: 11, color: AppColors.adminPrimary))),
          const SizedBox(width: 10),
          Expanded(
            child: Text('$a – $b',
                style: AdminText.ui(
                  size: 13,
                  color: isPending ? AppColors.adminTextSecondary : AppColors.adminTextBody,
                  style: isPending ? FontStyle.italic : null,
                ),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 10),
          Text(score, style: AdminText.mono(size: 13, weight: FontWeight.w600,
              color: status == 'live' ? AppColors.coralDeep : AppColors.adminText)),
          SizedBox(
            width: 40,
            child: isPending
                ? null
                : AdminGhostIconButton(
                    icon: Icons.edit_outlined,
                    size: 36,
                    iconSize: 16,
                    tooltip: 'Rediger kamp',
                    onPressed: () => _showMatchEditDialog(m),
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
        final isLive     = status == 'live';
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

        final Widget statusPill = isFinished
            ? AdminPill(label: '$homeS – $awayS', background: const Color(0x1F1F7556), foreground: AppColors.green, height: 22, mono: true)
            : isLive
                ? const AdminPill.live(height: 22)
                : isPending
                    ? const AdminPill.neutral('Venter...', height: 22)
                    : const AdminPill.neutral('Planlagt', height: 22);

        TextStyle nameStyle(bool win) => AdminText.ui(
              size: 13,
              weight: win ? FontWeight.w700 : FontWeight.w500,
              color: isPending
                  ? AppColors.adminTextSecondary
                  : win
                      ? AppColors.green
                      : AppColors.adminText,
              style: isPending ? FontStyle.italic : FontStyle.normal,
            );

        return InkWell(
          onTap: () => _showMatchEditDialog(m),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.adminSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isLive
                    ? AppColors.coral.withValues(alpha: 0.6)
                    : isFinished
                        ? AppColors.green.withValues(alpha: 0.3)
                        : AppColors.adminOutline,
                width: isLive ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kamp-nummer + tid/bane + status
                Row(children: [
                  if (num != null) ...[
                    Text('#$num', style: AdminText.mono(size: 11, weight: FontWeight.w600, color: AppColors.adminPrimary)),
                    const SizedBox(width: 8),
                  ],
                  if (time != null && !isPending) ...[
                    Text(time, style: AdminText.mono(size: 11, color: AppColors.adminTextSecondary)),
                    const SizedBox(width: 6),
                  ],
                  if (court != null && court != 'TBD' && !isPending)
                    Flexible(
                      child: Text(court, style: AdminText.ui(size: 11, color: AppColors.adminTextSecondary), overflow: TextOverflow.ellipsis),
                    ),
                  const Spacer(),
                  statusPill,
                ]),
                const SizedBox(height: 6),
                Text(teamA, style: nameStyle(homeWin), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(teamB, style: nameStyle(awayWin), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bracket-header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.adminInfoBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.adminInfoBorder),
            ),
            child: Row(children: [
              Icon(
                bracket == 'A'
                    ? Icons.emoji_events_outlined
                    : bracket == 'B'
                        ? Icons.workspace_premium_outlined
                        : Icons.military_tech_outlined,
                size: 16,
                color: AppColors.adminPrimary,
              ),
              const SizedBox(width: 8),
              Text('$bracket-Bracket',
                  style: AdminText.ui(size: 14, weight: FontWeight.w700, color: AppColors.adminPrimaryDark)),
            ]),
          ),
          // Runde-seksjoner
          ...usedRounds.map((r) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Rundetittel
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
                child: Text(
                  (roundLabels[r] ?? r).toUpperCase(),
                  style: AdminText.kicker(),
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

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminCardHeader(
            title: "Sluttspillsoversikt",
            leading: const Icon(Icons.emoji_events_outlined, color: AppColors.adminPrimary, size: 20),
            trailing: AdminButton(
              label: "Sync",
              icon: Icons.sync,
              height: 36,
              onPressed: () async {
                await _resolvePendingMatches();
                _snack("Bracket synkronisert.");
              },
            ),
          ),
          // Bracket-kolonner side om side
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(builder: (context, c) {
              if (c.maxWidth < 520 && brackets.length > 1) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final b in brackets) ...[bracketColumn(b), const SizedBox(height: 12)],
                  ],
                );
              }
              return Row(
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
              );
            }),
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