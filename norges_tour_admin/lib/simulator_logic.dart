import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class MatchSimulator {
  static final _random = Random();

  /// Simulerer alle planlagte kamper i en turnering
  static Future<void> simulateScheduledMatches(String tournamentId, Function(String) onProgress) async {
    final matchesSnap = await FirebaseFirestore.instance
        .collection('matches')
        .where('tournament_id', isEqualTo: tournamentId)
        .where('status', isEqualTo: 'scheduled')
        .get();

    final matches = matchesSnap.docs;
    if (matches.isEmpty) {
      onProgress("Ingen planlagte kamper å simulere.");
      return;
    }

    onProgress("Starter simulering av ${matches.length} kamper...");

    int count = 0;
    for (var matchDoc in matches) {
      await _simulateSingleMatch(matchDoc.id, matchDoc.data());
      count++;
      onProgress("Simulert $count / ${matches.length} kamper...");
    }

    onProgress("Simulering fullført!");
  }

  static Future<void> _simulateSingleMatch(String matchId, Map<String, dynamic> matchData) async {
    // 1. Avgjør hvem som vinner kampen (Lag A eller Lag B)
    bool homeWinsMatch = _random.nextBool();
    int homeSets = homeWinsMatch ? 2 : (_random.nextBool() ? 1 : 0);
    int awaySets = homeWinsMatch ? (homeSets == 2 && _random.nextBool() ? 1 : 0) : 2;
    if (!homeWinsMatch && awaySets == 2 && homeSets == 0 && _random.nextBool()) homeSets = 1;

    int totalSets = homeSets + awaySets;
    int currentSet = 1;

    WriteBatch batch = FirebaseFirestore.instance.batch();
    
    // Referanse til kampen
    DocumentReference matchRef = FirebaseFirestore.instance.collection('matches').doc(matchId);

    // Hent spillere
    String p1Home = matchData['team_a_p1_name'] ?? 'P1H';
    String p2Home = matchData['team_a_p2_name'] ?? 'P2H';
    String? p1HomeId = matchData['team_a_p1_id'];
    String? p2HomeId = matchData['team_a_p2_id'];

    String p1Away = matchData['team_b_p1_name'] ?? 'P1A';
    String p2Away = matchData['team_b_p2_name'] ?? 'P2A';
    String? p1AwayId = matchData['team_b_p1_id'];
    String? p2AwayId = matchData['team_b_p2_id'];

    String homeTeamName = matchData['team_a_name'] ?? 'Lag A';
    String awayTeamName = matchData['team_b_name'] ?? 'Lag B';

    // Simuler hvert sett
    while (currentSet <= totalSets) {
      bool homeWinsSet = (currentSet == 1 && homeSets > 0) || 
                         (currentSet == 2 && (homeSets == 2 || (homeSets == 1 && awaySets == 2))) ||
                         (currentSet == 3 && homeSets == 2);
                         
      if (currentSet == 2 && homeSets == 1 && awaySets == 1 && homeWinsSet == true) {
         // Pass på at det blir 1-1 før 3. sett
         homeWinsSet = false; 
      }
      if (currentSet == 2 && homeSets == 1 && awaySets == 2) {
        homeWinsSet = true;
      }
      if (currentSet == 2 && homeSets == 2 && awaySets == 1) {
        homeWinsSet = false;
      }

      int targetScore = currentSet == 3 ? 15 : 21;
      int loserScore = _random.nextInt(targetScore - 2); 
      // Sjelden overtid for enkelhets skyld
      if (_random.nextDouble() > 0.8) {
        targetScore += _random.nextInt(3) + 1;
        loserScore = targetScore - 2;
      }

      int homeScore = homeWinsSet ? targetScore : loserScore;
      int awayScore = homeWinsSet ? loserScore : targetScore;

      // Generer events for dette settet
      _generateEventsForSet(
        matchRef: matchRef,
        batch: batch,
        homeScoreTarget: homeScore,
        awayScoreTarget: awayScore,
        setNumber: currentSet,
        p1Home: p1Home, p2Home: p2Home, p1HomeId: p1HomeId, p2HomeId: p2HomeId, homeTeam: homeTeamName,
        p1Away: p1Away, p2Away: p2Away, p1AwayId: p1AwayId, p2AwayId: p2AwayId, awayTeam: awayTeamName,
      );

      currentSet++;
    }

    // Oppdater selve kampen
    batch.update(matchRef, {
      'status': 'finished',
      'home_score': homeSets, // I resultatvisning kan man lagre sett, men i databasen lagrer vi kanskje poengene fra siste sett, eller bare sett-stilling.
      'away_score': awaySets, // For å bevare formatet til appen, oppdaterer vi home_score og away_score til å være sett-score hvis det er ferdig. Egentlig burde det være set_scores.
      'home_sets': homeSets,
      'away_sets': awaySets,
    });

    // Modified Pool Play: Sett plasseringer etter Kamp 3 og Kamp 4
    String? matchType = matchData['match_type'];
    if (matchType == 'group_match_3' || matchType == 'group_match_4') {
       String? winnerTeamId = homeWinsMatch ? matchData['team_a_id'] : matchData['team_b_id'];
       String? loserTeamId = homeWinsMatch ? matchData['team_b_id'] : matchData['team_a_id'];

       if (winnerTeamId != null && loserTeamId != null) {
         int winnerPlacement = matchType == 'group_match_3' ? 1 : 3;
         int loserPlacement  = matchType == 'group_match_3' ? 2 : 4;

         batch.update(FirebaseFirestore.instance.collection('teams').doc(winnerTeamId), {
           'group_placement': winnerPlacement
         });
         batch.update(FirebaseFirestore.instance.collection('teams').doc(loserTeamId), {
           'group_placement': loserPlacement
         });
       }
    }

    await batch.commit();
  }

  static void _generateEventsForSet({
    required DocumentReference matchRef,
    required WriteBatch batch,
    required int homeScoreTarget,
    required int awayScoreTarget,
    required int setNumber,
    required String p1Home, required String p2Home, String? p1HomeId, String? p2HomeId, required String homeTeam,
    required String p1Away, required String p2Away, String? p1AwayId, String? p2AwayId, required String awayTeam,
  }) {
    int currentHome = 0;
    int currentAway = 0;

    List<String> actions = ['Kill', 'Kill', 'Kill', 'Block', 'Ace', 'Opponent Error', 'Opponent Error'];

    while (currentHome < homeScoreTarget || currentAway < awayScoreTarget) {
      bool pointToHome = false;
      if (currentHome < homeScoreTarget && currentAway < awayScoreTarget) {
        pointToHome = _random.nextBool();
      } else if (currentHome < homeScoreTarget) {
        pointToHome = true;
      }

      String scoringTeam = pointToHome ? homeTeam : awayTeam;
      
      // Velg spiller som tok poenget (tilfeldig for enkelhets skyld)
      bool isP1 = _random.nextBool();
      String playerName = pointToHome ? (isP1 ? p1Home : p2Home) : (isP1 ? p1Away : p2Away);
      String? playerId = pointToHome ? (isP1 ? p1HomeId : p2HomeId) : (isP1 ? p1AwayId : p2AwayId);
      
      String partnerName = pointToHome ? (!isP1 ? p1Home : p2Home) : (!isP1 ? p1Away : p2Away);
      String? partnerId = pointToHome ? (!isP1 ? p1HomeId : p2HomeId) : (!isP1 ? p1AwayId : p2AwayId);

      String action = actions[_random.nextInt(actions.length)];
      
      if (pointToHome) {
        currentHome++;
      } else {
        currentAway++;
      }

      DocumentReference eventRef = matchRef.collection('events').doc();
      batch.set(eventRef, {
        'player_name': action == 'Opponent Error' ? 'Lag' : playerName,
        'player_id': action == 'Opponent Error' ? null : playerId,
        'team': scoringTeam,
        'action': action,
        'point_to': pointToHome ? 'home' : 'away',
        'phase': _random.nextBool() ? 'Break Point' : 'Sideout',
        'timestamp': FieldValue.serverTimestamp(), // Not entirely accurate chronologically in a batch, but okay for stats aggregation
        'home_score': currentHome,
        'away_score': currentAway,
        'set_number': setNumber,
      });

      // Legg til Set Assist hvis det var en Kill
      if (action == 'Kill') {
        DocumentReference assistRef = matchRef.collection('events').doc();
        batch.set(assistRef, {
          'player_name': partnerName,
          'player_id': partnerId,
          'team': scoringTeam,
          'action': 'Set Assist',
          'point_to': 'none',
          'phase': 'Sideout',
          'timestamp': FieldValue.serverTimestamp(),
          'set_number': setNumber,
        });
      }
      
      // Legg til noen forsøk
      DocumentReference attemptRef = matchRef.collection('events').doc();
      batch.set(attemptRef, {
        'player_name': partnerName,
        'player_id': partnerId,
        'team': scoringTeam,
        'action': 'Set Attempt',
        'point_to': 'none',
        'phase': 'Sideout',
        'timestamp': FieldValue.serverTimestamp(),
        'set_number': setNumber,
      });
    }
  }
}
