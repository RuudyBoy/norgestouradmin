import 'dart:io';

void main() {
  final file = File('lib/tournament_control_page.dart');
  var lines = file.readAsLinesSync();

  int start = lines.indexWhere((l) => l.contains("Widget _buildOppsettWrapper() {"));
  if (start != -1) {
    int end = -1;
    for (int i = start; i < lines.length; i++) {
      if (lines[i].contains("if (_selectedCategoryId == null) {")) {
        lines[i] = "    if (_selectedCategoryId == null) {";
        lines[i+1] = '      return const Center(child: Text("Velg en klasse."));';
        lines[i+2] = "    }";
        lines.insert(i+3, "    if (_selectedCategoryId == 'all') {");
        lines.insert(i+4, "      return StreamBuilder<QuerySnapshot>(");
        lines.insert(i+5, "        stream: FirebaseFirestore.instance.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),");
        lines.insert(i+6, "        builder: (ctx, snap) {");
        lines.insert(i+7, "          if (!snap.hasData) return const Center(child: CircularProgressIndicator());");
        lines.insert(i+8, "          return ListView(");
        lines.insert(i+9, "            children: snap.data!.docs.map((doc) => _buildOppsettWrapperForCategory(doc.id, (doc.data() as Map)['name'])).toList(),");
        lines.insert(i+10, "          );");
        lines.insert(i+11, "        }");
        lines.insert(i+12, "      );");
        lines.insert(i+13, "    }");
        lines.insert(i+14, "    return _buildOppsettWrapperForCategory(_selectedCategoryId!, null);");
        lines.insert(i+15, "  }");
        lines.insert(i+16, "  Widget _buildOppsettWrapperForCategory(String categoryId, String? categoryName) {");
        
        for (int k = i + 17; k < lines.length; k++) {
          if (lines[k].contains("stream: _matchesQuery()")) {
            lines[k] = "      stream: FirebaseFirestore.instance.collection('matches').where('tournament_id', isEqualTo: widget.tournamentId).where('category_id', isEqualTo: categoryId).snapshots(),";
            // Check if next line is .snapshots() from previous _matchesQuery().snapshots() chaining!
            if (lines[k+1].trim() == ".snapshots(),") {
              lines[k+1] = ""; // remove extra snapshots
            }
            break;
          }
        }
        
        // Find where StreamBuilder's builder function returns, to insert the category name header
        for (int k = i + 17; k < lines.length; k++) {
          if (lines[k].contains("return Column(")) {
            lines.insert(k + 1, "      children: [");
            lines.insert(k + 2, "        if (categoryName != null) Padding(padding: const EdgeInsets.all(16), child: Text(categoryName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),");
            lines.insert(k + 3, "        Expanded(child: Column("); // wrap the old Column in Expanded since it's now inside a ListView? Wait.
            // If the outer is a ListView, it doesn't need Expanded. It can just be Column.
            break;
          }
        }
        break;
      }
    }
  }

  file.writeAsStringSync(lines.join('\n'));
}
