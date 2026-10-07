import 'dart:io';

void main() {
  final file = File('lib/tournament_control_page.dart');
  var lines = file.readAsLinesSync();
  
  for (int i = 2105; i < 2115; i++) {
    if (lines[i].trim() == "),") {
       lines[i] = "";
       print("Removed closing paren at $i");
       break;
    }
  }

  file.writeAsStringSync(lines.join('\n'));
}
