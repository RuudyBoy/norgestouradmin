import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme/app_colors.dart';

class TournamentSchedulePage extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;
  final int courtsCount;
  final int matchDurationMinutes;

  const TournamentSchedulePage({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    required this.courtsCount,
    required this.matchDurationMinutes,
  });

  @override
  State<TournamentSchedulePage> createState() => _TournamentSchedulePageState();
}

class _TournamentSchedulePageState extends State<TournamentSchedulePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  int _breakBetweenRounds = 5; // minutes
  bool _isGenerating = false;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.adminOrangeHover : null,
      ));

  String _fmtTime(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
  }

  int _startMinutes() => _startTime.hour * 60 + _startTime.minute;

  // ─── Round ordering ────────────────────────────────────────────────────────

  int _roundOrder(Map d) {
    final stage = d['stage'] as String? ?? '';
    final matchType = d['match_type'] as String? ?? '';
    final round = d['round'] as String? ?? '';

    if (stage == 'group') {
      if (matchType == 'group_match_1' || matchType == 'group_match_2') return 1;
      if (matchType == 'group_match_3' || matchType == 'group_match_4') return 2;
      if (matchType == 'group_match_5') return 3;
      return 1;
    }
    if (stage == 'playoff') {
      if (round == 'omspill') return 9;
      if (round == 'r16') return 10;
      if (round == 'r8') return 11;
      if (round == 'qf') return 12;
      if (round == 'sf') return 13;
      if (round == 'final') return 14;
    }
    return 99;
  }

  String _roundLabel(Map d) {
    final stage = d['stage'] as String? ?? '';
    final matchType = d['match_type'] as String? ?? '';
    final round = d['round'] as String? ?? '';
    final bracket = d['bracket'] as String? ?? '';

    if (stage == 'group') {
      if (matchType == 'group_match_1' || matchType == 'group_match_2') return 'Runde 1 – Puljespill';
      if (matchType == 'group_match_3' || matchType == 'group_match_4') return 'Runde 2 – Puljespill';
      if (matchType == 'group_match_5') return 'Runde 3 – Puljespill';
    }
    if (stage == 'playoff') {
      final bl = bracket.toUpperCase();
      if (round == 'omspill') return '$bl-Bracket – Playoff';
      if (round == 'r16') return '$bl-Bracket – 1/16';
      if (round == 'r8') return '$bl-Bracket – 1/8';
      if (round == 'qf') return '$bl-Bracket – Kvartfinale';
      if (round == 'sf') return '$bl-Bracket – Semifinale';
      if (round == 'final') return '$bl-Bracket – FINALE';
    }
    return 'Ukjent runde';
  }

  // ─── Auto-generate schedule ────────────────────────────────────────────────

  Future<void> _generateSchedule() async {
    if (_selectedCategoryId == null) {
      _snack("Velg en klasse først.", isError: true);
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('matches')
          .where('tournament_id', isEqualTo: widget.tournamentId)
          .where('category_id', isEqualTo: _selectedCategoryId)
          .get();

      if (snap.docs.isEmpty) {
        _snack("Ingen kamper funnet. Generer grupper/sluttspill først.", isError: true);
        setState(() => _isGenerating = false);
        return;
      }

      // Sort by round order
      final docs = List<DocumentSnapshot>.from(snap.docs)
        ..sort((a, b) {
          final ao = _roundOrder(a.data() as Map);
          final bo = _roundOrder(b.data() as Map);
          if (ao != bo) return ao.compareTo(bo);
          // Within same round: sort by group then match type
          final ag = (a.data() as Map)['group'] as String? ?? '';
          final bg = (b.data() as Map)['group'] as String? ?? '';
          return ag.compareTo(bg);
        });

      // Group by round order
      final Map<int, List<DocumentSnapshot>> byRound = {};
      for (final doc in docs) {
        final order = _roundOrder(doc.data() as Map);
        byRound.putIfAbsent(order, () => []).add(doc);
      }

      final batch = FirebaseFirestore.instance.batch();
      int currentMinutes = _startMinutes();

      for (final roundOrder in (byRound.keys.toList()..sort())) {
        final roundMatches = byRound[roundOrder]!;
        // Assign courts: distribute evenly across available courts
        final numCourts = widget.courtsCount;
        final numSlots = (roundMatches.length / numCourts).ceil();

        for (int slot = 0; slot < numSlots; slot++) {
          final slotMinutes = currentMinutes + slot * widget.matchDurationMinutes;
          for (int court = 0; court < numCourts; court++) {
            final idx = slot * numCourts + court;
            if (idx >= roundMatches.length) break;
            final match = roundMatches[idx];
            batch.update(match.reference, {
              'court': 'Bane ${court + 1}',
              'match_time': _fmtTime(slotMinutes),
              'scheduled_minutes': slotMinutes,
            });
          }
        }
        // Advance time: numSlots × matchDuration + break
        currentMinutes += numSlots * widget.matchDurationMinutes + _breakBetweenRounds;
      }

      await batch.commit();
      _snack("Kampskjema generert!");
    } catch (e) {
      _snack("Feil: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Kampskjema – ${widget.tournamentName}"),
        
        
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.adminText,
          labelColor: AppColors.adminText,
          unselectedLabelColor: AppColors.adminTextSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.schedule), text: "Tidskjema"),
            Tab(icon: Icon(Icons.account_tree), text: "Kryssninger"),
          ],
        ),
        actions: [
          if (_isGenerating)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: AppColors.adminText, strokeWidth: 2)),
            )
          else
            TextButton.icon(
              onPressed: _showGenerateDialog,
              icon: const Icon(Icons.auto_fix_high, color: AppColors.adminText),
              label: const Text("Auto-skjema", style: TextStyle(color: AppColors.adminText)),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildCategorySelector(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildScheduleTab(),
                _buildCrossingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Category selector ─────────────────────────────────────────────────────

  Widget _buildCategorySelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('categories')
          .where('tournament_id', isEqualTo: widget.tournamentId)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SizedBox(height: 48, child: LinearProgressIndicator());
        final cats = snap.data!.docs;
        if (cats.isEmpty) return const SizedBox.shrink();

        if (_selectedCategoryId == null && cats.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedCategoryId = cats.first.id);
          });
        }

        return Container(
          color: AppColors.adminSurfaceElevated,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.category, size: 16, color: AppColors.adminOrange),
              const SizedBox(width: 8),
              const Text("Klasse:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedCategoryId,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: cats.map((c) {
                    final d = c.data() as Map<String, dynamic>;
                    return DropdownMenuItem(value: c.id, child: Text(d['name'] ?? ''));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Tab 1: Tidskjema ──────────────────────────────────────────────────────

  Widget _buildScheduleTab() {
    if (_selectedCategoryId == null) {
      return const Center(child: Text("Velg en klasse."));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('tournament_id', isEqualTo: widget.tournamentId)
          .where('category_id', isEqualTo: _selectedCategoryId)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 48, color: AppColors.adminTextSecondary),
                const SizedBox(height: 12),
                const Text("Ingen kamper generert enda.",
                    style: TextStyle(fontSize: 15, color: AppColors.adminTextSecondary)),
                const SizedBox(height: 6),
                const Text("Generer grupper og sluttspill først.",
                    style: TextStyle(fontSize: 12, color: AppColors.adminTextSecondary)),
              ],
            ),
          );
        }

        // Sort by scheduled_minutes, then round order
        final sorted = List<DocumentSnapshot>.from(docs)
          ..sort((a, b) {
            final am = (a.data() as Map)['scheduled_minutes'] as int? ?? _roundOrder(a.data() as Map) * 10000;
            final bm = (b.data() as Map)['scheduled_minutes'] as int? ?? _roundOrder(b.data() as Map) * 10000;
            if (am != bm) return am.compareTo(bm);
            final ac = (a.data() as Map)['court'] as String? ?? '';
            final bc = (b.data() as Map)['court'] as String? ?? '';
            return ac.compareTo(bc);
          });

        // Group by round label
        final Map<String, List<DocumentSnapshot>> byRound = {};
        for (final doc in sorted) {
          final label = _roundLabel(doc.data() as Map);
          byRound.putIfAbsent(label, () => []).add(doc);
        }

        // Preserve insertion order (already sorted)
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: byRound.length,
          itemBuilder: (ctx, i) {
            final label = byRound.keys.elementAt(i);
            final matches = byRound[label]!;
            return _buildRoundSection(label, matches);
          },
        );
      },
    );
  }

  Widget _buildRoundSection(String label, List<DocumentSnapshot> matches) {
    final firstTime = (matches.first.data() as Map)['match_time'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 16, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.adminText,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: AppColors.adminText,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              if (firstTime != null)
                Text("fra $firstTime",
                    style: const TextStyle(color: AppColors.adminTextSecondary, fontSize: 11)),
            ],
          ),
        ),
        // Group by time slot
        ..._buildTimeSlots(matches),
        const SizedBox(height: 4),
      ],
    );
  }

  List<Widget> _buildTimeSlots(List<DocumentSnapshot> matches) {
    // Group by match_time
    final Map<String, List<DocumentSnapshot>> byTime = {};
    for (final m in matches) {
      final t = (m.data() as Map)['match_time'] as String? ?? 'TBD';
      byTime.putIfAbsent(t, () => []).add(m);
    }

    return byTime.entries.map((entry) {
      final time = entry.key;
      final slotMatches = entry.value..sort((a, b) {
        final ac = (a.data() as Map)['court'] as String? ?? '';
        final bc = (b.data() as Map)['court'] as String? ?? '';
        return ac.compareTo(bc);
      });

      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time label
            SizedBox(
              width: 50,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  time,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.adminText,
                  ),
                ),
              ),
            ),
            // Match cards
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: slotMatches.map((m) => _buildMatchCard(m)).toList(),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildMatchCard(DocumentSnapshot matchDoc) {
    final d = matchDoc.data() as Map<String, dynamic>;
    final matchNum = d['match_number'] as int?;
    final court = d['court'] as String? ?? 'Bane ?';
    final teamA = d['team_a_name'] as String? ?? 'TBD';
    final teamB = d['team_b_name'] as String? ?? 'TBD';
    final status = d['status'] as String? ?? 'scheduled';
    final isFinished = status == 'finished';
    final isPending = status == 'pending' || d['team_a_id'] == 'placeholder' || d['team_b_id'] == 'placeholder';
    final group = d['group'] as String?;
    final bracket = d['bracket'] as String?;

    Color borderColor = AppColors.adminTextSecondary;
    if (isFinished) borderColor = AppColors.green;
    if (status == 'live') borderColor = AppColors.adminOrange;

    return GestureDetector(
      onTap: () => _editMatchDialog(matchDoc),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(8),
          color: isFinished
              ? AppColors.green.withOpacity(0.1)
              : isPending
                  ? AppColors.adminTextSecondary
                  : AppColors.adminText,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Court + tag
            Row(
              children: [
                if (matchNum != null) ...[
                  Text('Kamp $matchNum',
                      style: const TextStyle(fontSize: 9, color: AppColors.adminOrange, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 5),
                ],
                Text(court,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.adminTextSecondary)),
                const Spacer(),
                if (group != null)
                  _tag("Pulje $group", AppColors.adminSurfaceElevated, AppColors.adminText)
                else if (bracket != null)
                  _tag("$bracket-bracket", AppColors.adminOrangeHover.withOpacity(0.2), AppColors.adminOrangeHover),
                if (isFinished)
                  _tag("Ferdig", AppColors.green.withOpacity(0.2), AppColors.green)
                else if (status == 'live')
                  _tag("LIVE", AppColors.adminOrange.withOpacity(0.2), AppColors.adminOrangeHover),
              ],
            ),
            const SizedBox(height: 6),
            // Teams
            Text(
              teamA,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isPending ? AppColors.adminTextSecondary : null,
                fontStyle: isPending ? FontStyle.italic : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    teamB,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isPending ? AppColors.adminTextSecondary : null,
                      fontStyle: isPending ? FontStyle.italic : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isFinished)
                  Text(
                    "${d['home_score']} – ${d['away_score']}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.green),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color bg, Color fg) => Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: TextStyle(fontSize: 9, color: fg, fontWeight: FontWeight.bold)),
      );

  // ─── Tab 2: Kryssninger ────────────────────────────────────────────────────

  Widget _buildCrossingsTab() {
    if (_selectedCategoryId == null) {
      return const Center(child: Text("Velg en klasse."));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('tournament_id', isEqualTo: widget.tournamentId)
          .where('category_id', isEqualTo: _selectedCategoryId)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("Ingen kamper funnet."));
        }

        // Separate group and playoff
        final group = docs.where((d) => (d.data() as Map)['stage'] == 'group').toList()
          ..sort((a, b) {
            final ag = (a.data() as Map)['group'] as String? ?? '';
            final bg = (b.data() as Map)['group'] as String? ?? '';
            if (ag != bg) return ag.compareTo(bg);
            return _roundOrder(a.data() as Map).compareTo(_roundOrder(b.data() as Map));
          });

        final playoff = docs.where((d) => (d.data() as Map)['stage'] == 'playoff').toList()
          ..sort((a, b) {
            final ab = (a.data() as Map)['bracket'] as String? ?? '';
            final bb = (b.data() as Map)['bracket'] as String? ?? '';
            if (ab != bb) return ab.compareTo(bb);
            return _roundOrder(a.data() as Map).compareTo(_roundOrder(b.data() as Map));
          });

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (group.isNotEmpty) ...[
              _sectionHeader("Puljespill", Icons.grid_view, AppColors.adminText),
              const SizedBox(height: 8),
              _buildGroupCrossings(group),
            ],
            if (playoff.isNotEmpty) ...[
              const SizedBox(height: 16),
              _sectionHeader("Sluttspill (bracket)", Icons.account_tree, AppColors.adminOrangeHover),
              const SizedBox(height: 8),
              _buildPlayoffCrossings(playoff),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(icon, color: AppColors.adminText, size: 16),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: AppColors.adminText,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ],
        ),
      );

  Widget _buildGroupCrossings(List<DocumentSnapshot> matches) {
    // Group by pulje
    final Map<String, List<DocumentSnapshot>> byGroup = {};
    for (final m in matches) {
      final g = (m.data() as Map)['group'] as String? ?? '?';
      byGroup.putIfAbsent(g, () => []).add(m);
    }

    return Column(
      children: byGroup.entries.map((entry) {
        final group = entry.key;
        final gMatches = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.adminSurfaceElevated),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.adminSurfaceElevated,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Text("Pulje $group",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.adminText)),
              ),
              ...gMatches.map((m) => _crossingRow(m, isPlayoff: false)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlayoffCrossings(List<DocumentSnapshot> matches) {
    final Map<String, List<DocumentSnapshot>> byBracket = {};
    for (final m in matches) {
      final b = ((m.data() as Map)['bracket'] as String? ?? '?').toUpperCase();
      byBracket.putIfAbsent(b, () => []).add(m);
    }

    return Column(
      children: byBracket.entries.map((entry) {
        final bracket = entry.key;
        final bMatches = entry.value;
        final color = bracket == 'A'
            ? AppColors.adminOrange
            : bracket == 'B'
                ? AppColors.green
                : AppColors.adminTextSecondary;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Text("$bracket-Bracket",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12, color: color)),
              ),
              ...bMatches.map((m) => _crossingRow(m, isPlayoff: true)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _crossingRow(DocumentSnapshot matchDoc, {required bool isPlayoff}) {
    final d = matchDoc.data() as Map<String, dynamic>;
    final num = d['match_number'] as int?;
    final teamA = d['team_a_name'] as String? ?? 'TBD';
    final teamB = d['team_b_name'] as String? ?? 'TBD';
    final time = d['match_time'] as String?;
    final court = d['court'] as String?;
    final status = d['status'] as String? ?? 'scheduled';
    final isFinished = status == 'finished';
    final isPending = d['team_a_id'] == 'placeholder' || d['team_b_id'] == 'placeholder';
    final round = d['round'] as String? ?? '';
    final matchType = d['match_type'] as String? ?? '';

    // Build match description
    String desc = '';
    if (isPlayoff) {
      if (round == 'omspill') desc = 'PO';
      if (round == 'r16') desc = '1/16';
      if (round == 'r8') desc = '1/8';
      if (round == 'qf') desc = 'KF';
      if (round == 'sf') desc = 'SF';
      if (round == 'final') desc = 'FIN';
    } else {
      if (matchType == 'group_match_1') desc = 'K1';
      if (matchType == 'group_match_2') desc = 'K2';
      if (matchType == 'group_match_3') desc = 'K3 (V→1st)';
      if (matchType == 'group_match_4') desc = 'K3 (T→3rd)';
      if (matchType == 'group_match_5') desc = 'K4';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: AppColors.adminTextSecondary)),
        color: isFinished ? AppColors.green.withOpacity(0.1) : null,
      ),
      child: Row(
        children: [
          // Match number / label
          SizedBox(
            width: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (num != null)
                  Text("Kamp $num",
                      style: TextStyle(fontSize: 9, color: AppColors.adminTextSecondary)),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // Teams
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(teamA,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isPending ? AppColors.adminTextSecondary : null,
                      fontStyle: isPending ? FontStyle.italic : null,
                    ),
                    overflow: TextOverflow.ellipsis),
                Text(teamB,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isPending ? AppColors.adminTextSecondary : null,
                      fontStyle: isPending ? FontStyle.italic : null,
                    ),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Time + court
          if (time != null || court != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (time != null)
                  Text(time,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                if (court != null && court != 'TBD')
                  Text(court,
                      style: TextStyle(fontSize: 10, color: AppColors.adminTextSecondary)),
              ],
            ),
          // Score / status
          const SizedBox(width: 8),
          if (isFinished)
            Text("${d['home_score']}–${d['away_score']}",
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.green))
          else
            Icon(
                isPending ? Icons.hourglass_empty : Icons.circle_outlined,
                size: 14,
                color: isPending ? AppColors.adminTextSecondary : AppColors.adminOrange),
        ],
      ),
    );
  }

  // ─── Auto-schedule dialog ──────────────────────────────────────────────────

  void _showGenerateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text("Generer kampskjema"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time, color: AppColors.adminOrange),
                title: const Text("Starttid"),
                subtitle:
                    Text(_startTime.format(ctx), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onTap: () async {
                  final t = await showTimePicker(
                      context: ctx, initialTime: _startTime);
                  if (t != null) set(() => _startTime = t);
                },
                trailing: const Icon(Icons.chevron_right),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.coffee, color: Colors.brown),
                title: const Text("Pause mellom runder"),
                trailing: DropdownButton<int>(
                  value: _breakBetweenRounds,
                  underline: const SizedBox(),
                  items: [0, 5, 10, 15, 20]
                      .map((n) => DropdownMenuItem(
                          value: n, child: Text("$n min")))
                      .toList(),
                  onChanged: (v) => set(() => _breakBetweenRounds = v ?? 5),
                ),
              ),
              const Divider(),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.adminSurfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Kampformat:",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text("${widget.courtsCount} baner  •  ${widget.matchDurationMinutes} min per kamp",
                        style: const TextStyle(fontSize: 12)),
                    Text("Starttid: ${_startTime.format(ctx)}  •  Pause: $_breakBetweenRounds min",
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text("Avbryt")),
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_fix_high),
              label: const Text("Generer"),
              style: ElevatedButton.styleFrom(
                   foregroundColor: AppColors.adminText),
              onPressed: () {
                Navigator.pop(ctx);
                _generateSchedule();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Quick edit match dialog ───────────────────────────────────────────────

  void _editMatchDialog(DocumentSnapshot matchDoc) {
    final d = matchDoc.data() as Map<String, dynamic>;
    final courtCtrl = TextEditingController(text: d['court'] as String? ?? '');
    final timeCtrl  = TextEditingController(text: d['match_time'] as String? ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("${d['team_a_name'] ?? 'A'} vs ${d['team_b_name'] ?? 'B'}",
            style: const TextStyle(fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: courtCtrl,
              decoration: const InputDecoration(
                  labelText: "Bane", border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.grid_view)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: timeCtrl,
              decoration: const InputDecoration(
                  labelText: "Tid (HH:MM)", border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.access_time)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Avbryt")),
          ElevatedButton(
            onPressed: () async {
              await matchDoc.reference.update({
                'court': courtCtrl.text.trim(),
                'match_time': timeCtrl.text.trim(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _snack("Kamp oppdatert.");
            },
            child: const Text("Lagre"),
          ),
        ],
      ),
    );
  }
}
