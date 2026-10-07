import 'dart:io';

void main() {
  final file = File('lib/tournament_control_page.dart');
  var lines = file.readAsLinesSync();

  // Fix 1: _buildOppsettSection / _buildOppsettWrapper for 'all'
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains("Widget _buildOppsettWrapper() {")) {
      var end = -1;
      for (var j = i; j < lines.length; j++) {
        if (lines[j].contains("if (_selectedCategoryId == null) {")) {
          lines[j] = "    if (_selectedCategoryId == null) {";
          lines[j+1] = '      return const Center(child: Text("Velg en klasse."));';
          lines[j+2] = "    }";
          lines.insert(j+3, "    if (_selectedCategoryId == 'all') {");
          lines.insert(j+4, "      return StreamBuilder<QuerySnapshot>(");
          lines.insert(j+5, "        stream: FirebaseFirestore.instance.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),");
          lines.insert(j+6, "        builder: (ctx, snap) {");
          lines.insert(j+7, "          if (!snap.hasData) return const Center(child: CircularProgressIndicator());");
          lines.insert(j+8, "          return ListView(");
          lines.insert(j+9, "            children: snap.data!.docs.map((doc) => _buildOppsettWrapperForCategory(doc.id, (doc.data() as Map)['name'])).toList(),");
          lines.insert(j+10, "          );");
          lines.insert(j+11, "        }");
          lines.insert(j+12, "      );");
          lines.insert(j+13, "    }");
          lines.insert(j+14, "    return _buildOppsettWrapperForCategory(_selectedCategoryId!, null);");
          lines.insert(j+15, "  }");
          lines.insert(j+16, "  Widget _buildOppsettWrapperForCategory(String categoryId, String? categoryName) {");
          
          for(var k = j+17; k < lines.length; k++) {
            if(lines[k].contains("stream: _matchesQuery()")) {
              lines[k] = "      stream: FirebaseFirestore.instance.collection('matches').where('tournament_id', isEqualTo: widget.tournamentId).where('category_id', isEqualTo: categoryId).snapshots(),";
              break;
            }
          }
          break;
        }
      }
      break;
    }
  }

  for(var i = 0; i < lines.length; i++) {
    if (lines[i].contains("import 'edit_tournament_page.dart';")) {
      lines[i] = "import 'edit_tournament_page.dart';\nimport 'schedule_logic.dart';";
      break;
    }
  }

  file.writeAsStringSync(lines.join('\n'));
}
