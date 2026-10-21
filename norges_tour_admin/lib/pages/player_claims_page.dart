import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:norges_tour_admin/widgets/admin_shell.dart';
import 'package:norges_tour_admin/theme/app_colors.dart';
import 'package:norges_tour_admin/theme/responsive_layout.dart';

class PlayerClaimsPage extends StatelessWidget {
  const PlayerClaimsPage({super.key});

  Future<void> _approveClaim(BuildContext context, String claimId, String uid, String playerId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Update claim status
      final claimRef = FirebaseFirestore.instance.collection('player_claims').doc(claimId);
      batch.update(claimRef, {'status': 'approved', 'updatedAt': FieldValue.serverTimestamp()});

      // 2. Update user profile to link player
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      batch.set(userRef, {
        'linkedPlayerId': playerId,
        'isPlayer': true,
      }, SetOptions(merge: true));

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Krav godkjent!'), backgroundColor: AppColors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Feil: $e'), backgroundColor: AppColors.adminPrimary),
        );
      }
    }
  }

  Future<void> _rejectClaim(BuildContext context, String claimId) async {
    try {
      await FirebaseFirestore.instance.collection('player_claims').doc(claimId).update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Krav avvist.'), backgroundColor: AppColors.adminPrimary),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Feil: $e'), backgroundColor: AppColors.adminPrimary),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventende Spillerkrav'),
        backgroundColor: AppColors.adminPrimary,
        foregroundColor: AppColors.adminText,
        automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context),
      ),
      drawer: Responsive.isDesktopOrLarger(context)
          ? null
          : const AdminDrawer(selectedIndex: 2),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('player_claims')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Ingen ventende krav akkurat nå.',
                style: TextStyle(fontSize: 16, color: AppColors.adminTextSecondary),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ResponsiveContainer.dashboard(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final claimId = doc.id;
              final uid = data['uid'] ?? '';
              final playerId = data['playerId'] ?? '';
              final userName = data['userName'] ?? 'Ukjent bruker';
              final playerName = data['playerName'] ?? 'Ukjent spiller';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const Icon(Icons.person_add, size: 40, color: AppColors.adminPrimary),
                  title: Text(
                    '$userName ber om å bli koblet til $playerName',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text('Bruker-ID: $uid', style: const TextStyle(fontSize: 12, color: AppColors.adminTextSecondary)),
                      Text('Spiller-ID: $playerId', style: const TextStyle(fontSize: 12, color: AppColors.adminTextSecondary)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.adminPrimary),
                        tooltip: 'Avvis',
                        onPressed: () => _rejectClaim(context, claimId),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Godkjenn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          
                        ),
                        onPressed: () => _approveClaim(context, claimId, uid, playerId),
                      ),
                    ],
                  ),
                ),
              );
            },
            ),
          );
        },
      ),
    );
  }
}
