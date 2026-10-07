import 'dart:io';
void main() {
  final file = File('lib/tournament_control_page.dart');
  var text = file.readAsStringSync();

  text = text.replaceFirst(
    "import 'edit_tournament_page.dart';",
    "import 'edit_tournament_page.dart';\nimport 'schedule_logic.dart';"
  );

  int start = text.indexOf("Future<void> _autoScheduleForCategory(");
  int endStr = text.indexOf("Future<void> _resetTournament() async {");
  if (start != -1 && endStr != -1) {
    // Find the last '  }' before endStr
    int end = text.lastIndexOf("  }", endStr);
    if (end != -1 && end > start) {
      String replacement = """  Future<void> _autoScheduleForCategory(
    String categoryId, {
    required int startMinutes,
    required int matchDurationMinutes,
    required int courtsCount,
    required String startDate,
    required String endDate,
    int breakBetweenRounds = 5,
  }) =>
      autoScheduleCategory(
        tournamentId: widget.tournamentId,
        categoryId: categoryId,
        startMinutes: startMinutes,
        matchDurationMinutes: matchDurationMinutes,
        courtsCount: courtsCount,
        startDate: startDate,
        endDate: endDate,
        breakBetweenRounds: breakBetweenRounds,
      );""";
      
      text = text.replaceRange(start, end + 3, replacement); // +3 to include "  }"
      print("Fix 2 applied.");
    }
  }

  file.writeAsStringSync(text);
}
