import 'dart:io';

void main() {
  final file = File('lib/tournament_control_page.dart');
  var lines = file.readAsLinesSync();
  
  if (lines[2109].trim() == "),") {
     lines[2109] = "";
     print("Removed extra closing paren at 2109");
  } else if (lines[2108].trim() == "),") {
     lines[2108] = "";
     print("Removed extra closing paren at 2108");
  }

  file.writeAsStringSync(lines.join('\n'));
}
