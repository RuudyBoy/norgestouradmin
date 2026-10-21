part of '../tournament_control_page.dart';

// Dialoger for lag: nytt lag, testlag, rediger, slett og bytte av seed.
extension _TeamDialogs on _TournamentControlPageState {
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

      // Lag A ↔ lag B der de står i kampen
      for (final prefix in const ['team_a', 'team_b']) {
        final id = prefix == 'team_a' ? aId : bId;
        if (id == teamA.id) upd.addAll(_slotFromTeam(prefix, teamB.id, dataB));
        if (id == teamB.id) upd.addAll(_slotFromTeam(prefix, teamA.id, dataA));
      }

      if (upd.isNotEmpty) batch.update(m.reference, upd);
    }

    await batch.commit();
    if (mounted) _refresh(() => _swapSelectionDoc = null);
    _snack("Byttet: ${dataA['team_name']} (S${seedA ?? '?'}) ↔ ${dataB['team_name']} (S${seedB ?? '?'})");
  }
}
