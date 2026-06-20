import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // brukes i AdminDashboard
import 'firebase_options.dart';
import 'add_tournament_page.dart';
import 'tournament_control_page.dart';
import 'all_players_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_login_page.dart';
import 'player_claims_page.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
        return Container(
          color: AppColors.adminBg,
          child: child,
        );
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
              if (adminSnapshot.hasData && adminSnapshot.data!.exists) {
                return const AdminDashboard();
              }
              // Signed in but not an admin — sign out and show login
              FirebaseAuth.instance.signOut();
              return const AdminLoginPage();
            },
          );
        }
        return const AdminLoginPage();
      },
    );
  }
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: Colors.blue[800],
        foregroundColor: AppColors.adminText,
      ),
      
      // --- SIDEMENY (DRAWER) ---
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue[800]),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text("Spike Dunk Admin", style: TextStyle(color: AppColors.adminText, fontSize: 24, fontWeight: FontWeight.bold)),
                  Text("Kontrollpanel", style: TextStyle(color: AppColors.adminTextSecondary)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events),
              title: const Text('Turneringer'),
              onTap: () {
                Navigator.pop(context); // Vi er allerede her
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Spillerdatabase'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const AllPlayersPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1),
              title: const Text('Ventende Spillerkrav'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PlayerClaimsPage()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logg ut', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),

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

      // --- LISTE OVER TURNERINGER ---
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tournaments')
            .orderBy('created_at', descending: true) // Nyeste øverst
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.inbox, size: 64, color: AppColors.adminTextSecondary),
                  SizedBox(height: 16),
                  Text("Ingen turneringer enda. Trykk på knappen for å lage en!"),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          // Vi bruker en ListView som ser bra ut på PC-skjerm
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;
              
              final name = data['name'] ?? 'Ukjent';
              final location = data['location'] ?? 'Ukjent sted';
              final start = data['start_date'] ?? '?';
              final end = data['end_date'] ?? '?';
              final imageUrl = data['image_url'] ?? '';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.blue[100],
                    backgroundImage: imageUrl.isNotEmpty
                        ? NetworkImage(imageUrl)
                        : null,
                    child: imageUrl.isEmpty
                        ? const Icon(Icons.emoji_events, color: Colors.blue)
                        : null,
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.map, size: 16, color: AppColors.adminTextSecondary),
                          const SizedBox(width: 4),
                          
                          // --- FIKSEN ER HER ---
                          // Flexible gjør at teksten krymper hvis det er trangt
                          Flexible( 
                            child: Text(
                              location,
                              overflow: TextOverflow.ellipsis, // Legger til "..." hvis for lang
                              maxLines: 1, // Holder seg på én linje
                            ),
                          ),
                          
                          const SizedBox(width: 16),
                          
                          // Datoene kan også bli for lange på mobilskjermer
                          const Icon(Icons.calendar_today, size: 16, color: AppColors.adminTextSecondary),
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // NAVIGER TIL COCKPITEN
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TournamentControlPage(
                                tournamentId: id,     // Send ID-en videre
                                tournamentName: name, // Send navnet videre
                              ),
                            ),
                          );
                        },
                        child: const Text("Administrer"),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Slett turnering',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Slett turnering"),
                              content: Text("Er du sikker på at du vil slette '$name'?\n\nDette kan ikke angres!"),
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
                              await FirebaseFirestore.instance.collection('tournaments').doc(id).delete();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Turnering '$name' slettet.")),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Feil ved sletting: $e")),
                                );
                              }
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}