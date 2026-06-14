import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MatchControlPage extends StatefulWidget {
  final String matchId;
  final String teamAName;
  final String teamBName;

  const MatchControlPage({
    super.key,
    required this.matchId,
    required this.teamAName,
    required this.teamBName,
  });

  @override
  State<MatchControlPage> createState() => _MatchControlPageState();
}

class _MatchControlPageState extends State<MatchControlPage> {
  
  void _updateScore(bool isHomeTeam, int delta) async {
    final docRef = FirebaseFirestore.instance.collection('matches').doc(widget.matchId);
    final doc = await docRef.get();
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;
    
    int hScore = data['home_score'] ?? 0;
    int aScore = data['away_score'] ?? 0;
    int currentSet = data['current_set'] ?? 1;
    
    if (isHomeTeam) hScore += delta;
    else aScore += delta;
    
    if (hScore < 0) hScore = 0;
    if (aScore < 0) aScore = 0;
    
    await docRef.update({
      isHomeTeam ? 'home_score' : 'away_score': isHomeTeam ? hScore : aScore,
    });
    
    // Check if set is won
    int winScore = currentSet == 3 ? 15 : 21;
    bool homeWins = hScore >= winScore && (hScore - aScore) >= 2;
    bool awayWins = aScore >= winScore && (aScore - hScore) >= 2;
    
    if (homeWins || awayWins) {
      if (!mounted) return;
      String winner = homeWins ? widget.teamAName : widget.teamBName;
      _showSetWonDialog(winner, hScore, aScore, currentSet);
    }
  }

  void _showSetWonDialog(String winnerName, int hScore, int aScore, int currentSet) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text("Sett $currentSet ferdig!"),
          content: Text("$winnerName vant settet $hScore - $aScore.\nVil du starte neste sett?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Avbryt
              child: const Text("Avbryt / Angre"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _finishSet(hScore, aScore);
              },
              child: const Text("Fullfør settet"),
            )
          ]
        );
      }
    );
  }

  Future<void> _finishSet(int hScore, int aScore) async {
    final docRef = FirebaseFirestore.instance.collection('matches').doc(widget.matchId);
    final doc = await docRef.get();
    final data = doc.data() as Map<String, dynamic>;
    
    int hSets = data['home_sets'] ?? 0;
    int aSets = data['away_sets'] ?? 0;
    int currentSet = data['current_set'] ?? 1;
    List<dynamic> pastSets = List.from(data['past_sets'] ?? []);
    
    if (hScore > aScore) hSets++; else aSets++;
    pastSets.add({"home": hScore, "away": aScore});
    
    if (hSets == 2 || aSets == 2) {
      // Match won
      await docRef.update({
        'home_sets': hSets,
        'away_sets': aSets,
        'past_sets': pastSets,
        'status': 'finished',
      });
      await _advanceTeamIfPlayoff();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kampen er ferdig!")));
    } else {
      await docRef.update({
        'home_score': 0,
        'away_score': 0,
        'home_sets': hSets,
        'away_sets': aSets,
        'current_set': currentSet + 1,
        'past_sets': pastSets,
      });
    }
  }

  void _updateStatus(String newStatus) async {
    await FirebaseFirestore.instance.collection('matches').doc(widget.matchId).update({
      'status': newStatus,
    });
    
    if (newStatus == 'finished') {
      await _advanceTeamIfPlayoff();
    }
  }

  Future<void> _advanceTeamIfPlayoff() async {
    final doc = await FirebaseFirestore.instance.collection('matches').doc(widget.matchId).get();
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;
    
    final hScore = data['home_score'] ?? 0;
    final aScore = data['away_score'] ?? 0;
    final winId = hScore > aScore ? data['team_a_id'] : data['team_b_id'];
    final loseId = hScore > aScore ? data['team_b_id'] : data['team_a_id'];
    
    if (winId == null || loseId == null || winId == 'placeholder' || loseId == 'placeholder') return;
    
    final dependentMatchesSnap = await FirebaseFirestore.instance.collection('matches')
      .where('tournament_id', isEqualTo: data['tournament_id'])
      .get();
      
    WriteBatch batch = FirebaseFirestore.instance.batch();
    
    for (var m in dependentMatchesSnap.docs) {
      final mData = m.data();
      Map<String, dynamic> docUpdates = {};
      
      if (mData['team_a_id'] == 'placeholder' && mData['dependent_on_a'] == widget.matchId) {
         final targetId = mData['match_type'] == '5_playoff_bronze' ? loseId : winId;
         final tDoc = await FirebaseFirestore.instance.collection('teams').doc(targetId).get();
         if (tDoc.exists) {
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
      if (mData['team_b_id'] == 'placeholder' && mData['dependent_on_b'] == widget.matchId) {
         final targetId = mData['match_type'] == '5_playoff_bronze' ? loseId : winId;
         final tDoc = await FirebaseFirestore.instance.collection('teams').doc(targetId).get();
         if (tDoc.exists) {
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
      }
    }
    await batch.commit();
  }

  void _showEditInfoDialog(BuildContext context) async {
    final doc = await FirebaseFirestore.instance.collection('matches').doc(widget.matchId).get();
    final data = doc.data() as Map<String, dynamic>?;
    
    final timeController = TextEditingController(text: data?['start_time'] ?? '');
    final typeController = TextEditingController(text: data?['group'] ?? '');
    final courtController = TextEditingController(text: data?['court'] ?? '');

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Rediger Kampinfo"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: timeController,
                decoration: const InputDecoration(labelText: "Tidspunkt (f.eks 14:00)"),
              ),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(labelText: "Kamp-type (f.eks Finale, Pulje A)"),
              ),
              TextField(
                controller: courtController,
                decoration: const InputDecoration(labelText: "Bane"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Avbryt"),
            ),
            ElevatedButton(
              onPressed: () {
                FirebaseFirestore.instance.collection('matches').doc(widget.matchId).update({
                  'start_time': timeController.text.trim(),
                  'group': typeController.text.trim(),
                  'court': courtController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kampstyring"),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              _showEditInfoDialog(context);
            },
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('matches').doc(widget.matchId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final int homeScore = data['home_score'] ?? 0;
          final int awayScore = data['away_score'] ?? 0;
          final String status = data['status'] ?? 'scheduled';
          final int currentSet = data['current_set'] ?? 1;
          final int homeSets = data['home_sets'] ?? 0;
          final int awaySets = data['away_sets'] ?? 0;

          return Column(
            children: [
              // --- STATUS LINJE ---
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[200],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Status: ${status.toUpperCase()} (Sett $currentSet)", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        // START KAMP (LIVE)
                        if (status == 'scheduled' || status == 'finished')
                          ElevatedButton.icon(
                            onPressed: () => _updateStatus('live'),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text("START KAMP"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          ),
                        
                        // AVSLUTT KAMP
                        if (status == 'live')
                          ElevatedButton.icon(
                            onPressed: () => _updateStatus('finished'),
                            icon: const Icon(Icons.stop),
                            label: const Text("AVSLUTT"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          ),
                      ],
                    )
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // --- SCOREBOARD ---
              Expanded(
                child: Row(
                  children: [
                    // --- HJEMMELAG (VENSTRE) ---
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(widget.teamAName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          const SizedBox(height: 10),
                          Text("Sett vunnet: $homeSets", style: const TextStyle(fontSize: 16, color: Colors.blue)),
                          const SizedBox(height: 10),
                          Text("$homeScore", style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _scoreButton(Icons.remove, () => _updateScore(true, -1)),
                              const SizedBox(width: 20),
                              _scoreButton(Icons.add, () => _updateScore(true, 1), isBig: true),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // STREK I MIDTEN
                    Container(width: 2, color: Colors.grey[300], margin: const EdgeInsets.symmetric(vertical: 40)),

                    // --- BORTELAG (HØYRE) ---
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(widget.teamBName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          const SizedBox(height: 10),
                          Text("Sett vunnet: $awaySets", style: const TextStyle(fontSize: 16, color: Colors.blue)),
                          const SizedBox(height: 10),
                          Text("$awayScore", style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _scoreButton(Icons.remove, () => _updateScore(false, -1)),
                              const SizedBox(width: 20),
                              _scoreButton(Icons.add, () => _updateScore(false, 1), isBig: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Hjelpeknapp for design
  Widget _scoreButton(IconData icon, VoidCallback onTap, {bool isBig = false}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        padding: EdgeInsets.all(isBig ? 24 : 16),
        backgroundColor: isBig ? Colors.blue[800] : Colors.grey[300],
        foregroundColor: isBig ? Colors.white : Colors.black,
      ),
      child: Icon(icon, size: isBig ? 32 : 24),
    );
  }
}