import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:norges_tour_admin/logic/schedule_logic.dart';
import 'package:norges_tour_admin/pages/registrations_page.dart';
import 'package:norges_tour_admin/pages/tournament_form/edit_tournament_page.dart';
import 'package:norges_tour_admin/theme/admin_ui.dart';
import 'package:norges_tour_admin/theme/app_colors.dart';
import 'package:norges_tour_admin/theme/responsive_layout.dart';
import 'package:norges_tour_admin/utils/format.dart';
import 'package:norges_tour_admin/widgets/admin_shell.dart';

// Turneringssiden er delt i flere filer. Denne filen har selve siden:
// tilstand, header, navigasjon og felles hjelpere. Hver fane og dialog ligger
// i sin egen fil som en `extension` på _TournamentControlPageState.
part 'tournament_generation.dart';
part 'tournament_resolver.dart';
part 'dialogs/match_dialogs.dart';
part 'dialogs/team_dialogs.dart';
part 'tabs/overview_tab.dart';
part 'tabs/schedule_tab.dart';
part 'tabs/setup_tab.dart';
part 'tabs/teams_tab.dart';

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

  // Valgt steg i Oppsett-fanen: Seeding | Gruppespill | Sluttspill
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

  /// `setState` for koden i fane- og dialogfilene. Extensions kan ikke kalle
  /// `setState` direkte fordi den er `@protected`.
  void _refresh(VoidCallback fn) => setState(fn);

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
    if (status == 'scheduled') {
      final scheduledDt = parseNoDateTime(matchDate, matchTime);
      if (scheduledDt != null) {
        final diff = DateTime.now().difference(scheduledDt).inMinutes;
        if (diff > 0) return '+${diff}min';
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

  String _courtShort(String? court) {
    final c = (court ?? '').trim();
    if (c.isEmpty || c == 'TBD') return '–';
    return c.toLowerCase().startsWith('bane ') ? c.substring(5) : c;
  }

  void _openRegistrations() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => RegistrationsPage(
        tournamentId: widget.tournamentId,
        tournamentName: widget.tournamentName,
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

  /// Datoperiode i headeren. Ugyldige datoer vises som de er lagret.
  String _headerDateRange(String? s, String? e) =>
      formatDateRange(s, e) ??
      [s, e].whereType<String>().where((x) => x.isNotEmpty).join(' – ');

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
            onPressed: () => _setPublished(!isPublished),
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

  // ─── Publisering ───────────────────────────────────────────────────────────

  /// Publiserer eller skjuler alle klassene i turneringen (spillerappen viser
  /// bare klasser med `published == true`).
  Future<void> _setPublished(bool published) async {
    final snap = await FirebaseFirestore.instance.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'published': published});
    }
    await batch.commit();
    _snack(published ? 'Hele turneringen er nå publisert offentlig' : 'Hele turneringen er nå skjult');
  }
}

/// Hvor langt en klasse har kommet, ut fra kampene i klassen.
_ClassPhase _classPhase(List<DocumentSnapshot> matches) {
  if (matches.isEmpty) return _ClassPhase.notGenerated;
  if (matches.every((m) => (m.data() as Map)['status'] == 'finished')) return _ClassPhase.done;
  final playoffStarted = matches.any((m) {
    final d = m.data() as Map;
    return d['stage'] == 'playoff' && (d['status'] == 'live' || d['status'] == 'finished');
  });
  return playoffStarted ? _ClassPhase.playoffs : _ClassPhase.groups;
}

/// De seks lagfeltene i en kamp (`<prefix>_name`, `_id`, `_p1_name`, `_p1_id`,
/// `_p2_name`, `_p2_id`) fylt fra et lagdokument i `teams`.
Map<String, dynamic> _slotFromTeam(String prefix, Object teamId, Map team, {String emptyName = ''}) => {
  '${prefix}_name': team['team_name'] ?? emptyName,
  '${prefix}_id': teamId,
  '${prefix}_p1_name': team['player1_name'] ?? '',
  '${prefix}_p1_id': team['player1_id'] ?? '',
  '${prefix}_p2_name': team['player2_name'] ?? '',
  '${prefix}_p2_id': team['player2_id'] ?? '',
};

/// De seks lagfeltene kopiert fra én side (`srcPrefix`) av en annen kamp.
Map<String, dynamic> _slotFromMatch(String prefix, Map src, String srcPrefix) => {
  for (final f in const ['name', 'id', 'p1_name', 'p1_id', 'p2_name', 'p2_id'])
    '${prefix}_$f': src['${srcPrefix}_$f'] ?? '',
};

/// Rundenavn i Runde-filteret i kampprogrammet («Pulje A», «1/16», «Kvart» …).
String _roundFilterLabel(Map d) {
  final stage = d['stage'] as String? ?? '';
  if (stage == 'group') return 'Pulje ${d['group'] as String? ?? ''}';
  if (stage == 'playoff') {
    const labels = {'r16': '1/16', 'r8': '1/8', 'qf': 'Kvart', 'sf': 'Semi', 'final': 'Finale'};
    return labels[d['round'] as String? ?? ''] ?? 'Playoff';
  }
  return '';
}

/// Fase for én klasse, brukt i oversikten og klasselisten i Oppsett.
enum _ClassPhase { notGenerated, groups, playoffs, done }
