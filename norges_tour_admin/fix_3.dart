import 'dart:io';
void main() {
  final file = File('lib/tournament_control_page.dart');
  var text = file.readAsStringSync();
  
  // Wrap to Column in _buildDaySection
  int idx = text.indexOf("child: Wrap(");
  if (idx != -1) {
    int nextLine = text.indexOf("\n", idx);
    int spacingLine = text.indexOf("spacing:", nextLine);
    if (spacingLine != -1 && spacingLine - nextLine < 50) {
      text = text.replaceRange(idx, spacingLine, "child: Column(\n            ");
      int endSpacing = text.indexOf("\n", spacingLine);
      text = text.replaceRange(spacingLine, endSpacing, ""); // remove spacing line
      print("Fix 3 applied.");
    }
  }

  file.writeAsStringSync(text);
}
