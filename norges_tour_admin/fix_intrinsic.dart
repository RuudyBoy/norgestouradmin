import 'dart:io';

void main() {
  final file = File('lib/tournament_control_page.dart');
  var text = file.readAsStringSync();
  
  // Remove IntrinsicHeight and change stretch to start
  text = text.replaceFirst("        child: IntrinsicHeight(\n          child: Row(\n            crossAxisAlignment: CrossAxisAlignment.stretch,", "        child: Row(\n          crossAxisAlignment: CrossAxisAlignment.start,");
  // Also fix the right side Row that was stretch
  text = text.replaceFirst("                  child: Row(\n                    crossAxisAlignment: CrossAxisAlignment.stretch,", "                  child: Row(\n                    crossAxisAlignment: CrossAxisAlignment.center,");

  file.writeAsStringSync(text);
  print("Removed IntrinsicHeight and adjusted crossAxisAlignments.");
}
