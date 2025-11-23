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
  
  // --- FUNKSJON: ENDRE POENG ---
  // delta er enten +1 eller -1
  void _updateScore(bool isHomeTeam, int delta) {
    FirebaseFirestore.instance.collection('matches').doc(widget.matchId).update({
      isHomeTeam ? 'home_score' : 'away_score': FieldValue.increment(delta),
    });
  }

  // --- FUNKSJON: ENDRE STATUS (LIVE / FINISHED) ---
  void _updateStatus(String newStatus) {
    FirebaseFirestore.instance.collection('matches').doc(widget.matchId).update({
      'status': newStatus,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kampstyring"),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('matches').doc(widget.matchId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final int homeScore = data['home_score'] ?? 0;
          final int awayScore = data['away_score'] ?? 0;
          final String status = data['status'] ?? 'scheduled';

          return Column(
            children: [
              // --- STATUS LINJE ---
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[200],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Status: ${status.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold)),
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
                          const SizedBox(height: 20),
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
                          const SizedBox(height: 20),
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