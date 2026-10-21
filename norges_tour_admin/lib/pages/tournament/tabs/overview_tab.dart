part of '../tournament_control_page.dart';

// Fanen «Oversikt»: nøkkeltall, LIVE nå, neste kamper og fremdrift per klasse.
extension _OverviewTab on _TournamentControlPageState {
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
                            _attentionRow(AdminPill.delayed(e.value), '${e.key} ligger etter skjema', onTap: () => _refresh(() => _selectedNavIndex = 1)),
                          if (pendingRegs > 0)
                            _attentionRow(AdminPill.info('$pendingRegs'),
                                pendingRegs == 1 ? 'Påmelding venter godkjenning' : 'Påmeldinger venter godkjenning',
                                onTap: _openRegistrations),
                          for (final c in notGenerated.take(3))
                            _attentionRow(const AdminPill.neutral('Venter...'),
                                'Oppsett ikke generert for ${(c.data() as Map)['name'] ?? 'klasse'}',
                                onTap: () => _refresh(() { _selectedCategoryId = c.id; _selectedNavIndex = 2; })),
                        ];

                        // Fremdrift per klasse
                        final classRows = <Widget>[];
                        for (final c in categories) {
                          if (_selectedCategoryId != null && _selectedCategoryId != 'all' && c.id != _selectedCategoryId) continue;
                          final cm = allMatches.where((m) => (m.data() as Map)['category_id'] == c.id).toList();
                          final ct = allTeams.where((t) => (t.data() as Map)['category_id'] == c.id).length;
                          final done = cm.where((m) => (m.data() as Map)['status'] == 'finished').length;
                          final phase = switch (_classPhase(cm)) {
                            _ClassPhase.notGenerated => 'Oppsett ikke generert',
                            _ClassPhase.done => 'Ferdig',
                            _ClassPhase.playoffs => 'Sluttspill pågår',
                            _ClassPhase.groups => 'Gruppespill',
                          };
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
                                  onTap: () => _refresh(() => _selectedNavIndex = 1),
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
                    Text(liveScoreLine(d, true, separator: ' · '), style: AdminText.mono(size: 14, weight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    Expanded(child: Text('${d['team_b_name'] ?? 'TBD'}', style: teamStyle, overflow: TextOverflow.ellipsis)),
                    Text(liveScoreLine(d, false, separator: ' · '), style: AdminText.mono(size: 14, weight: FontWeight.w600)),
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
}
