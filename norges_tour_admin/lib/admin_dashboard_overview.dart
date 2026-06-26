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
          return const SizedBox.shrink();
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
                    tournamentData: tData,
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
  final Map<String, dynamic> tournamentData;

  const _TournamentStatCard({
    required this.tournamentId,
    required this.tournamentName,
    required this.tournamentData,
  });

  String _shortDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '–';
    final parts = dateStr.split('.');
    if (parts.length >= 2) return '${parts[0]}.${parts[1]}';
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    final deadline = tournamentData['registration_deadline'] as String?;
    final regStatus = tournamentData['registration_status'] as String? ?? 'open';
    final isOpen = regStatus == 'open';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('teams')
          .where('tournament_id', isEqualTo: tournamentId)
          .snapshots(),
      builder: (context, teamsSnap) {
        final teamCount = teamsSnap.hasData ? teamsSnap.data!.docs.length : 0;

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
                  if (!teamsSnap.hasData)
                    const Expanded(child: Center(child: CircularProgressIndicator()))
                  else
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatColumn(
                            label: "Lag",
                            value: teamCount.toString(),
                            color: Colors.green,
                          ),
                          _StatColumn(
                            label: "Frist",
                            value: _shortDate(deadline),
                            color: Colors.orange,
                          ),
                          _StatColumn(
                            label: "Påmelding",
                            value: isOpen ? "Åpen" : "Stengt",
                            color: isOpen ? Colors.green : Colors.red,
                          ),
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
  final String value;
  final Color color;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
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
