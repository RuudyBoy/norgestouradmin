// Proposed refactoring for AdminDashboard in lib/main.dart
// Strictly preserves all Firebase streams, AuthGate, data queries, and delete dialog actions.
// Adds responsive multi-column GridView, ultrawide max-width containment (1600px), and optional test parameters.

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'add_tournament_page.dart';
import 'tournament_control_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_login_page.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'admin_dashboard_overview.dart';
import 'admin_shell.dart';
import 'theme/responsive_layout.dart';

class AdminDashboard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: Colors.blue[800],
        foregroundColor: AppColors.adminText,
        automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context),
      ),

      // --- SIDEMENY (DRAWER) ---
      drawer: Responsive.isDesktopOrLarger(context) ? null : const AdminDrawer(),

      // --- FLYTENDE KNAPP FOR Å LAGE NY TURNERING ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTournamentPage()),
          );
        },
        label: const Text("Ny Turnering"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blue[800],
        foregroundColor: AppColors.adminText,
      ),

      // --- LISTE / GRID OVER TURNERINGER ---
      body: testTournaments != null || testMode
          ? _buildDashboardBody(context, testTournaments ?? const [])
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tournaments')
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildDashboardBody(context, const []);
                }

                final docs = snapshot.data!.docs;
                final items = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return {
                    'id': doc.id,
                    ...data,
                  };
                }).toList();

                return _buildDashboardBody(context, items);
              },
            ),
    );
  }

  Widget _buildDashboardBody(BuildContext context, List<Map<String, dynamic>> items) {
    return ResponsiveContainer.dashboard(
      padding: EdgeInsets.zero,
      child: CustomScrollView(
        slivers: [
          // Dashboard-oversikt (Statistikk for turneringer)
          SliverToBoxAdapter(
            child: AdminDashboardOverview(
              testTournaments: testTournaments,
              testMode: testMode,
            ),
          ),

          // Tom liste visning
          if (items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox,
                      size: 64,
                      color: AppColors.adminTextSecondary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Ingen turneringer enda. Trykk på knappen for å lage en!",
                    ),
                  ],
                ),
              ),
            )
          else
            // Responsive Multi-Column Grid
            SliverPadding(
              padding: Responsive.contentPaddingInsets(context, vertical: 12),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: ResponsiveLayout.gridColumns(
                    context,
                    mobile: 1,
                    tablet: 2,
                    desktop: 3,
                  ),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: Responsive.value<double>(
                    context,
                    mobile: 2.3,
                    tablet: 2.1,
                    desktop: 2.3,
                    ultrawide: 2.4,
                  ),
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final data = items[index];
                    final id = data['id'] as String? ?? '';
                    final name = data['name'] ?? 'Ukjent';
                    final location = data['location'] ?? 'Ukjent sted';
                    final start = data['start_date'] ?? '?';
                    final end = data['end_date'] ?? '?';
                    final imageUrl = data['image_url'] ?? '';

                    return Card(
                      elevation: 2,
                      margin: EdgeInsets.zero,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.blue[100],
                              backgroundImage: imageUrl.isNotEmpty
                                  ? NetworkImage(imageUrl)
                                  : null,
                              child: imageUrl.isEmpty
                                  ? const Icon(
                                      Icons.emoji_events,
                                      color: Colors.blue,
                                    )
                                  : null,
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.map,
                                      size: 16,
                                      color: AppColors.adminTextSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        location,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: AppColors.adminTextSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        "$start - $end",
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.only(
                              right: 12,
                              bottom: 8,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            TournamentControlPage(
                                              tournamentId: id,
                                              tournamentName: name,
                                            ),
                                      ),
                                    );
                                  },
                                  child: const Text("Administrer"),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Slett turnering',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text("Slett turnering"),
                                        content: Text(
                                          "Er du sikker på at du vil slette '$name'?\n\nDette kan ikke angres!",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text("Avbryt"),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor:
                                                  AppColors.adminText,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text("Slett"),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true && context.mounted) {
                                      try {
                                        await FirebaseFirestore.instance
                                            .collection('tournaments')
                                            .doc(id)
                                            .delete();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                "Turnering '$name' slettet.",
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                "Feil ved sletting: $e",
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: items.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
