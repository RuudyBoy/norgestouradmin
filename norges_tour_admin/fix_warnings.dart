import 'dart:io';

void main() {
  final file = File('lib/edit_tournament_page.dart');
  var text = file.readAsStringSync();
  text = text.replaceAll("selectedStart!.hour", "selectedStart.hour");
  text = text.replaceAll("selectedStart!.minute", "selectedStart.minute");
  file.writeAsStringSync(text);
}
