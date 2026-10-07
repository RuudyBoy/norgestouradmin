import 'dart:io';

void main() {
  final file = File('lib/tournament_control_page.dart');
  var text = file.readAsStringSync();
  
  // Hide top sub-menu bar
  text = text.replaceFirst("                // Top sub-menu bar\n                Container(", "                // Top sub-menu bar\n                if (_selectedCategoryId != 'all') Container(");
  
  int s = text.indexOf("                // Tab content");
  int e = text.indexOf("              ],\n            );\n          },\n        );", s);
  
  if (s != -1 && e != -1) {
    String newContent = """                // Tab content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!hasMatches) ...[
                          _buildSeedingCard(sortedTeams, hasMatches),
                          const SizedBox(height: 16),
                          if (_selectedCategoryId != 'all') _buildGenerateCard(),
                        ] else ...[
                          if (_selectedCategoryId == 'all') ...[
                            if (sortedGroups.isNotEmpty) _buildGroupPreviewCard(groupTeams, sortedGroups),
                            if (sortedGroups.isNotEmpty && hasPlayoffs) const SizedBox(height: 16),
                            if (hasPlayoffs) _buildPlayoffPreviewCard(allMatches, matchNumById),
                          ] else ...[
                            if (_selectedOppsettTab == 'Seeding')
                              _buildSeedingCard(sortedTeams, hasMatches),
                              
                            if (_selectedOppsettTab == 'Gruppespill' && sortedGroups.isNotEmpty)
                              _buildGroupPreviewCard(groupTeams, sortedGroups),
                              
                            if (_selectedOppsettTab == 'Sluttspill' && hasPlayoffs)
                              _buildPlayoffPreviewCard(allMatches, matchNumById),
                              
                            if (_selectedOppsettTab != 'Seeding' && _selectedOppsettTab != 'Gruppespill' && _selectedOppsettTab != 'Sluttspill')
                              const Center(child: Text("Ingen kamper i denne visningen.")),
                          ]
                        ]
                      ],
                    ),
                  ),
                ),
""";
    text = text.replaceRange(s, e, newContent);
    print("Fixed content");
  } else {
    print("Could not find range");
  }

  file.writeAsStringSync(text);
}
