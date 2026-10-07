import re

with open('lib/tournament_control_page.dart', 'r', encoding='utf-8') as f:
    lines = f.read().split('\n')

# 1. Add import
for i, l in enumerate(lines):
    if "import 'edit_tournament_page.dart';" in l:
        lines[i] = "import 'edit_tournament_page.dart';\nimport 'schedule_logic.dart';"
        break

# 2. _autoScheduleForCategory
for i, l in enumerate(lines):
    if "Future<void> _autoScheduleForCategory(" in l:
        start = i
        for j in range(i, len(lines)):
            if lines[j] == "  }":
                end = j
                break
        
        new_sched = """  Future<void> _autoScheduleForCategory(
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
      );"""
        lines = lines[:start] + new_sched.split('\n') + lines[end+1:]
        break

# 3. _publishCategory & _unpublishCategory
for i, l in enumerate(lines):
    if "Future<void> _publishCategory()" in l:
        start = i
        for j in range(i, len(lines)):
            if "Future<void> _unpublishCategory()" in lines[j]:
                pass
            if lines[j] == "  }" and j+1 < len(lines) and "void _deleteCategory" in lines[j+1]:
                end = j
                new_pub = """  Future<void> _publishCategory() async {
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
  }"""
                lines = lines[:start] + new_pub.split('\n') + lines[end+1:]
                break
        break

# 4. _buildPublishButtonInline
for i, l in enumerate(lines):
    if "Widget _buildPublishButtonInline()" in l:
        start = i
        for j in range(i, len(lines)):
            if lines[j] == "  }" and j+1 < len(lines) and "Widget _buildCategoryMenu" in lines[j+1]:
                end = j
                new_btn = """  Widget _buildPublishButtonInline() {
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
  }"""
                lines = lines[:start] + new_btn.split('\n') + lines[end+1:]
                break
        break

# 5. Remove _buildInlineCategoryFilter from top bar
for i, l in enumerate(lines):
    if "if (!ResponsiveLayout.isMobile(context)) _buildInlineCategoryFilter()" in l:
        lines[i] = ""
        break

# 6. Rewrite _buildOppsettSection
for i, l in enumerate(lines):
    if "Widget _buildOppsettSection()" in l:
        start = i
        for j in range(i, len(lines)):
            if lines[j] == "  }" and j+1 < len(lines) and "Widget _buildOppsettSubTab" in lines[j+1]:
                end = j
                new_opp = """  Widget _buildOppsettSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: _buildInlineCategoryFilter(),
        ),
        if (_selectedCategoryId == null)
          const Expanded(child: Center(child: Text("Velg en klasse.")))
        else if (_selectedCategoryId == 'all')
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                return ListView(
                  padding: const EdgeInsets.only(bottom: 40),
                  children: snap.data!.docs.map((doc) => _buildCategoryOppsett(doc.id, (doc.data() as Map)['name'])).toList(),
                );
              }
            )
          )
        else
          Expanded(child: _buildCategoryOppsett(_selectedCategoryId!, null))
      ],
    );
  }

  Widget _buildCategoryOppsett(String catId, String? catName) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('teams').where('tournament_id', isEqualTo: widget.tournamentId).where('category_id', isEqualTo: catId).snapshots(),
      builder: (ctx, teamSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('matches').where('tournament_id', isEqualTo: widget.tournamentId).where('category_id', isEqualTo: catId).snapshots(),
          builder: (ctx2, matchSnap) {
            if (!teamSnap.hasData || !matchSnap.hasData) return const SizedBox.shrink();
            final teams = teamSnap.data!.docs;
            final allMatches = matchSnap.data!.docs;
            final hasMatches = allMatches.isNotEmpty;
            final seedingMatches = allMatches.where((m) => (m.data() as Map)['stage'] == 'seeding').toList();
            final groupMatches   = allMatches.where((m) => (m.data() as Map)['stage'] == 'group').toList();
            final playoffMatches = allMatches.where((m) => (m.data() as Map)['stage'] == 'playoff').toList();
            final Map<String, int> matchNumById = {};
            final Map<String, String> catIdToName = { catId: catName ?? '' };
            for (var m in allMatches) { matchNumById[m.id] = (m.data() as Map)['match_number'] as int? ?? 0; }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (catName != null) Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(catName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.adminPrimary)),
                ),
                if (!hasMatches) ...[
                  if (teams.isEmpty)
                    const Padding(padding: EdgeInsets.all(24), child: Text("Ingen lag påmeldt i denne klassen."))
                  else
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.settings),
                        label: const Text("Gå til Oppsett (Trekning)"),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminPrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                        onPressed: () => _openSeedingSettings(catId, teams.length),
                      ),
                    ),
                ] else ...[
                  Row(
                    children: [
                      _buildOppsettSubTab(0, "Seeding", seedingMatches.isNotEmpty),
                      _buildOppsettSubTab(1, "Gruppespill", groupMatches.isNotEmpty),
                      _buildOppsettSubTab(2, "Sluttspill", playoffMatches.isNotEmpty),
                      const Spacer(),
                      if (_oppsettTabIndex == 1 && groupMatches.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () => _generatePlayoffFromGroups(catId, teams.length),
                          icon: const Icon(Icons.emoji_events, size: 16),
                          label: const Text("Trekk Sluttspill"),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral, foregroundColor: Colors.white),
                        ),
                      if (_oppsettTabIndex == 2 && playoffMatches.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () => _showAddWalkoverMatchDialog(catId),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text("Ny kamp"),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminPrimary, foregroundColor: Colors.white),
                        )
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_oppsettTabIndex == 0) _buildSeedingView(teams, seedingMatches, catId, catIdToName, matchNumById),
                  if (_oppsettTabIndex == 1) _buildGroupView(teams, groupMatches, catId, catIdToName, matchNumById),
                  if (_oppsettTabIndex == 2) _buildPlayoffView(teams, playoffMatches, catId, catIdToName, matchNumById),
                ]
              ],
            );
          }
        );
      }
    );
  }"""
                lines = lines[:start] + new_opp.split('\n') + lines[end+1:]
                break
        break

# 7. Rewrite _buildTeamsTab
for i, l in enumerate(lines):
    if "Widget _buildTeamsTab()" in l:
        for j in range(i, len(lines)):
            if "if (_selectedCategoryId == null) {" in lines[j]:
                lines[j] = "    if (_selectedCategoryId == null) {"
                lines[j+1] = "      return const Center(child: Text(\"Velg en klasse.\"));"
                lines[j+2] = "    }"
                break
        break

# 8. Wrap to Column in _buildDaySection
for i, l in enumerate(lines):
    if "child: Wrap(" in l and i+1 < len(lines) and "spacing: 8, runSpacing: 8," in lines[i+1]:
        lines[i] = "              child: Column("
        lines[i+1] = ""
        break

# 9. Rewrite _buildScheduleCard
for i, l in enumerate(lines):
    if "Widget _buildScheduleCard(" in l:
        start = i
        for j in range(i, len(lines)):
            if lines[j] == "  }" and j+1 < len(lines) and "UI shell" in lines[j+1]:
                end = j
                new_card = """  Widget _buildScheduleCard(DocumentSnapshot matchDoc, Map<String, int> matchNumById, Map<String, String> catIdToName) {
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
          color: AppColors.adminSurfaceElevated.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isLive ? AppColors.coral.withValues(alpha: 0.6) : isFinished ? AppColors.green.withValues(alpha: 0.25) : AppColors.adminSurfaceElevated, width: isLive ? 1.5 : 1),
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
  }"""
                lines = lines[:start] + new_card.split('\n') + lines[end+1:]
                break
        break

with open('lib/tournament_control_page.dart', 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))
print("done")
