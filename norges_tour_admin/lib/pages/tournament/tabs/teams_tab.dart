part of '../tournament_control_page.dart';

// Fanen «Lag»: lagliste per klasse med søk, filter og sortering.
extension _TeamsTab on _TournamentControlPageState {
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
                        onChanged: (v) => _refresh(() => _teamQuery = v),
                      ),
                      if (groups.isNotEmpty)
                        AdminSelect<String>(
                          label: 'Pulje',
                          value: groups.contains(_teamGroupFilter) ? _teamGroupFilter : 'alle',
                          onChanged: (v) => _refresh(() => _teamGroupFilter = v),
                          options: [
                            const AdminSegmentItem(value: 'alle', label: 'Alle'),
                            for (final g in groups) AdminSegmentItem(value: g, label: 'Pulje $g'),
                          ],
                        ),
                      AdminSelect<String>(
                        label: 'Sorter',
                        value: _teamSort,
                        onChanged: (v) => _refresh(() => _teamSort = v),
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
}
