// Proposed refactoring for AdminDashboardOverview in lib/admin_dashboard_overview.dart
// Strictly preserves all Firebase collections, stream limits, registration calculations, and stat badges.
// Replaces fixed 120px horizontal scroll ListView with responsive Wrap/Row layout filling desktop width with zero RenderFlex overflow.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme/app_colors.dart';

class AdminDashboardOverview extends StatelessWidget {
  /// Optional test tournaments for headless widget testing without Firebase dependencies.
  final List<Map<String, dynamic>>? testTournaments;

  /// Optional flag indicating test mode to bypass live Firestore streams.
  final bool testMode;

  const AdminDashboardOverview({
    super.key,
    this.testTournaments,
    this.testMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (testTournaments != null || testMode) {
      final tournaments = (testTournaments ?? const []).take(3).toList();
      if (tournaments.isEmpty) {
        return const SizedBox.shrink();
      }
      return _buildOverviewContent(context, tournaments);
    }

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

        final tournaments = tourSnapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();

        return _buildOverviewContent(context, tournaments);
      },
    );
  }

  Widget _buildOverviewContent(
    BuildContext context,
    List<Map<String, dynamic>> tournaments,
  ) {
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final isSingleColumn = availableWidth < 600;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: tournaments.map((tData) {
                  final tId = tData['id'] as String? ?? '';
                  final tName = tData['name'] as String? ?? 'Ukjent';
                  final cardWidth = isSingleColumn
                      ? availableWidth
                      : ((availableWidth - (tournaments.length - 1) * 12) /
                              tournaments.length)
                          .clamp(260.0, 480.0);

                  return SizedBox(
                    width: cardWidth,
                    child: _TournamentStatCard(
                      tournamentId: tId,
                      tournamentName: tName,
                      tournamentData: tData,
                      testMode: testMode,
                    ),
                  );
                }).toList(),
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
  }
}

class _TournamentStatCard extends StatelessWidget {
  final String tournamentId;
  final String tournamentName;
  final Map<String, dynamic> tournamentData;
  final bool testMode;

  const _TournamentStatCard({
    required this.tournamentId,
    required this.tournamentName,
    required this.tournamentData,
    this.testMode = false,
  });

  String _shortDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '–';
    final parts = dateStr.split('.');
    if (parts.length >= 2) return '${parts[0]}.${parts[1]}';
    return dateStr;
  }

  Widget _buildCard(int teamCount, bool isLoading) {
    final deadline = tournamentData['registration_deadline'] as String?;
    final regStatus = tournamentData['registration_status'] as String? ?? 'open';
    final isOpen = regStatus == 'open';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.adminSurface,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
            if (isLoading)
              const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Row(
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (testMode || tournamentData.containsKey('team_count')) {
      final teamCount = tournamentData['team_count'] as int? ?? 0;
      return _buildCard(teamCount, false);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('teams')
          .where('tournament_id', isEqualTo: tournamentId)
          .snapshots(),
      builder: (context, teamsSnap) {
        final teamCount = teamsSnap.hasData ? teamsSnap.data!.docs.length : 0;
        return _buildCard(teamCount, !teamsSnap.hasData);
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
      mainAxisSize: MainAxisSize.min,
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
