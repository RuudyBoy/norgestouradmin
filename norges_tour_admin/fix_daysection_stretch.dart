import 'dart:io';

void main() {
  final file = File('lib/tournament_control_page.dart');
  var text = file.readAsStringSync();
  
  text = text.replaceFirst("              child: Column(\n                children: byTime[time]!.map", "              child: Column(\n                crossAxisAlignment: CrossAxisAlignment.stretch,\n                children: byTime[time]!.map");

  file.writeAsStringSync(text);
  print("Added crossAxisAlignment: stretch to _buildDaySection");
}
