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
        backgroundColor: AppColors.adminBg,
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
        backgroundColor: AppColors.adminBg,
        foregroundColor: AppColors.adminText,
      ),

      // --- LISTE / GRID OVER TURNERINGER ---
      body: (testTournaments != null || testMode)
          ? _buildDashboardBody(context, testTournaments ?? const [])
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tournaments')
                  .orderBy('created_at', descending: true) // Nyeste øverst
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
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
    );
  }

  Widget _buildDashboardBody(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) {
      return _buildEmptyState();
    }

    // Responsive containment: maks 1600px bredde for å hindre utstrekking på ultrawide
    return ResponsiveContainer.dashboard(
      maxWidth: ResponsiveLayout.dashboardMaxContentWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dashboard-oversikt (Statistikk for turneringer)
          AdminDashboardOverview(
            testTournaments: testTournaments,
            testMode: testMode,
            wrapInContainer: false,
            padding: EdgeInsets.zero,
          ),

          // Responsiv visning av turneringer (1 kolonne på mobil, 2 på nettbrett, grid på desktop)
          Expanded(
            child: _buildTournamentGrid(context, items),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentGrid(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    if (Responsive.isMobile(context)) {
      // Mobil (< 600px): enkel-kolonne liste
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final data = items[index];
          final id = data['id'] as String? ?? '';
          return _TournamentCard(
            id: id,
            data: data,
            isGrid: false,
          );
        },
      );
    } else if (Responsive.isTablet(context)) {
      // Nettbrett (600 - 1000px): 2 kolonner
      return GridView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.8,
          mainAxisExtent: 156,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final data = items[index];
          final id = data['id'] as String? ?? '';
          return _TournamentCard(
            id: id,
            data: data,
            isGrid: true,
          );
        },
      );
    } else {
      // Desktop (>= 1000px) & Ultrawide: responsiv grid med maxCrossAxisExtent (480px)
      return GridView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 480,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.8,
          mainAxisExtent: 156,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final data = items[index];
          final id = data['id'] as String? ?? '';
          return _TournamentCard(
            id: id,
            data: data,
            isGrid: true,
          );
        },
      );
    }
  }
}

class _TournamentCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final bool isGrid;

  const _TournamentCard({
    required this.id,
    required this.data,
    required this.isGrid,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? 'Ukjent';
    final location = data['location'] ?? 'Ukjent sted';
    final start = data['start_date'] ?? '?';
    final end = data['end_date'] ?? '?';
    final imageUrl = data['image_url'] ?? '';

    return Card(
      elevation: 2,
      margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TournamentControlPage(
                tournamentId: id,
                tournamentName: name,
              ),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              leading: CircleAvatar(
                radius: 24,
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
                        size: 14,
                        color: AppColors.adminTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: AppColors.adminTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
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
            Padding(
              padding: const EdgeInsets.only(
                right: 8,
                bottom: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TournamentControlPage(
                            tournamentId: id,
                            tournamentName: name,
                          ),
                        ),
                      );
                    },
                    child: const Text("Administrer"),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
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
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("Avbryt"),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: AppColors.adminText,
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("Slett"),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        try {
                          // Finn og slett alle relaterte dokumenter (matches, teams, categories)
                          final batch = FirebaseFirestore.instance.batch();
                          final matches = await FirebaseFirestore.instance.collection('matches').where('tournament_id', isEqualTo: id).get();
                          for (var doc in matches.docs) batch.delete(doc.reference);
                          final teams = await FirebaseFirestore.instance.collection('teams').where('tournament_id', isEqualTo: id).get();
                          for (var doc in teams.docs) batch.delete(doc.reference);
                          final categories = await FirebaseFirestore.instance.collection('categories').where('tournament_id', isEqualTo: id).get();
                          for (var doc in categories.docs) batch.delete(doc.reference);
                          
                          batch.delete(FirebaseFirestore.instance.collection('tournaments').doc(id));
                          await batch.commit();
                          
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
                    },
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
