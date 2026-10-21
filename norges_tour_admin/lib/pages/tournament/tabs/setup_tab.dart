part of '../tournament_control_page.dart';

// Fanen «Oppsett»: klasseliste, seeding, puljer og sluttspill.
extension _SetupTab on _TournamentControlPageState {
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
                    if (mounted && _selectedCategoryId == null) _refresh(() { _selectedCategoryId = 'all'; });
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
                          final Widget phase = switch (_classPhase(cm)) {
                            _ClassPhase.notGenerated => const AdminPill.neutral('Ikke generert', height: 20),
                            _ClassPhase.done => const AdminPill.success('Ferdig', height: 20),
                            _ClassPhase.playoffs => const AdminPill.info('Sluttspill', height: 20),
                            _ClassPhase.groups => const AdminPill.neutral('Gruppespill', height: 20),
                          };
                          final meta = [
                            '${ct.length} lag',
                            if (groupsN > 0) '$groupsN ${groupsN == 1 ? 'pulje' : 'puljer'}',
                            if (cm.isNotEmpty) '$done/${cm.length} ferdig',
                          ].join(' · ');
                          return classButton(
                            on: _selectedCategoryId == c.id,
                            onTap: () => _refresh(() => _selectedCategoryId = c.id),
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
                        onTap: () => _refresh(() => _selectedCategoryId = 'all'),
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
              onPressed: () => _refresh(() => _swapSelectionDoc = null),
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
                                onPressed: () => _refresh(() => _swapSelectionDoc = null),
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
                                    onPressed: () => _refresh(() => _swapSelectionDoc = teamDoc),
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
      onTap: () => _refresh(() => _selectedOppsettTab = title),
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
            (d['team_a_id'] as String? ?? '') == kPlaceholder ||
            (d['team_b_id'] as String? ?? '') == kPlaceholder;
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
}
