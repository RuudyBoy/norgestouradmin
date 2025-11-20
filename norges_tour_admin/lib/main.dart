import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'add_tournament_page.dart';
import 'tournament_control_page.dart';
import 'all_players_page.dart';

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
      title: 'Norges Tour Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AdminDashboard(),
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
        foregroundColor: Colors.white,
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
                  Text("Norges Tour Admin", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  Text("Kontrollpanel", style: TextStyle(color: Colors.white70)),
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
                // VIKTIG ENDRING: Vi bruker pushReplacement for å bytte side helt
                // Da får vi ingen "tilbake"-pil på neste side
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const AllPlayersPage()),
                );
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
        foregroundColor: Colors.white,
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
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
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

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: const Icon(Icons.emoji_events, color: Colors.blue),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                     Row(
                        children: [
                          const Icon(Icons.map, size: 16, color: Colors.grey),
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
                          
                          // Datoene holder vi som de er (de er som regel korte nok)
                          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text("$start - $end"),
                        ],
                      ),
                    ],
                  ),
                  trailing: ElevatedButton(
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}