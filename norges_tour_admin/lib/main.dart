import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // brukes i AdminDashboard
import 'firebase_options.dart';
import 'add_tournament_page.dart';
import 'tournament_control_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_login_page.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'admin_dashboard_overview.dart'; // Importerer oversiktsmodulen
import 'admin_shell.dart';
import 'theme/responsive_layout.dart';
import 'theme/admin_ui.dart';
import 'theme/app_text_styles.dart';
import 'utils/format.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spike Dunk Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.admin,
      builder: (context, child) {
        return Container(color: AppColors.adminBg, child: child);
      },
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('admins')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, adminSnapshot) {
              if (adminSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (adminSnapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text("Feil ved sjekk av admin-rettigheter: ${adminSnapshot.error}", textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => FirebaseAuth.instance.signOut(),
                          child: const Text("Logg ut"),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (adminSnapshot.hasData && adminSnapshot.data!.exists) {
                return const AdminShell();
              }
              
              // Signed in but not an admin — show error and allow sign out
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.block, color: Colors.orange, size: 48),
                      const SizedBox(height: 16),
                      const Text("Ingen admin-tilgang for denne brukeren."),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        child: const Text("Logg ut og prøv en annen bruker"),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }
        return const AdminLoginPage();
      },
    );
  }
}

class AdminDashboard extends StatefulWidget {
  /// Optional test tournaments for headless widget testing without Firebase dependencies.
  final List<Map<String, dynamic>>? testTournaments;

  /// Optional flag indicating test mode to bypass live Firestore streams.
  final bool testMode;

  const AdminDashboard({
    super.key,
    this.testTournaments,
    this.testMode = false,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // Visningsfiltre (kun klientside – endrer ingen data)
  String _query = '';
  String _phaseFilter = 'alle'; // alle | live | upcoming | done
  String _typeFilter = 'alle';
  String _sort = 'start_desc'; // start_desc | start_asc | name | created
  String _view = 'list'; // list | grid

  bool get _isTest => widget.testTournaments != null || widget.testMode;

  void _openNewTournament() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddTournamentPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktopOrLarger(context);
    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text("Kontrollpanel"),
              automaticallyImplyLeading: true,
            ),

      // --- SIDEMENY (DRAWER) ---
      drawer: isDesktop ? null : const AdminDrawer(),

      // --- LISTE / TABELL OVER TURNERINGER ---
      body: _isTest
          ? _buildDashboardBody(context, widget.testTournaments ?? const [], const {})
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tournaments')
                  .orderBy('created_at', descending: true) // Nyeste øverst
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? const [];
                final items = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return {
                    'id': doc.id,
                    ...data,
                  };
                }).toList();

                // Ventende påmeldinger per turnering (kun lesing)
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('registrations')
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, regSnap) {
                    final pending = <String, int>{};
                    for (final d in regSnap.data?.docs ?? const <QueryDocumentSnapshot>[]) {
                      final tid = (d.data() as Map<String, dynamic>)['tournament_id'] as String? ?? '';
                      pending[tid] = (pending[tid] ?? 0) + 1;
                    }
                    return _buildDashboardBody(context, items, pending);
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return AdminEmptyState(
      icon: Icons.inbox,
      text: "Ingen turneringer enda. Trykk på knappen for å lage en!",
      action: AdminButton.primary(
        label: "Ny turnering",
        icon: Icons.add,
        onPressed: _openNewTournament,
      ),
    );
  }

  // ── Filtrering / sortering (visning) ───────────────────────────────────────

  static String _typeLabel(Map<String, dynamic> d) {
    final l = (d['tournament_type_label'] as String?)?.trim() ?? '';
    return l.isEmpty ? 'Turnering' : l;
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> items) {
    final q = _query.trim().toLowerCase();
    final list = items.where((d) {
      if (_phaseFilter != 'alle' && _tournamentPhase(d) != _phaseFilter) return false;
      if (_typeFilter != 'alle' && _typeLabel(d) != _typeFilter) return false;
      if (q.isNotEmpty) {
        final hay = '${d['name'] ?? ''} ${d['location'] ?? ''}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    int byStart(Map<String, dynamic> a, Map<String, dynamic> b) {
      final da = parseNoDate(a['start_date'] as String?);
      final db = parseNoDate(b['start_date'] as String?);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    }

    switch (_sort) {
      case 'start_desc':
        list.sort((a, b) => byStart(b, a));
        break;
      case 'start_asc':
        list.sort(byStart);
        break;
      case 'name':
        list.sort((a, b) => '${a['name'] ?? ''}'.toLowerCase().compareTo('${b['name'] ?? ''}'.toLowerCase()));
        break;
      default:
        break; // 'created' – rekkefølgen fra Firestore (nyeste først)
    }
    return list;
  }

  Widget _buildDashboardBody(
    BuildContext context,
    List<Map<String, dynamic>> items,
    Map<String, int> pendingRegs,
  ) {
    final isDesktop = Responsive.isDesktopOrLarger(context);
    final header = AdminPageHeader(
      kicker: 'Kontrollpanel',
      title: 'Turneringer',
      action: AdminButton.primary(
        label: 'Ny turnering',
        icon: Icons.add,
        height: 52,
        fontSize: 15,
        onPressed: _openNewTournament,
      ),
    );

    if (items.isEmpty) {
      return SingleChildScrollView(
        child: AdminPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isDesktop) header,
              const SizedBox(height: 48),
              _buildEmptyState(),
            ],
          ),
        ),
      );
    }

    final filtered = _applyFilters(items);
    final types = items.map(_typeLabel).toSet().toList()..sort();
    final counts = <String, int>{'live': 0, 'upcoming': 0, 'done': 0};
    for (final d in items) {
      final p = _tournamentPhase(d);
      counts[p] = (counts[p] ?? 0) + 1;
    }

    return SingleChildScrollView(
      child: AdminPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 24),
            // Dashboard-oversikt («Krever handling»)
            AdminDashboardOverview(
              testTournaments: widget.testTournaments,
              testMode: widget.testMode,
              tournaments: _isTest ? null : items,
            ),
            const SizedBox(height: 24),
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildToolbar(context, items.length, counts, types),
                  const Divider(height: 1),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(48),
                      child: Text('Ingen turneringer matcher filteret.',
                          textAlign: TextAlign.center,
                          style: AdminText.ui(size: 14, color: AppColors.adminTextSecondary)),
                    )
                  else if (_view == 'list')
                    _TournamentTable(items: filtered, pendingRegs: pendingRegs, testMode: _isTest)
                  else
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _TournamentGrouped(items: filtered, pendingRegs: pendingRegs, testMode: _isTest),
                    ),
                  Container(
                    color: AppColors.adminTableHead,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Viser ${filtered.length} av ${items.length} turneringer',
                              style: AdminText.ui(size: 13, color: AppColors.adminTextSecondary)),
                        ),
                        if (Responsive.isTabletOrLarger(context))
                          Text('Klikk på en rad for å åpne turneringen',
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
  }

  Widget _buildToolbar(BuildContext context, int total, Map<String, int> counts, List<String> types) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AdminSearchField(
            hint: 'Søk etter turnering eller sted',
            onChanged: (v) => setState(() => _query = v),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: AdminSegmented<String>(
              selected: _phaseFilter,
              onChanged: (v) => setState(() => _phaseFilter = v),
              items: [
                AdminSegmentItem(value: 'alle', label: 'Alle', count: '$total'),
                AdminSegmentItem(value: 'live', label: 'Pågår', count: '${counts['live']}'),
                AdminSegmentItem(value: 'upcoming', label: 'Kommende', count: '${counts['upcoming']}'),
                AdminSegmentItem(value: 'done', label: 'Ferdige', count: '${counts['done']}'),
              ],
            ),
          ),
          AdminSelect<String>(
            label: 'Type',
            value: types.contains(_typeFilter) ? _typeFilter : 'alle',
            onChanged: (v) => setState(() => _typeFilter = v),
            options: [
              const AdminSegmentItem(value: 'alle', label: 'Alle typer'),
              for (final t in types) AdminSegmentItem(value: t, label: t),
            ],
          ),
          AdminSelect<String>(
            label: 'Sorter',
            value: _sort,
            onChanged: (v) => setState(() => _sort = v),
            options: const [
              AdminSegmentItem(value: 'start_desc', label: 'Startdato, nyeste'),
              AdminSegmentItem(value: 'start_asc', label: 'Startdato, eldste'),
              AdminSegmentItem(value: 'name', label: 'Navn A–Å'),
              AdminSegmentItem(value: 'created', label: 'Sist opprettet'),
            ],
          ),
          AdminSegmented<String>(
            selected: _view,
            onChanged: (v) => setState(() => _view = v),
            items: const [
              AdminSegmentItem(value: 'list', icon: Icons.format_list_bulleted, tooltip: 'Listevisning'),
              AdminSegmentItem(value: 'grid', icon: Icons.grid_view, tooltip: 'Gruppert visning'),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Visningshjelpere (rene funksjoner – ingen databaseendringer)
// ════════════════════════════════════════════════════════════════════════════

/// 'live' (innenfor datoene), 'upcoming' eller 'done' – ut fra start/slutt-dato.
String _tournamentPhase(Map<String, dynamic> d) {
  final start = parseNoDate(d['start_date'] as String?);
  final end = parseNoDate(d['end_date'] as String?) ?? start;
  if (start == null || end == null) return 'upcoming';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (today.isBefore(start)) return 'upcoming';
  if (today.isAfter(end)) return 'done';
  return 'live';
}

/// «22.–24.08.2026» / «30.08.–01.09.2026» / original tekst som reserve.
String _formatDateRange(String? startS, String? endS, {bool withYear = true}) =>
    formatDateRange(startS, endS, withYear: withYear) ?? '${startS ?? '?'} - ${endS ?? '?'}';

String _courtLabel(String? court) {
  final c = (court ?? '').trim();
  if (c.isEmpty || c == 'TBD') return 'BANE –';
  if (c.toLowerCase().startsWith('bane')) return c.toUpperCase();
  return 'BANE $c';
}

/// Samlet, lest status for én turnering (lag, klasser, kamper).
class _TourStats {
  final int teams;
  final int? maxTeams;
  final bool published;
  final bool hasCategories;
  final int totalMatches;
  final int finishedMatches;
  final List<Map<String, dynamic>> liveMatches;
  final int delayed;
  final String? delayedInfo;
  final String? nextTime;

  const _TourStats({
    this.teams = 0,
    this.maxTeams,
    this.published = false,
    this.hasCategories = false,
    this.totalMatches = 0,
    this.finishedMatches = 0,
    this.liveMatches = const [],
    this.delayed = 0,
    this.delayedInfo,
    this.nextTime,
  });
}

/// Leser lag, klasser og kamper for én turnering og gir et [_TourStats].
class _TourStatsBuilder extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final bool testMode;
  final Widget Function(BuildContext context, _TourStats stats) builder;

  const _TourStatsBuilder({
    required this.id,
    required this.data,
    required this.testMode,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    if (testMode || id.isEmpty) {
      return builder(context, _TourStats(teams: data['team_count'] as int? ?? 0));
    }
    final db = FirebaseFirestore.instance;
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('teams').where('tournament_id', isEqualTo: id).snapshots(),
      builder: (context, teamSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: db.collection('categories').where('tournament_id', isEqualTo: id).snapshots(),
          builder: (context, catSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: db.collection('matches').where('tournament_id', isEqualTo: id).snapshots(),
              builder: (context, matchSnap) {
                final cats = catSnap.data?.docs ?? const [];
                int? maxTeams;
                for (final c in cats) {
                  final m = ((c.data() as Map<String, dynamic>)['max_teams'] as num?)?.toInt();
                  if (m != null) maxTeams = (maxTeams ?? 0) + m;
                }
                final published = cats.isNotEmpty &&
                    (cats.first.data() as Map<String, dynamic>)['published'] == true;

                final matches = (matchSnap.data?.docs ?? const [])
                    .map((m) => m.data() as Map<String, dynamic>)
                    .toList();
                final live = matches.where((m) => m['status'] == 'live').toList()
                  ..sort((a, b) => '${a['court'] ?? ''}'.compareTo('${b['court'] ?? ''}'));
                final finished = matches.where((m) => m['status'] == 'finished').length;

                // Forsinket: planlagt kamp der starttidspunktet er passert
                final now = DateTime.now();
                var delayed = 0;
                String? delayedInfo;
                String? nextTime;
                final todayStr = fmtNoDate(now);
                for (final m in matches) {
                  if (m['status'] != 'scheduled') continue;
                  final date = m['match_date'] as String? ?? '';
                  final time = m['match_time'] as String? ?? '';
                  final dt = parseNoDateTime(date, time);
                  if (dt != null) {
                    final diff = now.difference(dt).inMinutes;
                    if (diff > 0) {
                      delayed++;
                      delayedInfo ??= '${m['court'] ?? ''} · +${diff}min';
                    }
                  }
                  if (date == todayStr && time.isNotEmpty) {
                    if (nextTime == null || time.compareTo(nextTime) < 0) nextTime = time;
                  }
                }

                return builder(
                  context,
                  _TourStats(
                    teams: teamSnap.data?.docs.length ?? 0,
                    maxTeams: maxTeams,
                    published: published,
                    hasCategories: cats.isNotEmpty,
                    totalMatches: matches.length,
                    finishedMatches: finished,
                    liveMatches: live,
                    delayed: delayed,
                    delayedInfo: delayedInfo,
                    nextTime: nextTime,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

void _openTournament(BuildContext context, String id, String name, {int? initialTab}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => TournamentControlPage(
        tournamentId: id,
        tournamentName: name,
        initialNavIndex: initialTab,
      ),
    ),
  );
}

Future<void> _confirmDeleteTournament(BuildContext context, String id, String name) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Slett turnering"),
      content: Text(
        "Er du sikker på at du vil slette '$name'?\n\nDette kan ikke angres!",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Avbryt"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.adminDanger,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Slett"),
        ),
      ],
    ),
  );
  if (confirm == true && context.mounted) {
    try {
      await _deleteTournamentCascade(id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Turnering '$name' slettet.",
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Feil ved sletting: $e",
            ),
          ),
        );
      }
    }
  }
}

Widget _tournamentThumb(Map<String, dynamic> data, {double size = 40}) {
  final imageUrl = data['image_url'] as String? ?? '';
  if (imageUrl.isNotEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => AdminIconTile(icon: Icons.emoji_events_outlined, size: size),
      ),
    );
  }
  return AdminIconTile(icon: Icons.emoji_events_outlined, size: size);
}

Widget _registrationCell(Map<String, dynamic> data) {
  final isOpen = (data['registration_status'] as String? ?? 'open') == 'open';
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      isOpen ? const AdminPill.success('Åpen') : const AdminPill.neutral('Stengt'),
      const SizedBox(height: 4),
      Text('Frist ${shortDate(data['registration_deadline'] as String?)}',
          style: AdminText.ui(size: 12, color: AppColors.adminTextSecondary)),
    ],
  );
}

/// Statuspille + undertekst for en turnering.
Widget _statusCell(Map<String, dynamic> data, _TourStats st, int pendingRegs, {bool testMode = false}) {
  final phase = _tournamentPhase(data);
  Widget pill;
  String sub;
  if (st.liveMatches.isNotEmpty) {
    pill = const AdminPill.live(dot: true);
    sub = st.liveMatches.length == 1 ? '1 kamp pågår' : '${st.liveMatches.length} kamper pågår';
  } else if (phase == 'live') {
    pill = const AdminPill.info('Pågår');
    sub = '${st.finishedMatches} / ${st.totalMatches} kamper ferdig';
  } else if (phase == 'done') {
    pill = const AdminPill.success('Ferdig');
    sub = '${st.finishedMatches} / ${st.totalMatches} kamper';
  } else {
    pill = const AdminPill.info('Kommende');
    if (pendingRegs > 0) {
      sub = pendingRegs == 1 ? '1 påmelding venter' : '$pendingRegs påmeldinger venter';
    } else if (testMode) {
      sub = '';
    } else if (st.totalMatches == 0) {
      sub = 'Oppsett ikke generert';
    } else {
      sub = '${st.totalMatches} kamper satt opp';
    }
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      pill,
      if (sub.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(sub,
            style: AdminText.ui(size: 12, color: AppColors.adminTextSecondary),
            overflow: TextOverflow.ellipsis),
      ],
    ],
  );
}

Widget _visibilityCell(_TourStats st, {bool testMode = false}) {
  if (testMode) return const SizedBox.shrink();
  final pub = st.published;
  final color = pub ? AppColors.green : AppColors.adminTextSecondary;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(pub ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 16, color: color),
      const SizedBox(width: 6),
      Text(pub ? 'Publisert' : 'Skjult', style: AdminText.ui(size: 13, color: color)),
    ],
  );
}

Widget _teamsCell(_TourStats st, {double barWidth = 88}) {
  final max = st.maxTeams;
  final label = max != null && max > 0 ? '${st.teams} / $max' : '${st.teams}';
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: AdminText.mono(size: 13)),
      if (max != null && max > 0) ...[
        const SizedBox(height: 6),
        AdminProgressBar(value: st.teams / max, width: barWidth),
      ],
    ],
  );
}

// ════════════════════════════════════════════════════════════════════════════
// Listevisning (tabell på nettbrett/desktop, kort på mobil)
// ════════════════════════════════════════════════════════════════════════════

class _TournamentTable extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Map<String, int> pendingRegs;
  final bool testMode;

  const _TournamentTable({required this.items, required this.pendingRegs, required this.testMode});

  static const double _minWidth = 1040;

  @override
  Widget build(BuildContext context) {
    if (Responsive.isMobile(context)) {
      return Column(
        children: [
          for (final d in items)
            _TournamentCard(
              id: d['id'] as String? ?? '',
              data: d,
              isGrid: false,
              pendingRegs: pendingRegs[d['id']] ?? 0,
              testMode: testMode,
            ),
          const SizedBox(height: 12),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < _minWidth ? _minWidth : constraints.maxWidth;
        final table = SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: AppColors.adminTableHead,
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                child: Row(
                  children: [
                    const Expanded(child: AdminTh('Turnering')),
                    SizedBox(
                      width: 150,
                      child: Row(children: [
                        const AdminTh('Dato'),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_downward,
                          size: 12,
                          color: AppColors.adminPrimary.withValues(alpha: 0.9),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 120, child: AdminTh('Lag')),
                    const SizedBox(width: 110, child: AdminTh('Påmelding')),
                    const SizedBox(width: 170, child: AdminTh('Status')),
                    const SizedBox(width: 120, child: AdminTh('Synlighet')),
                    const SizedBox(width: 172),
                  ],
                ),
              ),
              const Divider(height: 1),
              for (final d in items)
                _TournamentRow(
                  data: d,
                  pendingRegs: pendingRegs[d['id']] ?? 0,
                  testMode: testMode,
                ),
            ],
          ),
        );
        if (constraints.maxWidth >= _minWidth) return table;
        return SingleChildScrollView(scrollDirection: Axis.horizontal, child: table);
      },
    );
  }
}

class _TournamentRow extends StatefulWidget {
  final Map<String, dynamic> data;
  final int pendingRegs;
  final bool testMode;

  const _TournamentRow({required this.data, required this.pendingRegs, required this.testMode});

  @override
  State<_TournamentRow> createState() => _TournamentRowState();
}

class _TournamentRowState extends State<_TournamentRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final id = data['id'] as String? ?? '';
    final name = data['name'] ?? 'Ukjent';
    final location = data['location'] ?? 'Ukjent sted';
    final type = _AdminDashboardState._typeLabel(data);

    return _TourStatsBuilder(
      id: id,
      data: data,
      testMode: widget.testMode,
      builder: (context, st) => MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openTournament(context, id, name),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
            decoration: BoxDecoration(
              color: _hover ? AppColors.adminRowHover : AppColors.adminSurface,
              border: const Border(bottom: BorderSide(color: AppColors.adminDivider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _tournamentThumb(data),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(name,
                                style: AdminText.ui(size: 15, weight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.testMode ? location : '$type · $location',
                                    style: AdminText.ui(size: 13, color: AppColors.adminTextSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: Text(
                    _formatDateRange(data['start_date'] as String?, data['end_date'] as String?),
                    style: AdminText.mono(size: 13),
                  ),
                ),
                SizedBox(width: 120, child: Align(alignment: Alignment.centerLeft, child: _teamsCell(st))),
                SizedBox(width: 110, child: Align(alignment: Alignment.centerLeft, child: _registrationCell(data))),
                SizedBox(
                  width: 170,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _statusCell(data, st, widget.pendingRegs, testMode: widget.testMode),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Align(alignment: Alignment.centerLeft, child: _visibilityCell(st, testMode: widget.testMode)),
                ),
                SizedBox(
                  width: 172,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: AdminButton(
                            label: 'Administrer',
                            height: 40,
                            onPressed: () => _openTournament(context, id, name),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      AdminGhostIconButton(
                        icon: Icons.delete_outline,
                        color: AppColors.adminDanger,
                        size: 44,
                        tooltip: 'Slett turnering',
                        onPressed: () => _confirmDeleteTournament(context, id, name),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Gruppert visning: Pågår nå (hero) · Kommende (kort) · Tidligere (liste)
// ════════════════════════════════════════════════════════════════════════════

class _TournamentGrouped extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Map<String, int> pendingRegs;
  final bool testMode;

  const _TournamentGrouped({required this.items, required this.pendingRegs, required this.testMode});

  Widget _section(String title, int count) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Row(
          children: [
            Text(title, style: AdminText.ui(size: 20, weight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text('$count', style: AdminText.mono(size: 13, color: AppColors.adminTextSecondary)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final live = items.where((d) => _tournamentPhase(d) == 'live').toList();
    final upcoming = items.where((d) => _tournamentPhase(d) == 'upcoming').toList();
    final past = items.where((d) => _tournamentPhase(d) == 'done').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in live) ...[
          _LiveHeroCard(data: d, testMode: testMode),
          const SizedBox(height: 20),
        ],
        if (upcoming.isNotEmpty) ...[
          _section('Kommende', upcoming.length),
          LayoutBuilder(builder: (context, c) {
            const gap = 16.0;
            final cols = c.maxWidth >= 1000 ? 3 : (c.maxWidth >= 660 ? 2 : 1);
            final w = cols == 1 ? c.maxWidth : (c.maxWidth - gap * (cols - 1)) / cols - 0.1;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final d in upcoming)
                  SizedBox(
                    width: w,
                    child: _TournamentCard(
                      id: d['id'] as String? ?? '',
                      data: d,
                      isGrid: true,
                      pendingRegs: pendingRegs[d['id']] ?? 0,
                      testMode: testMode,
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: 20),
        ],
        if (past.isNotEmpty) ...[
          _section('Tidligere', past.length),
          AdminCard(
            child: Column(
              children: [
                for (final d in past) _PastRow(data: d, testMode: testMode),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _LiveHeroCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool testMode;

  const _LiveHeroCard({required this.data, required this.testMode});

  @override
  Widget build(BuildContext context) {
    final id = data['id'] as String? ?? '';
    final name = data['name'] as String? ?? 'Ukjent';
    final location = data['location'] as String? ?? 'Ukjent sted';
    final courts = (data['courts_count'] as num?)?.toInt();
    final start = parseNoDate(data['start_date'] as String?);
    final end = parseNoDate(data['end_date'] as String?);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String dayInfo = 'PÅGÅR NÅ';
    if (start != null && end != null) {
      final total = end.difference(start).inDays + 1;
      final day = today.difference(start).inDays + 1;
      if (total > 1) dayInfo = 'PÅGÅR NÅ · DAG $day AV $total';
    }
    final white75 = Colors.white.withValues(alpha: 0.75);

    return _TourStatsBuilder(
      id: id,
      data: data,
      testMode: testMode,
      builder: (context, st) {
        final meta = [
          location,
          _formatDateRange(data['start_date'] as String?, data['end_date'] as String?),
          '${st.teams} lag',
          if (courts != null) '$courts baner',
          if (!testMode) (st.published ? 'Publisert' : 'Skjult'),
        ].join(' · ');
        final progress = st.totalMatches == 0 ? 0.0 : st.finishedMatches / st.totalMatches;

        final left = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              if (st.liveMatches.isNotEmpty) ...[
                const AdminPill.live(dot: true),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(dayInfo,
                    style: AdminText.mono(size: 11, color: white75, letterSpacing: 1.3),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 16),
            Text(name,
                style: AppText.dispH1(40).copyWith(color: Colors.white, height: 1.0),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text(meta, style: AdminText.ui(size: 14, color: white75)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text('Kamper ferdig', style: AdminText.ui(size: 13, color: Colors.white.withValues(alpha: 0.8)))),
              Text('${st.finishedMatches} / ${st.totalMatches}', style: AdminText.mono(size: 13, color: Colors.white.withValues(alpha: 0.8))),
            ]),
            const SizedBox(height: 8),
            AdminProgressBar(
              value: progress,
              height: 8,
              color: Colors.white,
              track: Colors.white.withValues(alpha: 0.12),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 28,
              runSpacing: 12,
              children: [
                _heroStat('LIVE nå', Text('${st.liveMatches.length}', style: AdminText.ui(size: 22, weight: FontWeight.w700, color: Colors.white))),
                _heroStat(
                  'Forsinket',
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '${st.delayed}', style: AdminText.ui(size: 22, weight: FontWeight.w700, color: Colors.white)),
                    if (st.delayedInfo != null)
                      TextSpan(text: '  ${st.delayedInfo}', style: AdminText.ui(size: 13, weight: FontWeight.w500, color: white75)),
                  ])),
                ),
                _heroStat('Neste runde', Text(st.nextTime ?? '–', style: AdminText.mono(size: 22, weight: FontWeight.w600, color: Colors.white))),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.ink,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: AdminText.ui(size: 14, weight: FontWeight.w600),
                  ),
                  onPressed: () => _openTournament(context, id, name, initialTab: 1),
                  child: const Text('Åpne kampprogram'),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: () => _openTournament(context, id, name),
                  child: const Text('Administrer'),
                ),
              ],
            ),
          ],
        );

        final right = Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: st.liveMatches.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Ingen kamper pågår akkurat nå',
                        style: AdminText.ui(size: 14, color: white75)),
                  ),
                )
              : Column(
                  children: [
                    for (final m in st.liveMatches)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 64,
                              child: Text(_courtLabel(m['court'] as String?),
                                  style: AdminText.mono(size: 11, color: white75)),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${m['team_a_name'] ?? 'TBD'}',
                                      style: AdminText.ui(size: 14, color: Colors.white, height: 1.5),
                                      overflow: TextOverflow.ellipsis),
                                  Text('${m['team_b_name'] ?? 'TBD'}',
                                      style: AdminText.ui(size: 14, color: Colors.white, height: 1.5),
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(liveScoreLine(m, true),
                                    style: AdminText.mono(size: 15, weight: FontWeight.w600, color: Colors.white, height: 1.5)),
                                Text(liveScoreLine(m, false),
                                    style: AdminText.mono(size: 15, weight: FontWeight.w600, color: Colors.white, height: 1.5)),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        );

        return Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: AppColors.heroNavy,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x330B1B33), blurRadius: 40, offset: Offset(0, 16))],
          ),
          child: LayoutBuilder(builder: (context, c) {
            if (c.maxWidth < 820) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [left, const SizedBox(height: 24), right],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 11, child: left),
                const SizedBox(width: 28),
                Expanded(flex: 9, child: right),
              ],
            );
          }),
        );
      },
    );
  }

  Widget _heroStat(String label, Widget value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AdminText.ui(size: 12, color: Colors.white.withValues(alpha: 0.75))),
          value,
        ],
      );
}

class _PastRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool testMode;
  const _PastRow({required this.data, required this.testMode});

  @override
  Widget build(BuildContext context) {
    final id = data['id'] as String? ?? '';
    final name = data['name'] ?? 'Ukjent';
    final location = data['location'] ?? 'Ukjent sted';
    final type = _AdminDashboardState._typeLabel(data);
    return _TourStatsBuilder(
      id: id,
      data: data,
      testMode: testMode,
      builder: (context, st) => InkWell(
        onTap: () => _openTournament(context, id, name),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.adminDivider))),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 220, maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, style: AdminText.ui(size: 14, weight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                    Text('$type · $location',
                        style: AdminText.ui(size: 13, color: AppColors.adminTextSecondary),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 0,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(_formatDateRange(data['start_date'] as String?, data['end_date'] as String?),
                        style: AdminText.mono(size: 13)),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text('${st.teams} lag', style: AdminText.ui(size: 13, color: AppColors.adminTextSecondary)),
                  ),
                  const AdminPill.success('Ferdig'),
                  const SizedBox(width: 16),
                  AdminButton(label: 'Administrer', height: 40, onPressed: () => _openTournament(context, id, name)),
                  AdminGhostIconButton(
                    icon: Icons.delete_outline,
                    color: AppColors.adminDanger,
                    size: 44,
                    tooltip: 'Slett turnering',
                    onPressed: () => _confirmDeleteTournament(context, id, name),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Turneringskort – brukes i mobil-listen og under «Kommende» i gruppert visning.
class _TournamentCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final bool isGrid;
  final int pendingRegs;
  final bool testMode;

  const _TournamentCard({
    required this.id,
    required this.data,
    required this.isGrid,
    this.pendingRegs = 0,
    this.testMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? 'Ukjent';
    final location = data['location'] ?? 'Ukjent sted';
    final type = _AdminDashboardState._typeLabel(data);
    final deadline = data['registration_deadline'] as String?;
    final isOpen = (data['registration_status'] as String? ?? 'open') == 'open';

    return _TourStatsBuilder(
      id: id,
      data: data,
      testMode: testMode,
      builder: (context, st) {
        String todo;
        IconData todoIcon = Icons.info_outline;
        if (st.liveMatches.isNotEmpty) {
          todo = '${st.liveMatches.length} kamper pågår';
          todoIcon = Icons.sensors;
        } else if (pendingRegs > 0) {
          todo = pendingRegs == 1 ? '1 påmelding venter' : '$pendingRegs påmeldinger venter';
        } else if (!testMode && st.totalMatches == 0) {
          todo = 'Oppsett ikke generert';
        } else if (!testMode) {
          todo = '${st.finishedMatches} / ${st.totalMatches} kamper ferdig';
          todoIcon = Icons.check_circle_outline;
        } else {
          todo = location;
          todoIcon = Icons.location_on_outlined;
        }

        return Card(
          margin: isGrid ? EdgeInsets.zero : const EdgeInsets.fromLTRB(12, 12, 12, 0),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openTournament(context, id, name),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                AdminPill.info(type, height: 22),
                                if (!testMode)
                                  Text(st.published ? 'Publisert' : 'Skjult',
                                      style: AdminText.ui(size: 12, color: AppColors.adminTextSecondary)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(name,
                                style: AdminText.ui(size: 17, weight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text.rich(
                              TextSpan(children: [
                                TextSpan(text: '$location · '),
                                TextSpan(
                                  text: _formatDateRange(data['start_date'] as String?, data['end_date'] as String?, withYear: false),
                                  style: AdminText.mono(size: 13, color: AppColors.adminTextSecondary),
                                ),
                              ]),
                              style: AdminText.ui(size: 13, color: AppColors.adminTextSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      AdminGhostIconButton(
                        icon: Icons.delete_outline,
                        color: AppColors.adminDanger,
                        size: 36,
                        tooltip: 'Slett turnering',
                        onPressed: () => _confirmDeleteTournament(context, id, name),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: const BoxDecoration(
                      border: Border.symmetric(horizontal: BorderSide(color: AppColors.adminDivider)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AdminStat(
                            label: 'Lag',
                            value: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  st.maxTeams != null && st.maxTeams! > 0 ? '${st.teams}/${st.maxTeams}' : '${st.teams}',
                                  style: AdminText.ui(size: 22, weight: FontWeight.w700),
                                ),
                                if (st.maxTeams != null && st.maxTeams! > 0) ...[
                                  const SizedBox(height: 6),
                                  AdminProgressBar(value: st.teams / st.maxTeams!),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AdminStat(
                            label: 'Frist',
                            value: Text(shortDate(deadline),
                                style: AdminText.ui(size: 22, weight: FontWeight.w700, color: AppColors.adminWarning)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AdminStat(
                            label: 'Påmelding',
                            value: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: isOpen ? const AdminPill.success('Åpen') : const AdminPill.neutral('Stengt')),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(todoIcon, size: 16, color: AppColors.adminPrimary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(todo,
                            style: AdminText.ui(size: 13, color: AppColors.adminTextBody),
                            overflow: TextOverflow.ellipsis),
                      ),
                      AdminButton(
                        label: 'Administrer',
                        height: 40,
                        onPressed: () => _openTournament(context, id, name),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Sletter turneringen og alt som hører til den (kamper + events, lag,
/// kategorier, påmeldinger). Spillere og brukere røres ikke.
/// Turneringsdokumentet slettes sist, så et avbrutt forsøk kan kjøres på nytt.
Future<void> _deleteTournamentCascade(String id) async {
  final db = FirebaseFirestore.instance;
  final refs = <DocumentReference>[];

  final matches = await db.collection('matches').where('tournament_id', isEqualTo: id).get();
  for (final match in matches.docs) {
    final events = await match.reference.collection('events').get();
    refs.addAll(events.docs.map((e) => e.reference));
    refs.add(match.reference);
  }
  for (final col in ['teams', 'categories', 'registrations']) {
    final snap = await db.collection(col).where('tournament_id', isEqualTo: id).get();
    refs.addAll(snap.docs.map((d) => d.reference));
  }

  // Firestore tillater maks 500 operasjoner per batch.
  for (var i = 0; i < refs.length; i += 450) {
    final batch = db.batch();
    for (final ref in refs.skip(i).take(450)) {
      batch.delete(ref);
    }
    await batch.commit();
  }

  await db.collection('tournaments').doc(id).delete();
}
