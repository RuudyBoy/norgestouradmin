import 'dart:io';
void main() {
  final file = File('lib/tournament_control_page.dart');
  var lines = file.readAsLinesSync();

  int findLine(String pattern, [int start = 0]) {
    for (int i = start; i < lines.length; i++) {
      if (lines[i].contains(pattern)) return i;
    }
    return -1;
  }

  // 1. Add import
  int iImport = findLine("import 'edit_tournament_page.dart';");
  if (iImport != -1) lines[iImport] = "import 'edit_tournament_page.dart';\nimport 'schedule_logic.dart';";

  // 2. autoScheduleForCategory
  int iAutoStart = findLine("Future<void> _autoScheduleForCategory(");
  int iAutoEnd = findLine("  }", iAutoStart);
  if (iAutoStart != -1 && iAutoEnd != -1) {
    lines.replaceRange(iAutoStart, iAutoEnd + 1, ["""  Future<void> _autoScheduleForCategory(
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
      );"""]);
  }

  // 3. Wrap to Column
  int iWrap = findLine("child: Wrap(");
  if (iWrap != -1 && lines[iWrap + 1].contains("spacing: 8, runSpacing: 8,")) {
    lines[iWrap] = "              child: Column(";
    lines[iWrap + 1] = "";
  }

  // 4. publish batch
  int iPubStart = findLine("Future<void> _publishCategory() async {");
  int iPubEnd = findLine("void _deleteCategory() {", iPubStart);
  if (iPubStart != -1 && iPubEnd != -1) {
    lines.replaceRange(iPubStart, iPubEnd, ["""  Future<void> _publishCategory() async {
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
  """]);
  }

  // 5. inline publish button
  int iBtnStart = findLine("Widget _buildPublishButtonInline() {");
  int iBtnEnd = findLine("Widget _buildCategoryMenu() {", iBtnStart);
  if (iBtnStart != -1 && iBtnEnd != -1) {
    lines.replaceRange(iBtnStart, iBtnEnd, ["""  Widget _buildPublishButtonInline() {
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
  """]);
  }

  // 6. _buildScheduleCard
  int iCardStart = findLine("Widget _buildScheduleCard(");
  int iCardEnd = findLine("  // ─── UI shell ─────────────────────────────────────────────────────────────", iCardStart);
  if (iCardStart != -1 && iCardEnd != -1) {
    lines.replaceRange(iCardStart, iCardEnd, ["""  Widget _buildScheduleCard(DocumentSnapshot matchDoc, Map<String, int> matchNumById, Map<String, String> catIdToName) {
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

    String stageLabel = catName.isNotEmpty ? '\$catName - ' : '';
    if (stage == 'group') {
      final mType = d['match_type'] as String? ?? '';
      final matchLabel = {'group_match_1':' - K1','group_match_2':' - K2','group_match_3':' - K3','group_match_4':' - K4'}[mType] ?? '';
      stageLabel += 'Pulje \$group\$matchLabel';
    }
    if (stage == 'playoff') {
      final bl = bracket?.toUpperCase() ?? '';
      final rl = const {'r16':'R16','qf':'KF','sf':'SF','final':'Finale'}[round] ?? '';
      stageLabel += '\$bl-Bracket \$rl';
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
    else if (delayMinutes != null && delayMinutes > 0) { statusColor = AppColors.adminPrimaryHover; statusLabel = '+\${delayMinutes}min'; }

    Widget teamLine(String name, bool wins, int? score) => Row(children: [
      Expanded(child: Text(name, style: TextStyle(fontSize: 14, fontWeight: wins ? FontWeight.bold : FontWeight.w600, color: wins ? AppColors.adminText : AppColors.adminTextSecondary), overflow: TextOverflow.ellipsis)),
      if (score != null) Text('\$score', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: wins ? AppColors.green : AppColors.adminTextSecondary)),
    ]);

    Widget infoChip(String text, {Color? color, bool filled = true}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: filled ? AppColors.adminSurfaceElevated : Colors.transparent, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 11, color: color ?? AppColors.adminTextSecondary, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
    );

    final accent = isLive ? AppColors.coral : isFinished ? AppColors.green : AppColors.adminSurfaceElevated;
    final qrUrl = "https://spikedunk.web.app/?matchId=\${matchDoc.id}";

    final Widget qrBox = isPending
        ? SizedBox(width: 108, child: Center(child: Text('QR når lagene\\ner klare', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.adminTextSecondary))))
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
                      if (matchNum != null) ...[Text('#\$matchNum', style: const TextStyle(fontSize: 12, color: AppColors.adminPrimary, fontWeight: FontWeight.bold)), const SizedBox(width: 6)],
                      Flexible(child: infoChip(statusLabel, color: statusColor)),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, size: 12, color: AppColors.adminTextSecondary),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.access_time, size: 12, color: AppColors.adminTextSecondary),
                      const SizedBox(width: 4),
                      Flexible(child: Text(matchTime.isEmpty ? '--:--' : (matchDate.isEmpty ? matchTime : '\$matchTime – \$matchDate'), style: const TextStyle(fontSize: 11, color: AppColors.adminTextSecondary), overflow: TextOverflow.ellipsis)),
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
"""]);
  }

  file.writeAsStringSync(lines.join('\n'));
}
