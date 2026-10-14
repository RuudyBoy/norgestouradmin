import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_shell.dart';
import 'theme/app_colors.dart';
import 'theme/admin_ui.dart';

/// «Krever handling» – tre KPI-kort øverst på turneringsoversikten:
///   1. Påmeldinger som venter (registrations.status == 'pending')
///   2. Spillerkrav som venter (player_claims.status == 'pending')
///   3. Nærmeste påmeldingsfrist blant turneringer med åpen påmelding
///
/// Kun lesing og visning – ingen skriving til databasen.
class AdminDashboardOverview extends StatelessWidget {
  /// Optional custom padding.
  final EdgeInsetsGeometry? padding;

  /// Beholdt for bakoverkompatibilitet (brukes ikke lenger til maks-bredde –
  /// siden rundt styrer bredden).
  final bool wrapInContainer;

  /// Optional test tournaments for headless widget testing without Firebase dependencies.
  final List<Map<String, dynamic>>? testTournaments;

  /// Optional flag indicating test mode to bypass live Firestore streams.
  final bool testMode;

  /// Turneringene som allerede er lastet av siden (unngår dobbel henting).
  final List<Map<String, dynamic>>? tournaments;

  const AdminDashboardOverview({
    super.key,
    this.padding,
    this.wrapInContainer = true,
    this.testTournaments,
    this.testMode = false,
    this.tournaments,
  });

  @override
  Widget build(BuildContext context) {
    final isTest = testTournaments != null || testMode;
    final tours = tournaments ?? testTournaments ?? const <Map<String, dynamic>>[];

    if (isTest) {
      return _wrap(_buildCards(context, tours, const {}, 0));
    }

    if (tournaments == null) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tournaments').snapshots(),
        builder: (context, snap) {
          final list = snap.hasData
              ? snap.data!.docs.map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)}).toList()
              : <Map<String, dynamic>>[];
          return _withLiveCounts(context, list);
        },
      );
    }
    return _withLiveCounts(context, tours);
  }

  Widget _wrap(Widget child) => padding == null ? child : Padding(padding: padding!, child: child);

  Widget _withLiveCounts(BuildContext context, List<Map<String, dynamic>> tours) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('registrations')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, regSnap) {
        final pendingByTournament = <String, int>{};
        if (regSnap.hasData) {
          for (final d in regSnap.data!.docs) {
            final tid = (d.data() as Map<String, dynamic>)['tournament_id'] as String? ?? '';
            pendingByTournament[tid] = (pendingByTournament[tid] ?? 0) + 1;
          }
        }
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('player_claims')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, claimSnap) {
            final claims = claimSnap.hasData ? claimSnap.data!.docs.length : 0;
            return _wrap(_buildCards(context, tours, pendingByTournament, claims));
          },
        );
      },
    );
  }

  static DateTime? _parse(String? s) {
    if (s == null) return null;
    final p = s.split('.');
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final y = int.tryParse(p[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  static String _short(String? s) {
    if (s == null || s.isEmpty) return '–';
    final parts = s.split('.');
    if (parts.length >= 2) return '${parts[0]}.${parts[1]}';
    return s;
  }

  Widget _buildCards(
    BuildContext context,
    List<Map<String, dynamic>> tours,
    Map<String, int> pendingByTournament,
    int pendingClaims,
  ) {
    // 1 – påmeldinger
    final nameById = {for (final t in tours) (t['id'] as String? ?? ''): (t['name'] as String? ?? 'Ukjent')};
    final pendingTotal = pendingByTournament.values.fold<int>(0, (a, b) => a + b);
    final pendingNames = pendingByTournament.keys
        .where((id) => nameById.containsKey(id))
        .map((id) => nameById[id]!)
        .toList();
    String regSub;
    if (pendingTotal == 0) {
      regSub = 'Ingen ventende påmeldinger';
    } else if (pendingNames.length <= 2) {
      regSub = pendingNames.isEmpty ? 'Venter på godkjenning' : pendingNames.join(' · ');
    } else {
      regSub = '${pendingNames.take(2).join(' · ')} +${pendingNames.length - 2}';
    }

    // 3 – nærmeste frist
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    Map<String, dynamic>? nearest;
    DateTime? nearestDate;
    for (final t in tours) {
      if ((t['registration_status'] as String? ?? 'open') != 'open') continue;
      final dl = _parse(t['registration_deadline'] as String?);
      if (dl == null || dl.isBefore(today)) continue;
      if (nearestDate == null || dl.isBefore(nearestDate)) {
        nearestDate = dl;
        nearest = t;
      }
    }
    String dlTitle;
    String dlSub;
    if (nearest == null || nearestDate == null) {
      dlTitle = 'Ingen åpne frister';
      dlSub = 'Ingen turneringer med åpen påmelding';
    } else {
      final days = nearestDate.difference(today).inDays;
      dlTitle = days == 0
          ? 'Frist i dag'
          : days == 1
              ? 'Frist i morgen'
              : 'Frist om $days dager';
      dlSub = '${nearest['name'] ?? 'Ukjent'} · Frist ${_short(nearest['registration_deadline'] as String?)}';
    }

    final cards = <Widget>[
      _KpiCard(
        icon: Icons.how_to_reg_outlined,
        title: pendingTotal == 1 ? '1 påmelding venter' : '$pendingTotal påmeldinger venter',
        subtitle: regSub,
      ),
      _KpiCard(
        icon: Icons.assignment_ind_outlined,
        title: pendingClaims == 1 ? '1 spillerkrav venter' : '$pendingClaims spillerkrav venter',
        subtitle: pendingClaims == 0 ? 'Ingen ventende krav' : 'Venter på godkjenning',
        onTap: testMode ? null : () => AdminShell.of(context)?.setIndex(2),
      ),
      _KpiCard(
        icon: Icons.schedule,
        title: dlTitle,
        subtitle: dlSub,
        iconBg: AppColors.adminWarningBg,
        iconFg: AppColors.adminWarning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final w = constraints.maxWidth;
        final cols = w >= 800 ? 3 : (w >= 520 ? 2 : 1);
        final cardW = cols == 1 ? w : (w - gap * (cols - 1)) / cols - 0.1;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final c in cards) SizedBox(width: cardW, child: c)],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color iconBg;
  final Color iconFg;

  const _KpiCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.iconBg = AppColors.adminInfoBg,
    this.iconFg = AppColors.adminPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          AdminIconTile(icon: icon, background: iconBg, foreground: iconFg),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: AdminText.ui(size: 15, weight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(subtitle,
                    style: AdminText.ui(size: 13, color: AppColors.adminTextSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
