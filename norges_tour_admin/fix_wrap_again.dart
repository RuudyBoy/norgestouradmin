import 'dart:io';

void main() {
  final file = File('lib/tournament_control_page.dart');
  var text = file.readAsStringSync();
  
  // Replace Wrap with Column in _buildDaySection
  int iWrap = text.indexOf("              child: Wrap(\n                spacing: 8, runSpacing: 8,");
  if (iWrap != -1) {
    text = text.replaceFirst("              child: Wrap(\n                spacing: 8, runSpacing: 8,", "              child: Column(");
    print("Wrap replaced with Column.");
  } else {
    print("Wrap not found.");
  }

  file.writeAsStringSync(text);
}
