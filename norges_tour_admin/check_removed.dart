import 'dart:io';
void main() {
  final file = File('lib/tournament_control_page.dart');
  var text = file.readAsStringSync();
  final cardRegex = RegExp(r"Widget _buildScheduleCard\([^]*?// ─── UI shell", multiLine: true);
  var match = cardRegex.firstMatch(text);
  if (match != null) {
    var removed = match.group(0)!;
    int open = removed.split('{').length - 1;
    int close = removed.split('}').length - 1;
    print("removed balance: ${open - close}");
  } else {
    print("Not found");
  }
}
