import 'dart:io';

void main() {
  final file = File('lib/tournament_control_page.dart');
  var lines = file.readAsLinesSync();

  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains("Widget _buildCategoryOppsett(String catId, String? catName) {")) {
      var end = -1;
      for (var j = i; j < lines.length; j++) {
        if (lines[j].contains("Widget _buildOppsettSubTab(String title) {")) {
          end = j - 1;
          break;
        }
      }
      if (end != -1) {
        var newCatOppsett = """  Widget _buildCategoryOppsett(String catId, String? catName) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('teams').where('tournament_id', isEqualTo: widget.tournamentId).where('category_id', isEqualTo: catId).snapshots(),
      builder: (ctx, teamSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('matches').where('tournament_id', isEqualTo: widget.tournamentId).where('category_id', isEqualTo: catId).snapshots(),
          builder: (ctx2, matchSnap) {
            if (!teamSnap.hasData || !matchSnap.hasData) return const SizedBox.shrink();
            final teams = teamSnap.data!.docs;
            final allMatches = matchSnap.data!.docs;
            final hasMatches = allMatches.isNotEmpty;
            final seedingMatches = allMatches.where((m) => (m.data() as Map)['stage'] == 'seeding').toList();
            final groupMatches   = allMatches.where((m) => (m.data() as Map)['stage'] == 'group').toList();
            final playoffMatches = allMatches.where((m) => (m.data() as Map)['stage'] == 'playoff').toList();
            final Map<String, int> matchNumById = {};
            final Map<String, String> catIdToName = { catId: catName ?? '' };
            for (var m in allMatches) { matchNumById[m.id] = (m.data() as Map)['match_number'] as int? ?? 0; }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (catName != null) Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(catName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.adminPrimary)),
                ),
                if (!hasMatches) ...[
                  if (teams.isEmpty)
                    const Padding(padding: EdgeInsets.all(24), child: Text("Ingen lag påmeldt i denne klassen."))
                  else
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.settings),
                        label: const Text("Gå til Oppsett (Trekning)"),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminPrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                        onPressed: () => _openSeedingSettings(catId, teams.length),
                      ),
                    ),
                ] else ...[
                  Row(
                    children: [
                      _buildOppsettSubTab("Seeding"),
                      const SizedBox(width: 8),
                      _buildOppsettSubTab("Gruppespill"),
                      const SizedBox(width: 8),
                      _buildOppsettSubTab("Sluttspill"),
                      const Spacer(),
                      if (_selectedOppsettTab == "Gruppespill" && groupMatches.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () => _generatePlayoffFromGroups(catId, teams.length),
                          icon: const Icon(Icons.emoji_events, size: 16),
                          label: const Text("Trekk Sluttspill"),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral, foregroundColor: Colors.white),
                        ),
                      if (_selectedOppsettTab == "Sluttspill" && playoffMatches.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () => _showAddWalkoverMatchDialog(catId),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text("Ny kamp"),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminPrimary, foregroundColor: Colors.white),
                        )
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_selectedOppsettTab == "Seeding") _buildSeedingView(teams, seedingMatches, catId, catIdToName, matchNumById),
                  if (_selectedOppsettTab == "Gruppespill") _buildGroupView(teams, groupMatches, catId, catIdToName, matchNumById),
                  if (_selectedOppsettTab == "Sluttspill") _buildPlayoffView(teams, playoffMatches, catId, catIdToName, matchNumById),
                ]
              ],
            );
          }
        );
      }
    );
  }
""";
        lines.replaceRange(i, end + 1, newCatOppsett.split('\n'));
      }
      break;
    }
  }

  file.writeAsStringSync(lines.join('\n'));
}
