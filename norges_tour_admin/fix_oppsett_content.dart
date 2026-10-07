import 'dart:io';

void main() {
  final file = File('lib/tournament_control_page.dart');
  var text = file.readAsStringSync();
  
  // Hide the Top sub-menu bar if _selectedCategoryId == 'all'
  text = text.replaceFirst("""                // Top sub-menu bar
                Container(""", """                // Top sub-menu bar
                if (_selectedCategoryId != 'all') Container(""");

  // Fix the content rendering
  String oldContent = """                Expanded(
                  child: (_selectedCategoryId == 'all')
                    ? const Center(child: Text("Velg en spesifikk klasse for  se puljeoppsett og sluttspill.", style: TextStyle(color: AppColors.adminTextSecondary, fontSize: 16)))
                    : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!hasMatches) ...[
                          _buildSeedingCard(sortedTeams, hasMatches),
                          const SizedBox(height: 16),
                          _buildGenerateCard(),
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
                      ],
                    ),
                  ),
                ),""";
  
  String newContent = """                Expanded(
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
                ),""";
                
  if (text.contains(oldContent)) {
    text = text.replaceFirst(oldContent, newContent);
    print("Fixed OppsettSection content rendering.");
  } else {
    print("Could not find oldContent.");
  }

  file.writeAsStringSync(text);
}
