import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'match_control_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TournamentControlPage extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;

  const TournamentControlPage({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  State<TournamentControlPage> createState() => _TournamentControlPageState();
}

class _TournamentControlPageState extends State<TournamentControlPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- 1. QR DIALOG ---
  void _showQrDialog(String matchId, String teamA, String teamB) {
    // HUSK: Bytt til din ekte web-app link!
    String scorekeeperUrl = "https://spikedunk.web.app/?matchId=$matchId";
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Dommer QR-kode"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Scan for å styre kampen:\n$teamA vs $teamB", textAlign: TextAlign.center),
              const SizedBox(height: 20),
              SizedBox(
                height: 200, width: 200,
                child: QrImageView(data: scorekeeperUrl, version: QrVersions.auto, size: 200.0),
              ),
              const SizedBox(height: 20),
              SelectableText(scorekeeperUrl, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Lukk"))],
        );
      },
    );
  }

  // --- 2. NY LOGIKK: HENT BILDER OG LAGRE KAMP ---
// --- 2. NY LOGIKK: HENT BILDER OG LAGRE KAMP (MED ID) ---
  Future<void> _addMatchFromTeams(Map<String, dynamic> teamA, Map<String, dynamic> teamB) async {
    
    // Hjelpefunksjon for å hente bilde-URL
    Future<String?> getImageUrl(String? playerId) async {
      if (playerId == null) return null;
      try {
        final doc = await FirebaseFirestore.instance.collection('players').doc(playerId).get();
        if (doc.exists && doc.data() != null) {
          // Sjekk om feltet 'image_url' finnes, hvis ikke returner null
          final data = doc.data()!;
          if (data.containsKey('image_url')) {
             return data['image_url'] as String?;
          }
        }
      } catch (e) {
        print("Kunne ikke hente bilde for $playerId: $e");
      }
      return null;
    }

    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (c) => const Center(child: CircularProgressIndicator())
    );

    // Hent bilder
    final p1AImg = await getImageUrl(teamA['player1_id']);
    final p2AImg = await getImageUrl(teamA['player2_id']);
    final p1BImg = await getImageUrl(teamB['player1_id']);
    final p2BImg = await getImageUrl(teamB['player2_id']);

    // Lagre kampen med ID-er
    await FirebaseFirestore.instance.collection('matches').add({
      'tournament_id': widget.tournamentId,
      'status': 'scheduled',
      'court': 'Hovedbane',
      'timestamp': FieldValue.serverTimestamp(),
      'home_score': 0, 
      'away_score': 0,

      // Lag A info
      'team_a_name': teamA['team_name'],
      'team_a_id': teamA['id'],
      
      'team_a_p1_name': teamA['player1_name'],
      'team_a_p1_id': teamA['player1_id'],   // <--- NYTT: Lagrer ID
      'team_a_p1_img': p1AImg,
      
      'team_a_p2_name': teamA['player2_name'],
      'team_a_p2_id': teamA['player2_id'],   // <--- NYTT: Lagrer ID
      'team_a_p2_img': p2AImg,

      // Lag B info
      'team_b_name': teamB['team_name'],
      'team_b_id': teamB['id'],
      
      'team_b_p1_name': teamB['player1_name'],
      'team_b_p1_id': teamB['player1_id'],   // <--- NYTT: Lagrer ID
      'team_b_p1_img': p1BImg,
      
      'team_b_p2_name': teamB['player2_name'],
      'team_b_p2_id': teamB['player2_id'],   // <--- NYTT: Lagrer ID
      'team_b_p2_img': p2BImg,
    });

    if (mounted) {
      Navigator.pop(context); // Fjern lastesirkel
      Navigator.pop(context); // Fjern dialog
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kamp opprettet med ID-er!")));
    }
  }

  // --- NY FUNKSJON: BEKREFT SLETTING ---
  void _confirmDelete(String docId, String collection, String title) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Slett $title?"),
          content: const Text("Er du sikker? Dette kan ikke angres."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Lukk vindu (Nei)
              child: const Text("Avbryt"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                // Utfør slettingen
                FirebaseFirestore.instance.collection(collection).doc(docId).delete();
                Navigator.pop(context); // Lukk vindu
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Slettet!")));
              },
              child: const Text("Slett"),
            ),
          ],
        );
      },
    );
  }

  // --- 3. NY DIALOG: VELG LAG FRA LISTE ---
 // --- 3. NY DIALOG: VELG LAG FRA LISTE (FIKSET VERSJON) ---
  void _showAddMatchDialog() {
    // VIKTIG ENDRING: Vi lagrer kun ID-en til laget, ikke hele objektet
    String? selectedTeamAId;
    String? selectedTeamBId;

    showDialog(
      context: context,
      builder: (context) {
        // Vi bruker StatefulBuilder for å kunne oppdatere dropdowns inne i dialogen
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Opprett ny kamp"),
              content: SizedBox(
                width: double.maxFinite,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('teams')
                      .where('tournament_id', isEqualTo: widget.tournamentId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    
                    final teamDocs = snapshot.data!.docs;
                    if (teamDocs.isEmpty) return const Text("Ingen lag registrert enda. Gå til 'Lag'-fanen først.");

                    // Vi lager listen med Items, men verdien er nå doc.id (String)
                    final teamItems = teamDocs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem<String>(
                        value: doc.id, // <--- HER ER FIXEN: Vi bruker ID som verdi
                        child: Text(data['team_name'] ?? "Ukjent lag"),
                      );
                    }).toList();

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // --- VELG LAG A ---
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: "Hjemmelag (Lag A)", border: OutlineInputBorder()),
                          items: teamItems,
                          value: selectedTeamAId,
                          onChanged: (value) {
                            setState(() => selectedTeamAId = value);
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        // --- VELG LAG B ---
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: "Bortelag (Lag B)", border: OutlineInputBorder()),
                          items: teamItems,
                          value: selectedTeamBId,
                          onChanged: (value) {
                            setState(() => selectedTeamBId = value);
                          },
                        ),
                        
                        // Viser navnene for bekreftelse (valgfritt)
                        if (selectedTeamAId != null && selectedTeamBId != null)
                           const Padding(
                             padding: EdgeInsets.only(top: 10),
                             child: Text("Klar til å opprette...", style: TextStyle(color: Colors.green)),
                           ),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Avbryt")),
                ElevatedButton(
                  onPressed: () {
                    if (selectedTeamAId != null && selectedTeamBId != null) {
                      if (selectedTeamAId == selectedTeamBId) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Du kan ikke velge samme lag to ganger!")));
                        return;
                      }

                      // Nå må vi finne tilbake til selve lag-dataene basert på ID-en
                      // Dette gjør vi ved å slå opp i snapshotet vi allerede har tilgang til (via en ny spørring eller StreamBuilderen over).
                      // Men siden vi er utenfor StreamBuilderen her, gjør vi et lite triks:
                      
                      FirebaseFirestore.instance.collection('teams').doc(selectedTeamAId).get().then((docA) {
                        FirebaseFirestore.instance.collection('teams').doc(selectedTeamBId).get().then((docB) {
                          
                          if (docA.exists && docB.exists) {
                            // Vi må legge til ID manuelt i data-mappen siden .data() ikke inkluderer den
                            Map<String, dynamic> teamAData = docA.data()!;
                            teamAData['id'] = docA.id;
                            
                            Map<String, dynamic> teamBData = docB.data()!;
                            teamBData['id'] = docB.id;

                            // Start prosessen
                            _addMatchFromTeams(teamAData, teamBData);
                          }
                        });
                      });
                      
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("Opprett Kamp"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- 4. LEGG TIL LAG (Beholdt som den var) ---
  void _showAddTeamDialog() {
    final TextEditingController teamNameController = TextEditingController();
    String? selectedPlayer1Id;
    String? selectedPlayer1Name;
    String? selectedPlayer2Id;
    String? selectedPlayer2Name;

    showDialog(
      context: context,
      builder: (context) => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('players').orderBy('first_name').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final playerDocs = snapshot.data!.docs;
          if (playerDocs.isEmpty) return const AlertDialog(content: Text("Ingen spillere i databasen."));

          final playerItems = playerDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final fullName = "${data['first_name']} ${data['last_name']}";
            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text(fullName),
            );
          }).toList();

          return StatefulBuilder( // Lar oss oppdatere dropdowns internt i dialogen
            builder: (context, setState) {
              return AlertDialog(
                title: const Text("Registrer nytt lag"),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: teamNameController, decoration: const InputDecoration(labelText: "Lagnavn")),
                      const SizedBox(height: 15),
                      DropdownButtonFormField(
                        decoration: const InputDecoration(labelText: "Spiller 1"),
                        items: playerItems,
                        onChanged: (val) {
                          selectedPlayer1Id = val;
                          final p = playerDocs.firstWhere((d) => d.id == val).data() as Map<String, dynamic>;
                          selectedPlayer1Name = "${p['first_name']} ${p['last_name']}";
                        },
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField(
                        decoration: const InputDecoration(labelText: "Spiller 2"),
                        items: playerItems,
                        onChanged: (val) {
                          selectedPlayer2Id = val;
                          final p = playerDocs.firstWhere((d) => d.id == val).data() as Map<String, dynamic>;
                          selectedPlayer2Name = "${p['first_name']} ${p['last_name']}";
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Avbryt")),
                  ElevatedButton(
                    onPressed: () {
                      if (teamNameController.text.isNotEmpty && selectedPlayer1Id != null && selectedPlayer2Id != null) {
                        FirebaseFirestore.instance.collection('teams').add({
                          'team_name': teamNameController.text,
                          'tournament_id': widget.tournamentId,
                          'player1_id': selectedPlayer1Id,
                          'player1_name': selectedPlayer1Name,
                          'player2_id': selectedPlayer2Id,
                          'player2_name': selectedPlayer2Name,
                          'created_at': FieldValue.serverTimestamp(),
                        });
                        Navigator.pop(context);
                      }
                    },
                    child: const Text("Lagre Lag"),
                  ),
                ],
              );
            }
          );
        }
      ),
    );
  }

  // --- 5. UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin: ${widget.tournamentName}"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(icon: Icon(Icons.sports_volleyball), text: "Kamper"), Tab(icon: Icon(Icons.groups), text: "Lag")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMatchesTab(), _buildTeamsTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 1) {
            _showAddTeamDialog();
          } else {
            _showAddMatchDialog(); // Kjører den nye dropdown-logikken
          }
        },
        label: Text(_tabController.index == 1 ? "Nytt Lag" : "Ny Kamp"),
        icon: Icon(_tabController.index == 1 ? Icons.group_add : Icons.sports_score),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
    );
  }

  // --- 6. LISTEVISNINGER (Beholdt som før) ---
  Widget _buildTeamsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('teams').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final teams = snapshot.data!.docs;
        if (teams.isEmpty) return const Center(child: Text("Ingen lag registrert."));
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: teams.length,
          itemBuilder: (context, index) {
            final data = teams[index].data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.group),
                title: Text(data['team_name'] ?? 'Ukjent Lag'),
                subtitle: Text("${data['player1_name']} & ${data['player2_name']}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: "Slett lag",
                  // Her bruker vi den nye sikkerhetsfunksjonen
                  onPressed: () => _confirmDelete(teams[index].id, 'teams', "laget"),
             ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMatchesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('matches').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final matches = snapshot.data!.docs;
        if (matches.isEmpty) return const Center(child: Text("Ingen kamper satt opp enda."));
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final data = matches[index].data() as Map<String, dynamic>;
            final status = data['status'] ?? 'scheduled';
            
            return Card(
              child: ListTile(
                leading: const Icon(Icons.sports_volleyball),
                title: Text("${data['team_a_name']} vs ${data['team_b_name']}"),
                subtitle: Text("Status: $status"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // QR-KNAPP
                    IconButton(
                      icon: const Icon(Icons.qr_code), 
                      tooltip: "Vis QR",
                      onPressed: () => _showQrDialog(matches[index].id, data['team_a_name'] ?? 'Lag A', data['team_b_name'] ?? 'Lag B')
                    ),
                    
                    // KAMPSTYRING
                    IconButton(
                      icon: const Icon(Icons.sports_esports, color: Colors.green),
                      tooltip: "Styr kamp",
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MatchControlPage(matchId: matches[index].id, teamAName: data['team_a_name'] ?? 'Lag A', teamBName: data['team_b_name'] ?? 'Lag B'))),
                    ),

                    // SLETT-KNAPP (NY!)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: "Slett kamp",
                      onPressed: () => _confirmDelete(matches[index].id, 'matches', "kampen"),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}