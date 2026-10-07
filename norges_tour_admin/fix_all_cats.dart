import 'dart:io';

void main() {
  final file = File('lib/tournament_control_page.dart');
  var lines = file.readAsLinesSync();

  int start = lines.indexWhere((l) => l.contains("Widget _buildOppsettWrapper() {"));
  if (start != -1) {
    for (int i = start; i < lines.length; i++) {
      if (lines[i].contains("if (_selectedCategoryId == null) {")) {
        lines[i] = "    if (_selectedCategoryId == null) {";
        lines[i+1] = '      return const Center(child: Text("Velg en klasse i menyen over."));';
        lines[i+2] = "    }";
        lines.insert(i+3, "    if (_selectedCategoryId == 'all') {");
        lines.insert(i+4, "      return StreamBuilder<QuerySnapshot>(");
        lines.insert(i+5, "        stream: FirebaseFirestore.instance.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),");
        lines.insert(i+6, "        builder: (ctx, snap) {");
        lines.insert(i+7, "          if (!snap.hasData) return const Center(child: CircularProgressIndicator());");
        lines.insert(i+8, "          final docs = snap.data!.docs;");
        lines.insert(i+9, "          if (docs.isEmpty) return const Center(child: Text(\"Ingen klasser funnet.\"));");
        lines.insert(i+10, "          return ListView(");
        lines.insert(i+11, "            children: docs.map((doc) => SizedBox(height: 800, child: _buildOppsettWrapperForCategory(doc.id, (doc.data() as Map)['name']))).toList(),");
        lines.insert(i+12, "          );");
        lines.insert(i+13, "        }");
        lines.insert(i+14, "      );");
        lines.insert(i+15, "    }");
        lines.insert(i+16, "    return _buildOppsettWrapperForCategory(_selectedCategoryId!, null);");
        lines.insert(i+17, "  }");
        lines.insert(i+18, "  Widget _buildOppsettWrapperForCategory(String categoryId, String? categoryName) {");
        
        for (int k = i + 19; k < lines.length; k++) {
          if (lines[k].contains("stream: _matchesQuery()")) {
            lines[k] = "      stream: FirebaseFirestore.instance.collection('matches').where('tournament_id', isEqualTo: widget.tournamentId).where('category_id', isEqualTo: categoryId).snapshots(),";
            if (lines[k+1].trim() == ".snapshots(),") {
              lines[k+1] = ""; 
            }
            break;
          }
        }
        
        for (int k = i + 19; k < lines.length; k++) {
          if (lines[k].contains("return Column(")) {
            // Find children: [
            for (int j = k + 1; j < lines.length; j++) {
              if (lines[j].contains("children: [")) {
                lines.insert(j + 1, "            if (categoryName != null) Padding(padding: const EdgeInsets.all(16), child: Text(categoryName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.adminPrimary))),");
                break;
              }
            }
            break;
          }
        }
        break;
      }
    }
  }
  
  // Teams Tab
  int teamsStart = lines.indexWhere((l) => l.contains("Widget _buildTeamsTab() {"));
  if (teamsStart != -1) {
    for (int i = teamsStart; i < lines.length; i++) {
      if (lines[i].contains("if (_selectedCategoryId == null) {")) {
        lines[i] = "    if (_selectedCategoryId == null) {";
        lines[i+1] = '      return const Center(child: Text("Velg en klasse i menyen over."));';
        lines[i+2] = "    }";
        lines.insert(i+3, "    if (_selectedCategoryId == 'all') {");
        lines.insert(i+4, "      return StreamBuilder<QuerySnapshot>(");
        lines.insert(i+5, "        stream: FirebaseFirestore.instance.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),");
        lines.insert(i+6, "        builder: (ctx, snap) {");
        lines.insert(i+7, "          if (!snap.hasData) return const Center(child: CircularProgressIndicator());");
        lines.insert(i+8, "          final docs = snap.data!.docs;");
        lines.insert(i+9, "          if (docs.isEmpty) return const Center(child: Text(\"Ingen klasser funnet.\"));");
        lines.insert(i+10, "          return ListView(");
        lines.insert(i+11, "            children: docs.map((doc) => SizedBox(height: 600, child: _buildTeamsTabForCategory(doc.id, (doc.data() as Map)['name']))).toList(),");
        lines.insert(i+12, "          );");
        lines.insert(i+13, "        }");
        lines.insert(i+14, "      );");
        lines.insert(i+15, "    }");
        lines.insert(i+16, "    return _buildTeamsTabForCategory(_selectedCategoryId!, null);");
        lines.insert(i+17, "  }");
        lines.insert(i+18, "  Widget _buildTeamsTabForCategory(String categoryId, String? categoryName) {");
        
        for (int k = i + 19; k < lines.length; k++) {
          if (lines[k].contains("stream: _teamsQuery()")) {
            lines[k] = "        stream: FirebaseFirestore.instance.collection('teams').where('tournament_id', isEqualTo: widget.tournamentId).where('category_id', isEqualTo: categoryId).snapshots(),";
            if (lines[k+1].trim() == ".snapshots(),") {
              lines[k+1] = ""; 
            }
            break;
          }
        }
        
        for (int k = i + 19; k < lines.length; k++) {
          if (lines[k].contains("return Column(")) {
            for (int j = k + 1; j < lines.length; j++) {
              if (lines[j].contains("children: [")) {
                lines.insert(j + 1, "            if (categoryName != null) Padding(padding: const EdgeInsets.all(16), child: Text(categoryName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.adminPrimary))),");
                break;
              }
            }
            break;
          }
        }
        break;
      }
    }
  }

  file.writeAsStringSync(lines.join('\n'));
}
