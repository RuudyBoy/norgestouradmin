part of '../tournament_control_page.dart';

// Fanen «Kampprogram»: kamper per dag og tidspunkt, med søk og filtre.
extension _ScheduleTab on _TournamentControlPageState {
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
            final todayStr = fmtNoDate(now);
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

              final stage = d['stage'];
              final hasGroup = (d['group'] as String? ?? '').isNotEmpty;
              if ((stage == 'group' && hasGroup) || stage == 'playoff') {
                rounds.add(_roundFilterLabel(d));
              }
            }
            final sortedRounds = rounds.toList()..sort();
            final sortedCourts = courts.toList()..sort((a, b) => a.compareTo(b));

            // Bruk filtrene (runde/bane/søk) – teller status før statusfilter
            if (_selectedRoundFilter != 'alle') {
              dayMatches = dayMatches
                  .where((m) => _roundFilterLabel(m.data() as Map) == _selectedRoundFilter)
                  .toList();
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
                onTap: () => _refresh(() => _selectedScheduleDate = date),
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
                    onChanged: (v) => _refresh(() => _scheduleQuery = v),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: AdminSegmented<String>(
                      selected: _selectedStatusFilter,
                      onChanged: (v) => _refresh(() => _selectedStatusFilter = v),
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
                      onChanged: (v) => _refresh(() => _selectedRoundFilter = v),
                      options: [
                        const AdminSegmentItem(value: 'alle', label: 'Alle'),
                        for (final r in sortedRounds) AdminSegmentItem(value: r, label: r),
                      ],
                    ),
                  if (sortedCourts.isNotEmpty)
                    AdminSelect<String>(
                      label: 'Bane',
                      value: _selectedCourtFilter,
                      onChanged: (v) => _refresh(() => _selectedCourtFilter = v),
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
    final aPlaceholder = (d['team_a_id'] as String? ?? '') == kPlaceholder;
    final bPlaceholder = (d['team_b_id'] as String? ?? '') == kPlaceholder;
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
}
