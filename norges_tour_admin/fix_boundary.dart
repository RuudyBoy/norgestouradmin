import 'dart:io';

void main() {
  final file = File('lib/edit_tournament_page.dart');
  var lines = file.readAsLinesSync();
  
  int s = lines.indexWhere((l) => l.contains("Widget _buildCategoryScheduleSection() {"));
  if (s > 0 && lines[s-1].trim() == "") {
    if (lines[s-2].trim() == "}") {
      lines[s-2] = "";
      
      // Find end of _buildCategoryScheduleSection
      int e = lines.indexWhere((l) => l.contains("class _CategoryAdminDialog"), s);
      lines.insert(e - 1, "}");
      print("Fixed class boundary!");
    }
  }

  file.writeAsStringSync(lines.join('\n'));
}
