import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'match_control_page.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'simulator_logic.dart';

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
    _tabController = TabController(length: 4, vsync: this);
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
  void _showEditPlacementDialog(String teamId, String teamName, int? currentPlacement) {
    final TextEditingController placementController = TextEditingController(text: currentPlacement?.toString() ?? '');
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Endre plassering for $teamName"),
          content: TextField(
            controller: placementController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Plassering (1-4)",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Avbryt")),
            ElevatedButton(
              onPressed: () {
                int? newPlacement = int.tryParse(placementController.text);
                FirebaseFirestore.instance.collection('teams').doc(teamId).update({
                  'group_placement': newPlacement,
                });
                Navigator.pop(context);
              },
              child: const Text("Lagre"),
            ),
          ],
        );
      },
    );
  }

  void _showEditSeedDialog(String teamId, String teamName, int? currentSeed) {
    final TextEditingController seedController = TextEditingController(text: currentSeed?.toString() ?? '');
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Endre seeding for $teamName"),
          content: TextField(
            controller: seedController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Seeding (1-16)",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Avbryt")),
            ElevatedButton(
              onPressed: () {
                int? newSeed = int.tryParse(seedController.text);
                FirebaseFirestore.instance.collection('teams').doc(teamId).update({
                  'seed': newSeed,
                });
                Navigator.pop(context);
              },
              child: const Text("Lagre"),
            ),
          ],
        );
      },
    );
  }

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
        debugPrint("Kunne ikke hente bilde for $playerId: $e");
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
      'home_sets': 0,
      'away_sets': 0,
      'current_set': 1,
      'past_sets': [],

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

    // Hent streamen utenfor builder for å unngå at den gjenskapes ved hver setState
    final teamsStream = FirebaseFirestore.instance
        .collection('teams')
        .where('tournament_id', isEqualTo: widget.tournamentId)
        .snapshots();

    showDialog(
      context: context,
      builder: (context) {
        return StreamBuilder<QuerySnapshot>(
          stream: teamsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) return AlertDialog(content: Text("Feil: ${snapshot.error}"));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final teamDocs = snapshot.data!.docs;
            if (teamDocs.isEmpty) return const AlertDialog(content: Text("Ingen lag registrert enda. Gå til 'Lag'-fanen først."));

            final teamItems = teamDocs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return DropdownMenuItem<String>(
                value: doc.id,
                child: Text(data['team_name'] ?? "Ukjent lag"),
              );
            }).toList();

            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text("Opprett ny kamp"),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // --- VELG LAG A ---
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: "Hjemmelag (Lag A)", border: OutlineInputBorder()),
                          items: teamItems,
                          initialValue: selectedTeamAId,
                          onChanged: (value) {
                            setState(() => selectedTeamAId = value);
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        // --- VELG LAG B ---
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: "Bortelag (Lag B)", border: OutlineInputBorder()),
                          items: teamItems,
                          initialValue: selectedTeamBId,
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

                          // Lukk dialogen først for å unngå at en spinner henger igjen eller pop fjerner siden
                          Navigator.pop(context);

                          FirebaseFirestore.instance.collection('teams').doc(selectedTeamAId).get().then((docA) {
                            FirebaseFirestore.instance.collection('teams').doc(selectedTeamBId).get().then((docB) {
                              if (docA.exists && docB.exists) {
                                Map<String, dynamic> teamAData = docA.data()!;
                                teamAData['id'] = docA.id;
                                
                                Map<String, dynamic> teamBData = docB.data()!;
                                teamBData['id'] = docB.id;

                                // Start prosessen
                                _addMatchFromTeams(teamAData, teamBData);
                              }
                            });
                          });
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
      },
    );
  }

  // --- 4. LEGG TIL LAG (Beholdt som den var) ---
  void _showAddTeamDialog() {
    String? selectedPlayer1Id;
    String? selectedPlayer2Id;
    String? selectedPlayer1Name;
    String? selectedPlayer2Name;
    String? selectedPlayer1Short;
    String? selectedPlayer2Short;

    String getShortName(String firstName, String lastName) {
      String firstInitial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
      return '$firstInitial.$lastName';
    }

    final playersStream = FirebaseFirestore.instance.collection('players').orderBy('first_name').snapshots();

    showDialog(
      context: context,
      builder: (context) => StreamBuilder<QuerySnapshot>(
        stream: playersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return AlertDialog(content: Text("Feil: ${snapshot.error}"), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Lukk"))]);
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              content: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
            );
          }

          final playerDocs = snapshot.data?.docs ?? [];
          if (playerDocs.isEmpty) return AlertDialog(content: const Text("Ingen spillere i databasen."), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Lukk"))]);

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
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: "Spiller 1"),
                        items: playerItems,
                        initialValue: selectedPlayer1Id,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              selectedPlayer1Id = val;
                              final p = playerDocs.firstWhere((d) => d.id == val).data() as Map<String, dynamic>;
                              selectedPlayer1Name = "${p['first_name']} ${p['last_name']}";
                              selectedPlayer1Short = getShortName(p['first_name'] ?? '', p['last_name'] ?? '');
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: "Spiller 2"),
                        items: playerItems,
                        initialValue: selectedPlayer2Id,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              selectedPlayer2Id = val;
                              final p = playerDocs.firstWhere((d) => d.id == val).data() as Map<String, dynamic>;
                              selectedPlayer2Name = "${p['first_name']} ${p['last_name']}";
                              selectedPlayer2Short = getShortName(p['first_name'] ?? '', p['last_name'] ?? '');
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Avbryt")),
                  ElevatedButton(
                    onPressed: () {
                      if (selectedPlayer1Id != null && selectedPlayer2Id != null) {
                        if (selectedPlayer1Id == selectedPlayer2Id) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("En spiller kan ikke være på samme lag to ganger!")));
                          return;
                        }
                        
                        // Capture messenger before closing the dialog so we can
                        // use it after the dialog context is deactivated.
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);

                        String teamName = "$selectedPlayer1Short/$selectedPlayer2Short";
                        
                        // Hent poeng for begge spillere
                        final p1Data = playerDocs.firstWhere((d) => d.id == selectedPlayer1Id).data() as Map<String, dynamic>;
                        final p2Data = playerDocs.firstWhere((d) => d.id == selectedPlayer2Id).data() as Map<String, dynamic>;
                        
                        int p1Points = p1Data['ranking_points'] is int ? p1Data['ranking_points'] as int : int.tryParse(p1Data['ranking_points']?.toString() ?? '0') ?? 0;
                        int p2Points = p2Data['ranking_points'] is int ? p2Data['ranking_points'] as int : int.tryParse(p2Data['ranking_points']?.toString() ?? '0') ?? 0;
                        int teamPoints = p1Points + p2Points;

                        FirebaseFirestore.instance.collection('teams').add({
                          'team_name': teamName,
                          'tournament_id': widget.tournamentId,
                          'player1_id': selectedPlayer1Id,
                          'player1_name': selectedPlayer1Name,
                          'player2_id': selectedPlayer2Id,
                          'player2_name': selectedPlayer2Name,
                          'team_points': teamPoints,
                          'created_at': FieldValue.serverTimestamp(),
                        }).then((_) {
                          if (mounted) {
                            messenger.showSnackBar(const SnackBar(content: Text("Lag lagt til!")));
                          }
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Velg begge spillere!")));
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
          tabs: const [
            Tab(icon: Icon(Icons.sports_volleyball), text: "Kamper"), 
            Tab(icon: Icon(Icons.groups), text: "Lag"),
            Tab(icon: Icon(Icons.format_list_numbered), text: "Grupper"),
            Tab(icon: Icon(Icons.emoji_events), text: "Sluttspill")
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMatchesTab(), _buildTeamsTab(), _buildGroupsTab(), _buildPlayoffsTab()],
      ),
      floatingActionButton: _tabController.index > 1 ? null : FloatingActionButton.extended(
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.group_work),
            label: const Text("Auto-generer 16 lag (fra database)"),
            onPressed: () async {
              final scaffold = ScaffoldMessenger.of(context);
              final playersSnap = await FirebaseFirestore.instance.collection('players').get();
              final players = playersSnap.docs.toList();
              
              if (players.length < 32) {
                if (mounted) scaffold.showSnackBar(SnackBar(content: Text("Trenger minst 32 spillere i databasen for å lage 16 lag (har ${players.length})")));
                return;
              }
              
              players.shuffle();
              WriteBatch batch = FirebaseFirestore.instance.batch();
              
              for (int i = 0; i < 16; i++) {
                final p1 = players[i * 2];
                final p2 = players[i * 2 + 1];
                
                final p1Data = p1.data();
                final p2Data = p2.data();
                
                final p1Points = (p1Data['ranking_points'] as num?)?.toInt() ?? 0;
                final p2Points = (p2Data['ranking_points'] as num?)?.toInt() ?? 0;
                
                final p1Name = "${p1Data['first_name']} ${p1Data['last_name']}".trim();
                final p2Name = "${p2Data['first_name']} ${p2Data['last_name']}".trim();
                
                final p1Short = p1Data['last_name'] ?? p1Data['first_name'] ?? 'Ukjent';
                final p2Short = p2Data['last_name'] ?? p2Data['first_name'] ?? 'Ukjent';
                
                final docRef = FirebaseFirestore.instance.collection('teams').doc();
                batch.set(docRef, {
                  'team_name': "$p1Short/$p2Short",
                  'tournament_id': widget.tournamentId,
                  'player1_id': p1.id,
                  'player1_name': p1Name,
                  'player2_id': p2.id,
                  'player2_name': p2Name,
                  'team_points': p1Points + p2Points,
                  'created_at': FieldValue.serverTimestamp(),
                });
              }
              
              await batch.commit();
              if (mounted) scaffold.showSnackBar(const SnackBar(content: Text("16 lag ble generert!")));
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('teams').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("Feil: ${snapshot.error}"));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final teams = snapshot.data?.docs ?? [];
              if (teams.isEmpty) return const Center(child: Text("Ingen lag registrert."));
              
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: teams.length,
                itemBuilder: (context, index) {
            final data = teams[index].data() as Map<String, dynamic>;
            final seed = data.containsKey('seed') ? data['seed'] : null;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Text(seed?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                title: Text(data['team_name'] ?? 'Ukjent Lag'),
                subtitle: Text("${data['player1_name']} & ${data['player2_name']}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: "Endre seeding",
                      onPressed: () => _showEditSeedDialog(teams[index].id, data['team_name'] ?? 'Ukjent Lag', seed),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: "Slett lag",
                      // Her bruker vi den nye sikkerhetsfunksjonen
                      onPressed: () => _confirmDelete(teams[index].id, 'teams', "laget"),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
    ),
    ],
    );
  }

  Widget _buildMatchesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.auto_awesome),
            label: const Text("Simuler alle oppsatte kamper (Test)"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[800],
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // Viser en snackbar som oppdaterer seg
              final snackBar = ScaffoldMessenger.of(context);
              snackBar.showSnackBar(const SnackBar(content: Text("Starter simulering..."), duration: Duration(days: 1)));
              
              await MatchSimulator.simulateScheduledMatches(widget.tournamentId, (progress) {
                 // Her kunne vi brukt en StreamBuilder, men vi lar den være enkel.
              });
              
              snackBar.hideCurrentSnackBar();
              snackBar.showSnackBar(const SnackBar(content: Text("Simulering fullført!")));
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('matches').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Feil: ${snapshot.error}"));
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
    ),
    ), // Lukk Expanded
    ],
    ); // Lukk Column
  }

  // --- GRUPPESPILL UI OG LOGIKK ---
  Widget _buildGroupsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.shuffle),
                label: const Text("Generer Grupper (16 lag)"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], foregroundColor: Colors.white),
                onPressed: _generateGroupStage,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text("Generer Runde 2"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
                onPressed: _generateGroupRound2,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('teams')
              .where('tournament_id', isEqualTo: widget.tournamentId)
              .where('group', isNull: false)
              .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("Feil: ${snapshot.error}"));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final teams = snapshot.data!.docs;
              if (teams.isEmpty) return const Center(child: Text("Ingen grupper generert enda."));
              
              // Map lag til grupper
              Map<String, List<DocumentSnapshot>> groups = {'A': [], 'B': [], 'C': [], 'D': []};
              for (var t in teams) {
                final data = t.data() as Map<String, dynamic>;
                final g = data.containsKey('group') ? data['group'] as String? : null;
                if (g != null && groups.containsKey(g)) groups[g]!.add(t);
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: groups.keys.map((g) {
                  final groupTeams = groups[g]!;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          color: Colors.blue[100],
                          child: Text("Gruppe $g", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                        ...groupTeams.map((t) {
                          final data = t.data() as Map<String, dynamic>;
                          final placement = data.containsKey('group_placement') ? data['group_placement'] : null;
                          return ListTile(
                            leading: CircleAvatar(child: Text(placement?.toString() ?? '-')),
                            title: Text(data['team_name'] ?? 'Ukjent Lag'),
                            subtitle: Text("${data['player1_name']} & ${data['player2_name']}"),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: "Overstyr plassering",
                              onPressed: () => _showEditPlacementDialog(t.id, data['team_name'] ?? 'Ukjent Lag', placement),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _generateGroupStage() async {
    final snapshot = await FirebaseFirestore.instance.collection('teams').where('tournament_id', isEqualTo: widget.tournamentId).get();
    final teams = snapshot.docs;
    
    if (teams.length < 16) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Trenger minst 16 lag (har ${teams.length}) for å generere gruppespill.")));
      return;
    }

    // Sorter etter team_points (høyeste poengsum får seed 1, osv)
    final sortedTeams = teams.toList();
    sortedTeams.sort((a, b) {
      final aData = a.data();
      final bData = b.data();
      final aPoints = aData.containsKey('team_points') ? (aData['team_points'] as int?) ?? 0 : 0;
      final bPoints = bData.containsKey('team_points') ? (bData['team_points'] as int?) ?? 0 : 0;
      // Sorterer synkende (høyest først)
      return bPoints.compareTo(aPoints);
    });

    final selectedTeams = sortedTeams.take(16).toList();

    // Snake seeding distribusjon for 4 grupper:
    // A: 1, 8, 9, 16
    // B: 2, 7, 10, 15
    // C: 3, 6, 11, 14
    // D: 4, 5, 12, 13
    
    final groupA = [selectedTeams[0], selectedTeams[7], selectedTeams[8], selectedTeams[15]];
    final groupB = [selectedTeams[1], selectedTeams[6], selectedTeams[9], selectedTeams[14]];
    final groupC = [selectedTeams[2], selectedTeams[5], selectedTeams[10], selectedTeams[13]];
    final groupD = [selectedTeams[3], selectedTeams[4], selectedTeams[11], selectedTeams[12]];

    final groupsMap = {
      'A': groupA,
      'B': groupB,
      'C': groupC,
      'D': groupD,
    };
    
    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (String group in groupsMap.keys) {
      final groupTeams = groupsMap[group]!;
      
      for (int i = 0; i < groupTeams.length; i++) {
        var teamDoc = groupTeams[i];
        // Finn lagets faktiske seed (index i selectedTeams + 1)
        int actualSeed = selectedTeams.indexOf(teamDoc) + 1;
        batch.update(teamDoc.reference, {
          'group': group, 
          'group_placement': FieldValue.delete(),
          'seed': actualSeed,
        });
      }

      // Første kamp: Høyeste seed mot laveste seed i gruppa (index 0 vs index 3)
      final match1Ref = FirebaseFirestore.instance.collection('matches').doc();
      batch.set(match1Ref, _createGroupMatchData(group, 'group_semi_1', groupTeams[0], groupTeams[3]));

      // Andre kamp: De to midterste i gruppa (index 1 vs index 2)
      final match2Ref = FirebaseFirestore.instance.collection('matches').doc();
      batch.set(match2Ref, _createGroupMatchData(group, 'group_semi_2', groupTeams[1], groupTeams[2]));
    }

    await batch.commit();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gruppespill generert med seeding!")));
  }

  Future<void> _generateGroupRound2() async {
    final matchesSnap = await FirebaseFirestore.instance.collection('matches')
      .where('tournament_id', isEqualTo: widget.tournamentId)
      .where('status', isEqualTo: 'finished')
      .get();
      
    final allFinished = matchesSnap.docs;
    
    final groups = ['A', 'B', 'C', 'D'];
    WriteBatch batch = FirebaseFirestore.instance.batch();
    int addedMatches = 0;

    for (String g in groups) {
      final m1List = allFinished.where((m) => (m.data() as Map)['group'] == g && (m.data() as Map)['match_type'] == 'group_semi_1').toList();
      final m2List = allFinished.where((m) => (m.data() as Map)['group'] == g && (m.data() as Map)['match_type'] == 'group_semi_2').toList();
      
      final existingFinalsSnap = await FirebaseFirestore.instance.collection('matches')
        .where('tournament_id', isEqualTo: widget.tournamentId)
        .where('group', isEqualTo: g)
        .where('match_type', isEqualTo: 'group_final')
        .get();
        
      if (existingFinalsSnap.docs.isNotEmpty) continue;
      
      if (m1List.isNotEmpty && m2List.isNotEmpty) {
        final m1 = m1List.first.data();
        final m2 = m2List.first.data();
        
        final m1HomeScore = m1['home_score'] ?? 0;
        final m1AwayScore = m1['away_score'] ?? 0;
        final m1WinnerTeamId = m1HomeScore > m1AwayScore ? m1['team_a_id'] : m1['team_b_id'];
        final m1LoserTeamId = m1HomeScore > m1AwayScore ? m1['team_b_id'] : m1['team_a_id'];

        final m2HomeScore = m2['home_score'] ?? 0;
        final m2AwayScore = m2['away_score'] ?? 0;
        final m2WinnerTeamId = m2HomeScore > m2AwayScore ? m2['team_a_id'] : m2['team_b_id'];
        final m2LoserTeamId = m2HomeScore > m2AwayScore ? m2['team_b_id'] : m2['team_a_id'];

        final m1WinDoc = await FirebaseFirestore.instance.collection('teams').doc(m1WinnerTeamId).get();
        final m2WinDoc = await FirebaseFirestore.instance.collection('teams').doc(m2WinnerTeamId).get();
        final m1LoseDoc = await FirebaseFirestore.instance.collection('teams').doc(m1LoserTeamId).get();
        final m2LoseDoc = await FirebaseFirestore.instance.collection('teams').doc(m2LoserTeamId).get();
        
        final finalRef = FirebaseFirestore.instance.collection('matches').doc();
        batch.set(finalRef, _createGroupMatchData(g, 'group_final', m1WinDoc, m2WinDoc));
        
        final bronzeRef = FirebaseFirestore.instance.collection('matches').doc();
        batch.set(bronzeRef, _createGroupMatchData(g, 'group_bronze', m1LoseDoc, m2LoseDoc));
        
        addedMatches += 2;
      }
    }
    
    if (addedMatches > 0) {
      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Genererte $addedMatches kamper i Runde 2!")));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ingen nye kamper kunne genereres. Vent på resultater.")));
    }
  }

  Map<String, dynamic> _createGroupMatchData(String group, String matchType, DocumentSnapshot teamA, DocumentSnapshot teamB, {String round = 'Gruppespill'}) {
    final tA = teamA.data() as Map<String, dynamic>? ?? {};
    final tB = teamB.data() as Map<String, dynamic>? ?? {};
    
    return {
      'tournament_id': widget.tournamentId,
      'status': 'scheduled',
      'court': 'TBD',
      'timestamp': FieldValue.serverTimestamp(),
      'home_score': 0, 
      'away_score': 0,
      'home_sets': 0,
      'away_sets': 0,
      'current_set': 1,
      'past_sets': [],
      'match_type': matchType,
      'group': group,
      'round': round,

      'team_a_name': tA['team_name'] ?? 'Ukjent',
      'team_a_id': teamA.id,
      'team_a_p1_name': tA['player1_name'] ?? '',
      'team_a_p1_id': tA['player1_id'] ?? '',
      'team_a_p2_name': tA['player2_name'] ?? '',
      'team_a_p2_id': tA['player2_id'] ?? '',

      'team_b_name': tB['team_name'] ?? 'Ukjent',
      'team_b_id': teamB.id,
      'team_b_p1_name': tB['player1_name'] ?? '',
      'team_b_p1_id': tB['player1_id'] ?? '',
      'team_b_p2_name': tB['player2_name'] ?? '',
      'team_b_p2_id': tB['player2_id'] ?? '',
    };
  }

  // --- SLUTTSPILL UI OG LOGIKK ---
  Widget _buildPlayoffsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.emoji_events),
                label: const Text("Generer Sluttspill"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[800], foregroundColor: Colors.white),
                onPressed: _generatePlayoffs,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.update),
                label: const Text("Oppdater Bracket"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
                onPressed: _updatePlayoffBracket,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('matches')
              .where('tournament_id', isEqualTo: widget.tournamentId)
              .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("Feil: ${snapshot.error}"));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final matches = snapshot.data!.docs.where((m) {
                final type = (m.data() as Map<String, dynamic>)['match_type'] as String?;
                return type != null && type.contains('playoff');
              }).toList();
              if (matches.isEmpty) return const Center(child: Text("Sluttspill er ikke generert."));
              
              // Sorter etter match_type og deretter group (f.eks M1, M2)
              matches.sort((a, b) {
                 final aData = a.data() as Map;
                 final bData = b.data() as Map;
                 int typeCmp = (aData['match_type'] as String).compareTo(bData['match_type'] as String);
                 if (typeCmp != 0) return typeCmp;
                 
                 // Extract number from group name (e.g. "M1" -> 1)
                 int numA = int.tryParse((aData['group'] as String).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                 int numB = int.tryParse((bData['group'] as String).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                 return numA.compareTo(numB);
              });

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final data = matches[index].data() as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      title: Text("${data['group']}: ${data['team_a_name']} vs ${data['team_b_name']}"),
                      subtitle: Text("Type: ${data['match_type']} | Status: ${data['status']}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.qr_code), 
                            onPressed: () => _showQrDialog(matches[index].id, data['team_a_name'] ?? 'Lag A', data['team_b_name'] ?? 'Lag B')
                          ),
                          IconButton(
                            icon: const Icon(Icons.sports_esports, color: Colors.green),
                            onPressed: () {
                               if (data['team_a_id'] == 'placeholder' || data['team_b_id'] == 'placeholder') {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kan ikke styre kamp før begge lag er klare.")));
                                  return;
                               }
                               Navigator.push(context, MaterialPageRoute(builder: (context) => MatchControlPage(matchId: matches[index].id, teamAName: data['team_a_name'], teamBName: data['team_b_name'])));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(matches[index].id, 'matches', "sluttspillkampen"),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _finalizeGroupPlacements() async {
    final matchesSnap = await FirebaseFirestore.instance.collection('matches')
      .where('tournament_id', isEqualTo: widget.tournamentId)
      .where('status', isEqualTo: 'finished')
      .get();
      
    final allFinished = matchesSnap.docs;
    WriteBatch batch = FirebaseFirestore.instance.batch();
    int updatedTeams = 0;

    final groups = ['A', 'B', 'C', 'D'];
    for (String g in groups) {
      final gFinals = allFinished.where((m) => (m.data() as Map)['group'] == g && (m.data() as Map)['match_type'] == 'group_final').toList();
      final gBronzes = allFinished.where((m) => (m.data() as Map)['group'] == g && (m.data() as Map)['match_type'] == 'group_bronze').toList();
      
      if (gFinals.isNotEmpty) {
        final m = gFinals.first.data();
        final mHomeScore = m['home_score'] ?? 0;
        final mAwayScore = m['away_score'] ?? 0;
        final mWinnerTeamId = mHomeScore > mAwayScore ? m['team_a_id'] : m['team_b_id'];
        final mLoserTeamId = mHomeScore > mAwayScore ? m['team_b_id'] : m['team_a_id'];
        
        batch.update(FirebaseFirestore.instance.collection('teams').doc(mWinnerTeamId), {'group_placement': 1});
        batch.update(FirebaseFirestore.instance.collection('teams').doc(mLoserTeamId), {'group_placement': 2});
        updatedTeams += 2;
      }
      
      if (gBronzes.isNotEmpty) {
        final m = gBronzes.first.data();
        final mHomeScore = m['home_score'] ?? 0;
        final mAwayScore = m['away_score'] ?? 0;
        final mWinnerTeamId = mHomeScore > mAwayScore ? m['team_a_id'] : m['team_b_id'];
        final mLoserTeamId = mHomeScore > mAwayScore ? m['team_b_id'] : m['team_a_id'];
        
        batch.update(FirebaseFirestore.instance.collection('teams').doc(mWinnerTeamId), {'group_placement': 3});
        batch.update(FirebaseFirestore.instance.collection('teams').doc(mLoserTeamId), {'group_placement': 4});
        updatedTeams += 2;
      }
    }
    
    if (updatedTeams > 0) {
      await batch.commit();
    }
  }

  Future<void> _generatePlayoffs() async {
    try {
      await _finalizeGroupPlacements();
      
      final teamsSnap = await FirebaseFirestore.instance.collection('teams')
        .where('tournament_id', isEqualTo: widget.tournamentId)
        .where('group_placement', isNull: false)
        .get();
        
      final teams = teamsSnap.docs;
      if (teams.length < 16) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Trenger alle 16 lag ferdigspilt i grupper for å generere sluttspill.")));
        return;
      }

    
    DocumentSnapshot? getTeam(String group, int placement) {
      try {
        return teams.firstWhere((t) => (t.data() as Map)['group'] == group && (t.data() as Map)['group_placement'] == placement);
      } catch (e) {
        return null;
      }
    }

    final c3 = getTeam('C', 3); final d4 = getTeam('D', 4);
    final a3 = getTeam('A', 3); final b4 = getTeam('B', 4);
    final b3 = getTeam('B', 3); final a4 = getTeam('A', 4);
    final d3 = getTeam('D', 3); final c4 = getTeam('C', 4);
    
    final a1 = getTeam('A', 1); final b2 = getTeam('B', 2);
    final d1 = getTeam('D', 1); final c2 = getTeam('C', 2);
    final c1 = getTeam('C', 1); final d2 = getTeam('D', 2);
    final b1 = getTeam('B', 1); final a2 = getTeam('A', 2);

    if (c3 == null || d4 == null || a3 == null || b4 == null || 
        b3 == null || a4 == null || d3 == null || c4 == null ||
        a1 == null || b2 == null || d1 == null || c2 == null || 
        c1 == null || d2 == null || b1 == null || a2 == null) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mangler noen lagplasseringer. Er alle gruppekamper ferdig?")));
       return;
    }

    WriteBatch batch = FirebaseFirestore.instance.batch();
    
    final m1Ref = FirebaseFirestore.instance.collection('matches').doc();
    batch.set(m1Ref, _createPlayoffMatchData('1_playoff_r1', 'M1', c3, d4));
    
    final m2Ref = FirebaseFirestore.instance.collection('matches').doc();
    batch.set(m2Ref, _createPlayoffMatchData('1_playoff_r1', 'M2', a3, b4));

    final m3Ref = FirebaseFirestore.instance.collection('matches').doc();
    batch.set(m3Ref, _createPlayoffMatchData('1_playoff_r1', 'M3', b3, a4));

    final m4Ref = FirebaseFirestore.instance.collection('matches').doc();
    batch.set(m4Ref, _createPlayoffMatchData('1_playoff_r1', 'M4', d3, c4));
    
    final m5Ref = FirebaseFirestore.instance.collection('matches').doc();
    batch.set(m5Ref, _createPlayoffMatchDataWithPlaceholder('2_playoff_r2', 'M5', b2, 'Vinner M1', m1Ref.id));

    final m6Ref = FirebaseFirestore.instance.collection('matches').doc();
    batch.set(m6Ref, _createPlayoffMatchDataWithPlaceholder('2_playoff_r2', 'M6', c2, 'Vinner M2', m2Ref.id));

    final m7Ref = FirebaseFirestore.instance.collection('matches').doc();
    batch.set(m7Ref, _createPlayoffMatchDataWithPlaceholder('2_playoff_r2', 'M7', d2, 'Vinner M3', m3Ref.id));

    final m8Ref = FirebaseFirestore.instance.collection('matches').doc();
    batch.set(m8Ref, _createPlayoffMatchDataWithPlaceholder('2_playoff_r2', 'M8', a2, 'Vinner M4', m4Ref.id));

    final m9Ref = FirebaseFirestore.instance.collection('matches').doc();
    batch.set(m9Ref, _createPlayoffMatchDataWithPlaceholder('3_playoff_r3', 'M9', a1, 'Vinner M5', m5Ref.id));

    final m10Ref = FirebaseFirestore.instance.collection('matches').doc();
    batch.set(m10Ref, _createPlayoffMatchDataWithPlaceholder('3_playoff_r3', 'M10', d1, 'Vinner M6', m6Ref.id));

    final m11Ref = FirebaseFirestore.instance.collection('matches').doc();
    batch.set(m11Ref, _createPlayoffMatchDataWithPlaceholder('3_playoff_r3', 'M11', c1, 'Vinner M7', m7Ref.id));

    final m12Ref = FirebaseFirestore.instance.collection('matches').doc();
    batch.set(m12Ref, _createPlayoffMatchDataWithPlaceholder('3_playoff_r3', 'M12', b1, 'Vinner M8', m8Ref.id));

    final m13Ref = FirebaseFirestore.instance.collection('matches').doc();
    batch.set(m13Ref, _createPlayoffMatchDataDoublePlaceholder('4_playoff_r4', 'M13', 'Vinner M9', m9Ref.id, 'Vinner M10', m10Ref.id));

    final m14Ref = FirebaseFirestore.instance.collection('matches').doc();
    batch.set(m14Ref, _createPlayoffMatchDataDoublePlaceholder('4_playoff_r4', 'M14', 'Vinner M11', m11Ref.id, 'Vinner M12', m12Ref.id));

    final m15Ref = FirebaseFirestore.instance.collection('matches').doc();
    batch.set(m15Ref, _createPlayoffMatchDataDoublePlaceholder('5_playoff_final', 'Finale', 'Vinner M13', m13Ref.id, 'Vinner M14', m14Ref.id));
    
    final m16Ref = FirebaseFirestore.instance.collection('matches').doc();
    batch.set(m16Ref, _createPlayoffMatchDataDoublePlaceholder('5_playoff_bronze', 'Bronsefinale', 'Taper M13', m13Ref.id, 'Taper M14', m14Ref.id));

    await batch.commit();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sluttspill opprettet!")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Feil: $e (Sjekk kjørekonsollen for evt. index-lenker)"),
        duration: const Duration(seconds: 10),
      ));
      print("Error in _generatePlayoffs: $e");
    }
  }

  Future<void> _updatePlayoffBracket() async {
    final matchesSnap = await FirebaseFirestore.instance.collection('matches')
      .where('tournament_id', isEqualTo: widget.tournamentId)
      .where('round', isEqualTo: 'Sluttspill')
      .get();
      
    final matches = matchesSnap.docs;
    WriteBatch batch = FirebaseFirestore.instance.batch();
    int updates = 0;

    for (var m in matches) {
      final data = m.data();
      Map<String, dynamic> docUpdates = {};
      
      if (data['team_a_id'] == 'placeholder' && data['dependent_on_a'] != null) {
        final depId = data['dependent_on_a'];
        final depA = matches.firstWhere((x) => x.id == depId, orElse: () => m);
        if (depA.id != m.id && (depA.data())['status'] == 'finished') {
           final depData = depA.data();
           final hScore = depData['home_score'] ?? 0;
           final aScore = depData['away_score'] ?? 0;
           final winId = hScore > aScore ? depData['team_a_id'] : depData['team_b_id'];
           final loseId = hScore > aScore ? depData['team_b_id'] : depData['team_a_id'];
           
           final targetId = data['match_type'] == '5_playoff_bronze' ? loseId : winId;

           final tDoc = await FirebaseFirestore.instance.collection('teams').doc(targetId).get();
           final tData = tDoc.data()!;
           
           docUpdates.addAll({
             'team_a_id': targetId,
             'team_a_name': tData['team_name'],
             'team_a_p1_id': tData['player1_id'],
             'team_a_p1_name': tData['player1_name'],
             'team_a_p2_id': tData['player2_id'],
             'team_a_p2_name': tData['player2_name'],
           });
        }
      }

      if (data['team_b_id'] == 'placeholder' && data['dependent_on_b'] != null) {
        final depId = data['dependent_on_b'];
        final depB = matches.firstWhere((x) => x.id == depId, orElse: () => m);
        if (depB.id != m.id && (depB.data() as Map)['status'] == 'finished') {
           final depData = depB.data() as Map;
           final hScore = depData['home_score'] ?? 0;
           final aScore = depData['away_score'] ?? 0;
           final winId = hScore > aScore ? depData['team_a_id'] : depData['team_b_id'];
           final loseId = hScore > aScore ? depData['team_b_id'] : depData['team_a_id'];
           
           final targetId = data['match_type'] == '5_playoff_bronze' ? loseId : winId;

           final tDoc = await FirebaseFirestore.instance.collection('teams').doc(targetId).get();
           final tData = tDoc.data()!;
           
           docUpdates.addAll({
             'team_b_id': targetId,
             'team_b_name': tData['team_name'],
             'team_b_p1_id': tData['player1_id'],
             'team_b_p1_name': tData['player1_name'],
             'team_b_p2_id': tData['player2_id'],
             'team_b_p2_name': tData['player2_name'],
           });
        }
      }
      
      if (docUpdates.isNotEmpty) {
        batch.update(m.reference, docUpdates);
        updates++;
      }
    }

    if (updates > 0) {
      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Oppdaterte $updates lag i sluttspillet!")));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ingen nye lag kunne flyttes videre. Mangler ferdige kamper.")));
    }
  }

  Map<String, dynamic> _createPlayoffMatchData(String matchType, String matchName, DocumentSnapshot teamA, DocumentSnapshot teamB) {
    return _createGroupMatchData(matchName, matchType, teamA, teamB, round: 'Sluttspill');
  }

  Map<String, dynamic> _createPlayoffMatchDataWithPlaceholder(String matchType, String matchName, DocumentSnapshot teamA, String placeholderName, String depId) {
    final tA = teamA.data() as Map<String, dynamic>;
    return {
      'tournament_id': widget.tournamentId,
      'status': 'scheduled',
      'court': 'TBD',
      'timestamp': FieldValue.serverTimestamp(),
      'home_score': 0, 'away_score': 0,
      'home_sets': 0, 'away_sets': 0,
      'current_set': 1, 'past_sets': [],
      'match_type': matchType, 'group': matchName, 'round': 'Sluttspill',
      
      'team_a_name': tA['team_name'], 'team_a_id': teamA.id,
      'team_a_p1_name': tA['player1_name'], 'team_a_p1_id': tA['player1_id'],
      'team_a_p2_name': tA['player2_name'], 'team_a_p2_id': tA['player2_id'],

      'team_b_name': placeholderName, 'team_b_id': 'placeholder',
      'team_b_p1_name': '', 'team_b_p1_id': '',
      'team_b_p2_name': '', 'team_b_p2_id': '',
      'dependent_on_b': depId,
    };
  }

  Map<String, dynamic> _createPlayoffMatchDataDoublePlaceholder(String matchType, String matchName, String pA, String depA, String pB, String depB) {
    return {
      'tournament_id': widget.tournamentId,
      'status': 'scheduled',
      'court': 'TBD',
      'timestamp': FieldValue.serverTimestamp(),
      'home_score': 0, 'away_score': 0,
      'home_sets': 0, 'away_sets': 0,
      'current_set': 1, 'past_sets': [],
      'match_type': matchType, 'group': matchName, 'round': 'Sluttspill',
      
      'team_a_name': pA, 'team_a_id': 'placeholder',
      'team_a_p1_name': '', 'team_a_p1_id': '',
      'team_a_p2_name': '', 'team_a_p2_id': '',
      'dependent_on_a': depA,
      
      'team_b_name': pB, 'team_b_id': 'placeholder',
      'team_b_p1_name': '', 'team_b_p1_id': '',
      'team_b_p2_name': '', 'team_b_p2_id': '',
      'dependent_on_b': depB,
    };
  }
}