import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme/app_colors.dart';

class AdminDashboardOverview extends StatelessWidget {
  const AdminDashboardOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .orderBy('created_at', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, tourSnapshot) {
        if (!tourSnapshot.hasData || tourSnapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink(); // Ingen turneringer
        }

        final tournaments = tourSnapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                "Oversikt (Siste turneringer)",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.adminText,
                ),
              ),
            ),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tournaments.length,
                itemBuilder: (context, index) {
                  final tDoc = tournaments[index];
                  final tData = tDoc.data() as Map<String, dynamic>;
                  final tName = tData['name'] ?? 'Ukjent';

                  return _TournamentStatCard(
                    tournamentId: tDoc.id,
                    tournamentName: tName,
                  );
                },
              ),
            ),
            const Divider(height: 32, thickness: 1, color: Colors.white24),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                "Alle turneringer",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.adminText,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TournamentStatCard extends StatelessWidget {
  final String tournamentId;
  final String tournamentName;

  const _TournamentStatCard({
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('tournament_id', isEqualTo: tournamentId)
          .snapshots(),
      builder: (context, matchSnap) {
        int liveCount = 0;
        int scheduledCount = 0;
        int finishedCount = 0;

        if (matchSnap.hasData) {
          for (var doc in matchSnap.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'];
            if (status == 'live') liveCount++;
            else if (status == 'scheduled') scheduledCount++;
            else if (status == 'finished') finishedCount++;
          }
        }

        return Container(
          width: 260,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: AppColors.adminSurface,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tournamentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.adminText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (!matchSnap.hasData)
                    const Expanded(child: Center(child: CircularProgressIndicator()))
                  else
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatColumn(label: "Live", count: liveCount, color: Colors.green),
                          _StatColumn(label: "Venter", count: scheduledCount, color: Colors.orange),
                          _StatColumn(label: "Ferdig", count: finishedCount, color: Colors.blue),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatColumn({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.adminTextSecondary,
          ),
        ),
      ],
    );
  }
}
