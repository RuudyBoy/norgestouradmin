import 'dart:io';
void main() {
  final file = File('lib/tournament_control_page.dart');
  var text = file.readAsStringSync();
  text = text.replaceFirst("              child: Column(\n            spa\n", "              child: Column(\n");
  file.writeAsStringSync(text);
}
