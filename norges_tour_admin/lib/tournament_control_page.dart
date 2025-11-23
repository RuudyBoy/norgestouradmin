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

  void _showQrDialog(String matchId, String teamA, String teamB) {
    // VIKTIG: Her må vi etter hvert bytte ut "localhost" med den ekte nettadressen
    // når vi legger ut appen på nettet. 
    // For nå bruker vi en placeholder slik at du ser at det virker.
    String scorekeeperUrl = "https://norges-tour-scorekeeper.web.app/?matchId=$matchId";

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
                height: 200,
                width: 200,
                child: QrImageView(
                  data: scorekeeperUrl,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
              const SizedBox(height: 20),
              SelectableText(scorekeeperUrl, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Lukk"),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // Vi setter opp kontrolleren med 2 faner
    _tabController = TabController(length: 2, vsync: this);
    
    // Vi ber appen tegne seg på nytt når vi bytter fane (så knappen oppdateres)
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- FUNKSJON: LEGG TIL LAG ---
  // --- FUNKSJON: LEGG TIL LAG (MED SPILLER-VALG) ---
  void _showAddTeamDialog() {
    final TextEditingController teamNameController = TextEditingController();
    
    // Variabler for å lagre valgte spillere
    String? selectedPlayer1Id;
    String? selectedPlayer1Name;
    
    String? selectedPlayer2Id;
    String? selectedPlayer2Name;

    showDialog(
      context: context,
      builder: (context) => StreamBuilder<QuerySnapshot>(
        // 1. Hent alle spillere fra databasen
        stream: FirebaseFirestore.instance.collection('players').orderBy('first_name').snapshots(),
        builder: (context, snapshot) {
          
          // Sjekk om vi har data
          if (!snapshot.hasData) {
            return const AlertDialog(content: SizedBox(height: 50, child: Center(child: CircularProgressIndicator())));
          }

          final playerDocs = snapshot.data!.docs;
          
          // Hvis ingen spillere finnes, må vi si ifra
          if (playerDocs.isEmpty) {
            return AlertDialog(
              title: const Text("Mangler spillere"),
              content: const Text("Du må registrere spillere i databasen før du kan lage lag."),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
            );
          }

          // Lag listen til dropdown-menyen
          List<DropdownMenuItem<String>> playerItems = playerDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            // Vi setter sammen fornavn og etternavn
            final fullName = "${data['first_name']} ${data['last_name']}";
            return DropdownMenuItem<String>(
              value: doc.id, // VIKTIG: Vi lagrer ID-en som verdi
              child: Text(fullName), // Vi viser navnet til brukeren
            );
          }).toList();

          return AlertDialog(
            title: const Text("Registrer nytt lag"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: teamNameController,
                    decoration: const InputDecoration(labelText: "Lagnavn (f.eks. Mol/Sørum)"),
                  ),
                  const SizedBox(height: 24),
                  
                  // --- SPILLER 1 VELGER ---
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Velg Spiller 1", border: OutlineInputBorder()),
                    items: playerItems,
                    onChanged: (value) {
                      selectedPlayer1Id = value;
                      // Finn navnet som hører til ID-en for lagring
                      final selectedDoc = playerDocs.firstWhere((doc) => doc.id == value);
                      final data = selectedDoc.data() as Map<String, dynamic>;
                      selectedPlayer1Name = "${data['first_name']} ${data['last_name']}";
                    },
                  ),
                  
                  const SizedBox(height: 16),

                  // --- SPILLER 2 VELGER ---
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Velg Spiller 2", border: OutlineInputBorder()),
                    items: playerItems,
                    onChanged: (value) {
                      selectedPlayer2Id = value;
                      final selectedDoc = playerDocs.firstWhere((doc) => doc.id == value);
                      final data = selectedDoc.data() as Map<String, dynamic>;
                      selectedPlayer2Name = "${data['first_name']} ${data['last_name']}";
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Avbryt"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (teamNameController.text.isNotEmpty && 
                      selectedPlayer1Id != null && 
                      selectedPlayer2Id != null) {
                    
                    if (selectedPlayer1Id == selectedPlayer2Id) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Samme spiller valgt to ganger!")));
                       return;
                    }

                    // 1. Lagre til Firebase med BÅDE ID og Navn
                    await FirebaseFirestore.instance.collection('teams').add({
                      'team_name': teamNameController.text,
                      'tournament_id': widget.tournamentId,
                      
                      // Her lagrer vi ID-ene (for kobling)
                      'player1_id': selectedPlayer1Id,
                      'player2_id': selectedPlayer2Id,
                      
                      // Her lagrer vi navnene (for rask visning)
                      'player1_name': selectedPlayer1Name,
                      'player2_name': selectedPlayer2Name,
                      
                      'created_at': FieldValue.serverTimestamp(),
                    });
                    
                    if (mounted) Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Lag lagret med ID-er!")),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fyll ut alt!")));
                  }
                },
                child: const Text("Lagre Lag"),
              ),
            ],
          );
        }
      ),
    );
  }
  
  // --- FUNKSJON: LEGG TIL KAMP ---
// --- FUNKSJON: LEGG TIL KAMP (MED DROPDOWN) ---
  void _showAddMatchDialog() {
    final TextEditingController courtController = TextEditingController();
    
    // Vi trenger variabler for å huske hva brukeren velger
    String? selectedTeamA; // Vil lagre Navnet på Lag A
    String? selectedTeamB; // Vil lagre Navnet på Lag B
    
    // (Tips: I en enda proffere versjon lagrer vi ID-ene også, men navn holder nå)

    showDialog(
      context: context,
      builder: (context) => StreamBuilder<QuerySnapshot>(
        // 1. Hent alle lag som hører til denne turneringen
        stream: FirebaseFirestore.instance
            .collection('teams')
            .where('tournament_id', isEqualTo: widget.tournamentId)
            .snapshots(),
        builder: (context, snapshot) {
          
          // Hvis vi venter på data eller det oppstår feil...
          if (!snapshot.hasData) {
            return const AlertDialog(content: SizedBox(height: 50, child: Center(child: CircularProgressIndicator())));
          }

          final teamDocs = snapshot.data!.docs;

          // Lag en liste med "DropdownMenuItem" basert på lagene
          List<DropdownMenuItem<String>> teamItems = teamDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final teamName = data['team_name'] as String;
            return DropdownMenuItem<String>(
              value: teamName, // Dette er verdien vi lagrer
              child: Text(teamName), // Dette er teksten vi ser
            );
          }).toList();

          return AlertDialog(
            title: const Text("Sett opp ny kamp"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Velg lag fra listen:"),
                const SizedBox(height: 16),
                
                // --- DROPDOWN FOR LAG A ---
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Lag A (Hjemmelag)"),
                  items: teamItems,
                  onChanged: (value) {
                    selectedTeamA = value;
                  },
                ),
                
                const SizedBox(height: 16),

                // --- DROPDOWN FOR LAG B ---
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Lag B (Bortelag)"),
                  items: teamItems,
                  onChanged: (value) {
                    selectedTeamB = value;
                  },
                ),

                const SizedBox(height: 16),
                
                // Bane er fortsatt tekstfelt (til vi lager en bane-liste)
                TextField(
                  controller: courtController,
                  decoration: const InputDecoration(
                    labelText: "Bane (f.eks. Bane 1)", 
                    icon: Icon(Icons.map),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Avbryt"),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Sjekk at begge lag er valgt
                  if (selectedTeamA != null && selectedTeamB != null) {
                    
                    // Sjekk at man ikke valgte samme lag to ganger
                    if (selectedTeamA == selectedTeamB) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Et lag kan ikke spille mot seg selv!")),
                      );
                      return;
                    }

                    // 1. Lagre til 'matches' i Firebase
                    await FirebaseFirestore.instance.collection('matches').add({
                      'tournament_id': widget.tournamentId,
                      'team_a_name': selectedTeamA,
                      'team_b_name': selectedTeamB,
                      'home_score': 0,
                      'away_score': 0,
                      'status': 'scheduled',
                      'court': courtController.text.isEmpty ? 'Bane ?' : courtController.text,
                      'created_at': FieldValue.serverTimestamp(),
                    });
                    
                    // 2. Lukk vinduet
                    if (mounted) Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Kamp satt opp!")),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Du må velge to lag!")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
                child: const Text("Lagre Kamp"),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin: ${widget.tournamentName}"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController, // Koble til vår kontroller
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.sports_volleyball), text: "Kamper"), // Index 0
            Tab(icon: Icon(Icons.groups), text: "Lag"),               // Index 1
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController, // Koble til her også
        children: [
          // Fane 0: Kamper
          _buildMatchesTab(),

          // Fane 1: Lag
          _buildTeamsTab(),
        ],
      ),
      
      // --- DEN SMARTE KNAPPEN ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 1) {
            // Hvis vi er på LAG-fanen (Index 1)
            _showAddTeamDialog();
          } else {
            // Hvis vi er på KAMPER-fanen (Index 0)
            _showAddMatchDialog(); // <--- HER KJØRER VI NY KODE!
          }
        },
        // Bytt ikon og tekst basert på fanen!
        label: Text(_tabController.index == 1 ? "Nytt Lag" : "Ny Kamp"),
        icon: Icon(_tabController.index == 1 ? Icons.group_add : Icons.sports_score),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
    );
  }
  
  // ... (Behold _buildTeamsTab og _buildMatchesTab som de var) ...
  // Lim inn de to funksjonene fra forrige svar her hvis du slettet dem ved et uhell.
  
  Widget _buildTeamsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('teams')
          .where('tournament_id', isEqualTo: widget.tournamentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final teams = snapshot.data!.docs;

        if (teams.isEmpty) {
          return const Center(child: Text("Ingen lag påmeldt i denne turneringen."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: teams.length,
          itemBuilder: (context, index) {
            final data = teams[index].data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.group),
                title: Text(data['team_name'] ?? 'Ukjent Lag'),
                subtitle: Text("${data['player1_name'] ?? ''} & ${data['player2_name'] ?? ''}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    // Slett dokumentet fra Firebase
                    FirebaseFirestore.instance.collection('teams').doc(teams[index].id).delete();
                  },
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
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('tournament_id', isEqualTo: widget.tournamentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final matches = snapshot.data!.docs;

        if (matches.isEmpty) {
          return const Center(child: Text("Ingen kamper satt opp enda."));
        }

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
                subtitle: Text("Bane: ${data['court']} • Status: $status"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // QR-KNAPP
                    IconButton(
                      icon: const Icon(Icons.qr_code, color: Colors.black),
                      tooltip: "Vis QR-kode for dommer",
                      onPressed: () => _showQrDialog(
                        matches[index].id, 
                        data['team_a_name'] ?? 'Lag A', 
                        data['team_b_name'] ?? 'Lag B'
                      ),
                    ),
                    
                    // KAMPSTYRING-KNAPP
                    IconButton(
                      icon: const Icon(Icons.sports_esports, color: Colors.green),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MatchControlPage(
                              matchId: matches[index].id,
                              teamAName: data['team_a_name'] ?? 'Lag A',
                              teamBName: data['team_b_name'] ?? 'Lag B',
                            ),
                          ),
                        );
                      },
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