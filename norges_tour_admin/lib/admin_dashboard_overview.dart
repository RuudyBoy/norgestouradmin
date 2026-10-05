import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme/app_colors.dart';
import 'theme/responsive_layout.dart';

/// Responsive overview widget displaying KPI summary cards for the most recent tournaments.
///
/// Lays out tournament summary cards side-by-side in multi-column format on desktop,
/// wraps across 2 columns on tablet, and gracefully collapses to single-column on mobile.
/// Wrapped in [ResponsiveContainer.dashboard] to prevent stretching on ultrawide monitors.
class AdminDashboardOverview extends StatelessWidget {
  /// Optional custom padding overriding standard responsive padding.
  final EdgeInsetsGeometry? padding;

  /// Whether to wrap the overview in [ResponsiveContainer.dashboard] to constrain max-width
  /// and apply responsive edge padding. Defaults to `true`.
  final bool wrapInContainer;

  /// Optional test tournaments for headless widget testing without Firebase dependencies.
  final List<Map<String, dynamic>>? testTournaments;

  /// Optional flag indicating test mode to bypass live Firestore streams.
  final bool testMode;

  const AdminDashboardOverview({
    super.key,
    this.padding,
    this.wrapInContainer = true,
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

        final tournaments = tourSnapshot.data!.docs.map((tDoc) {
          final tData = tDoc.data() as Map<String, dynamic>;
          return {
            'id': tDoc.id,
            ...tData,
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
    final Widget overviewContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "Oversikt (Siste turneringer)",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.adminText,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final isDesktop = Responsive.isDesktopOrLarger(context) || availableWidth >= 900.0;
            final isTablet = (Responsive.isTablet(context) ||
                    (availableWidth >= 550.0 && availableWidth < 900.0)) &&
                !isDesktop;

            const double spacing = 16.0;
            const double runSpacing = 16.0;

            final int columns;
            if (isDesktop) {
              columns = tournaments.length.clamp(1, 3);
            } else if (isTablet) {
              columns = tournaments.length == 1 ? 1 : 2;
            } else {
              columns = 1;
            }

            final double cardWidth;
            if (columns == 1) {
              if (isDesktop && availableWidth > 500) {
                cardWidth = 440.0;
              } else {
                cardWidth = availableWidth;
              }
            } else {
              // Subtract 0.1 to guard against floating-point rounding wrap in Wrap
              final rawWidth =
                  (availableWidth - (columns - 1) * spacing) / columns - 0.1;
              cardWidth = rawWidth;
            }

            final effectiveCardWidth = math.max(0.0, cardWidth);

            return Wrap(
              spacing: spacing,
              runSpacing: runSpacing,
              children: tournaments.map((tData) {
                final tId = tData['id'] as String? ?? '';
                final tName = tData['name'] as String? ?? 'Ukjent';

                return SizedBox(
                  width: effectiveCardWidth,
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
        const Divider(height: 32, thickness: 1, color: Colors.white24),
        const Text(
          "Alle turneringer",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.adminText,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );

    if (wrapInContainer) {
      return ResponsiveContainer.dashboard(
        padding: padding,
        child: overviewContent,
      );
    }

    return Padding(
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: Responsive.contentPadding(context),
            vertical: 12.0,
          ),
      child: overviewContent,
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

  Widget _buildCardContent(BuildContext context, int teamCount, bool isLoading) {
    final deadline = tournamentData['registration_deadline'] as String?;
    final regStatus =
        tournamentData['registration_status'] as String? ?? 'open';
    final isOpen = regStatus == 'open';

    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.adminSurface,
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
            const SizedBox(height: 10),
            if (isLoading)
              const SizedBox(
                height: 44,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _StatColumn(
                      label: "Lag",
                      value: teamCount.toString(),
                      color: AppColors.adminText,
                    ),
                  ),
                  Expanded(
                    child: _StatColumn(
                      label: "Frist",
                      value: _shortDate(deadline),
                      color: Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _StatColumn(
                      label: "Påmelding",
                      value: isOpen ? "Åpen" : "Stengt",
                      color: AppColors.adminText,
                    ),
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
      return _buildCardContent(context, teamCount, false);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('teams')
          .where('tournament_id', isEqualTo: tournamentId)
          .snapshots(),
      builder: (context, teamsSnap) {
        final teamCount = teamsSnap.hasData ? teamsSnap.data!.docs.length : 0;
        return _buildCardContent(context, teamCount, !teamsSnap.hasData);
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
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.adminTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
