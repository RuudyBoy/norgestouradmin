part of '../tournament_control_page.dart';

// Dialoger for kamper: rediger kamp/resultat, walkover, bytt lag og dommer-QR.
extension _MatchDialogs on _TournamentControlPageState {
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
}
