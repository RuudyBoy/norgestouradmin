import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme/app_colors.dart';

class RegistrationsPage extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;
  final String tournamentType;

  const RegistrationsPage({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    required this.tournamentType,
  });

  @override
  State<RegistrationsPage> createState() => _RegistrationsPageState();
}

class _RegistrationsPageState extends State<RegistrationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String? _selectedCategoryName;

  // Filter
  String _statusFilter = 'all'; // all | pending | accepted | waitlist | rejected
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Statusfarger ─────────────────────────────────────────────────────────
  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppColors.green;
      case 'waitlist':
        return AppColors.adminOrange;
      case 'rejected':
        return AppColors.adminOrange;
      default:
        return AppColors.adminOrange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Godkjent';
      case 'waitlist':
        return 'Venteliste';
      case 'rejected':
        return 'Avvist';
      default:
        return 'Venter';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle;
      case 'waitlist':
        return Icons.hourglass_top;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.pending;
    }
  }

  // ─── Oppdater status ───────────────────────────────────────────────────────
  Future<void> _updateStatus(String registrationId, String newStatus) async {
    await FirebaseFirestore.instance
        .collection('registrations')
        .doc(registrationId)
        .update({'status': newStatus});
    if (mounted) {
      _snack(
          "${_statusLabel(newStatus)} – oppdatert!");
    }
  }

  // ─── Batch: godkjenn alle pending ─────────────────────────────────────────
  Future<void> _acceptAllPending(List<DocumentSnapshot> docs) async {
    final pending = docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return data['status'] == 'pending';
    }).toList();

    if (pending.isEmpty) {
      _snack("Ingen ventende påmeldinger.");
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Godkjenn alle"),
        content:
            Text("Vil du godkjenne alle ${pending.length} ventende påmeldinger?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Avbryt")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green, foregroundColor: AppColors.adminText),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Godkjenn alle"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in pending) {
      batch.update(
          FirebaseFirestore.instance.collection('registrations').doc(doc.id),
          {'status': 'accepted'});
    }
    await batch.commit();
    if (mounted) _snack("${pending.length} påmeldinger godkjent!");
  }

  // ─── Seeding-preview ──────────────────────────────────────────────────────
  void _showSeedingPreview(List<DocumentSnapshot> docs) {
    final accepted =
        docs.where((d) => (d.data() as Map)['status'] == 'accepted').toList();

    accepted.sort((a, b) {
      final aR = (a.data() as Map)['combined_ranking'] as int? ?? 0;
      final bR = (b.data() as Map)['combined_ranking'] as int? ?? 0;
      return bR.compareTo(aR); // høyest ranking = seed 1
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Seeding-preview – ${_selectedCategoryName ?? 'Alle'}"),
        content: SizedBox(
          width: 400,
          child: accepted.isEmpty
              ? const Text("Ingen godkjente påmeldinger ennå.")
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: accepted.length,
                  itemBuilder: (ctx, i) {
                    final d = accepted[i].data() as Map<String, dynamic>;
                    final name1 = d['player1_name'] ?? '';
                    final name2 = d['player2_name'] ?? '';
                    final pts = d['combined_ranking'] as int? ?? 0;
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: _seedColor(i + 1),
                        child: Text("${i + 1}",
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.adminText,
                                fontWeight: FontWeight.bold)),
                      ),
                      title: Text("$name1 & $name2",
                          style: const TextStyle(fontSize: 13)),
                      trailing: Text("$pts pts",
                          style: TextStyle(
                              color: AppColors.adminTextSecondary, fontSize: 12)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Lukk")),
        ],
      ),
    );
  }

  Color _seedColor(int seed) {
    if (seed <= 4) return AppColors.adminOrange;
    if (seed <= 16) return AppColors.adminOrange;
    if (seed <= 32) return AppColors.green;
    return AppColors.adminTextSecondary;
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Påmeldinger", style: TextStyle(fontSize: 18)),
            Text(widget.tournamentName,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.adminTextSecondary)),
          ],
        ),
        
        
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.adminText,
          unselectedLabelColor: AppColors.adminTextSecondary,
          indicatorColor: AppColors.adminText,
          tabs: const [
            Tab(text: "Oversikt", icon: Icon(Icons.list_alt, size: 16)),
            Tab(text: "Klasser", icon: Icon(Icons.category, size: 16)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildCategoriesTab(),
        ],
      ),
    );
  }

  // ─── Tab 1: Oversikt (alle påmeldinger) ───────────────────────────────────
  Widget _buildOverviewTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('registrations')
          .where('tournament_id', isEqualTo: widget.tournamentId)
          .orderBy('combined_ranking', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data?.docs ?? [];

        // Statistikk
        final counts = {
          'all': all.length,
          'pending': all
              .where((d) => (d.data() as Map)['status'] == 'pending')
              .length,
          'accepted': all
              .where((d) => (d.data() as Map)['status'] == 'accepted')
              .length,
          'waitlist': all
              .where((d) => (d.data() as Map)['status'] == 'waitlist')
              .length,
          'rejected': all
              .where((d) => (d.data() as Map)['status'] == 'rejected')
              .length,
        };

        // Filter
        var filtered = _statusFilter == 'all'
            ? all
            : all
                .where((d) =>
                    (d.data() as Map)['status'] == _statusFilter)
                .toList();

        if (_searchQuery.isNotEmpty) {
          filtered = filtered.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final n1 = (data['player1_name'] ?? '').toString().toLowerCase();
            final n2 = (data['player2_name'] ?? '').toString().toLowerCase();
            final cat =
                (data['category_name'] ?? '').toString().toLowerCase();
            return n1.contains(_searchQuery) ||
                n2.contains(_searchQuery) ||
                cat.contains(_searchQuery);
          }).toList();
        }

        return Column(
          children: [
            // ── Stats-chips ─────────────────────────────────────────
            Container(
              color: AppColors.adminTextSecondary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _statChip("Alle", counts['all']!, 'all', AppColors.adminTextSecondary),
                  const SizedBox(width: 6),
                  _statChip(
                      "Venter", counts['pending']!, 'pending', AppColors.adminOrange),
                  const SizedBox(width: 6),
                  _statChip("Godkjent", counts['accepted']!, 'accepted',
                      AppColors.green),
                  const SizedBox(width: 6),
                  _statChip("Vente", counts['waitlist']!, 'waitlist',
                      AppColors.adminOrange),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.bar_chart),
                    tooltip: "Seeding-preview",
                    onPressed: () => _showSeedingPreview(all),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.check_circle,
                        color: AppColors.green, size: 16),
                    label: const Text("Godkjenn alle",
                        style: TextStyle(color: AppColors.green)),
                    onPressed: () => _acceptAllPending(all),
                  ),
                ],
              ),
            ),
            // ── Søkefelt ────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: "Søk på navn eller klasse...",
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  isDense: true,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          })
                      : null,
                ),
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              ),
            ),
            // ── Liste ───────────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 48, color: AppColors.adminTextSecondary),
                          const SizedBox(height: 8),
                          Text("Ingen påmeldinger",
                              style: TextStyle(color: AppColors.adminTextSecondary)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 6),
                      itemBuilder: (ctx, i) {
                        // Finn seed-nummer (kun blant godkjente, sortert)
                        final doc = filtered[i];
                        final data =
                            doc.data() as Map<String, dynamic>;
                        return _buildRegistrationCard(doc, data, i, all);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _statChip(String label, int count, String filter, Color color) {
    final selected = _statusFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : AppColors.adminTextSecondary,
          ),
        ),
        child: Text(
          "$label ($count)",
          style: TextStyle(
            color: selected ? color : AppColors.adminTextSecondary,
            fontSize: 12,
            fontWeight:
                selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationCard(DocumentSnapshot doc,
      Map<String, dynamic> data, int index, List<DocumentSnapshot> all) {
    final status = data['status'] as String? ?? 'pending';
    final p1 = data['player1_name'] ?? '';
    final p2 = data['player2_name'] ?? '';
    final p1club = data['player1_club'] ?? '';
    final p2club = data['player2_club'] ?? '';
    final p1pts = data['player1_ranking'] as int? ?? 0;
    final p2pts = data['player2_ranking'] as int? ?? 0;
    final combined = data['combined_ranking'] as int? ?? 0;
    final catName = data['category_name'] ?? '';
    final wildcard = data['wildcard_requested'] as bool? ?? false;

    // Seed-nummer blant godkjente
    final acceptedSorted = all
        .where((d) => (d.data() as Map)['status'] == 'accepted')
        .toList()
      ..sort((a, b) {
        final aR = (a.data() as Map)['combined_ranking'] as int? ?? 0;
        final bR = (b.data() as Map)['combined_ranking'] as int? ?? 0;
        return bR.compareTo(aR);
      });
    final seedIdx =
        acceptedSorted.indexWhere((d) => d.id == doc.id);
    final seedNum = seedIdx >= 0 ? seedIdx + 1 : null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // Seed-indikator
                SizedBox(
                  width: 36,
                  child: seedNum != null
                      ? CircleAvatar(
                          radius: 16,
                          backgroundColor: _seedColor(seedNum),
                          child: Text("$seedNum",
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.adminText,
                                  fontWeight: FontWeight.bold)),
                        )
                      : CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.adminTextSecondary,
                          child: Icon(Icons.help_outline,
                              size: 14, color: AppColors.adminTextSecondary),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "$p1 & $p2",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (wildcard)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text("WC",
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.adminOrangeHover,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "$catName • $p1club / $p2club",
                        style: TextStyle(
                            fontSize: 11, color: AppColors.adminTextSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Ranking: $combined pts ($p1pts + $p2pts)",
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.adminTextSecondary,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: _statusColor(status).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(status),
                          size: 12, color: _statusColor(status)),
                      const SizedBox(width: 3),
                      Text(_statusLabel(status),
                          style: TextStyle(
                              fontSize: 11,
                              color: _statusColor(status),
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            // Handlingsknapper
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status != 'accepted')
                  _actionBtn(
                    "Godkjenn",
                    AppColors.green,
                    Icons.check,
                    () => _updateStatus(doc.id, 'accepted'),
                  ),
                const SizedBox(width: 6),
                if (status != 'waitlist')
                  _actionBtn(
                    "Venteliste",
                    AppColors.adminOrange,
                    Icons.hourglass_top,
                    () => _updateStatus(doc.id, 'waitlist'),
                  ),
                const SizedBox(width: 6),
                if (status != 'rejected')
                  _actionBtn(
                    "Avvis",
                    AppColors.adminOrange,
                    Icons.close,
                    () => _updateStatus(doc.id, 'rejected'),
                  ),
                const SizedBox(width: 6),
                // Wildcard toggle
                IconButton(
                  tooltip: wildcard ? "Fjern wildcard" : "Gi wildcard",
                  icon: Icon(
                    wildcard ? Icons.star : Icons.star_border,
                    color: Colors.purple[600],
                    size: 18,
                  ),
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('registrations')
                        .doc(doc.id)
                        .update({'wildcard_requested': !wildcard});
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(
      String label, Color color, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ─── Tab 2: Per klasse ────────────────────────────────────────────────────
  Widget _buildCategoriesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('categories')
          .where('tournament_id', isEqualTo: widget.tournamentId)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final cats = snap.data!.docs;
        if (cats.isEmpty) {
          return const Center(child: Text("Ingen klasser funnet."));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: cats.length,
          itemBuilder: (ctx, i) {
            final cat = cats[i];
            final catData = cat.data() as Map<String, dynamic>;
            final catName = catData['name'] as String? ?? 'Ukjent';
            final maxTeams = catData['max_teams'] as int? ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                title: Text(catName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Maks $maxTeams lag"),
                leading: const CircleAvatar(
                  backgroundColor: AppColors.adminOrange,
                  child: Icon(Icons.sports_volleyball,
                      color: AppColors.adminText, size: 18),
                ),
                children: [
                  _buildCategoryRegistrations(cat.id, catName, maxTeams),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryRegistrations(
      String catId, String catName, int maxTeams) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('registrations')
          .where('tournament_id', isEqualTo: widget.tournamentId)
          .where('category_id', isEqualTo: catId)
          .orderBy('combined_ranking', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          );
        }
        final docs = snap.data!.docs;
        final acceptedCount =
            docs.where((d) => (d.data() as Map)['status'] == 'accepted').length;
        final pendingCount =
            docs.where((d) => (d.data() as Map)['status'] == 'pending').length;

        return Column(
          children: [
            // Status-oversikt for klassen
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _miniStat("Påmeldt", docs.length, AppColors.adminTextSecondary),
                  const SizedBox(width: 12),
                  _miniStat("Godkjent", acceptedCount, AppColors.green),
                  const SizedBox(width: 12),
                  _miniStat("Venter", pendingCount, AppColors.adminOrange),
                  const SizedBox(width: 12),
                  _miniStat("Plasser", maxTeams, AppColors.adminTextSecondary),
                ],
              ),
            ),
            if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text("Ingen påmeldinger i $catName",
                    style: TextStyle(color: AppColors.adminTextSecondary)),
              )
            else
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildRegistrationCard(doc, data, 0, docs);
              }),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _miniStat(String label, int count, Color color) => Column(
        children: [
          Text("$count",
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          Text(label,
              style: TextStyle(fontSize: 10, color: AppColors.adminTextSecondary)),
        ],
      );
}
