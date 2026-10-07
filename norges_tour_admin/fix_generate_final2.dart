import 'dart:io';

void main() {
  final file = File('lib/tournament_control_page.dart');
  var lines = file.readAsLinesSync();
  
  int s = lines.indexWhere((l) => l.contains("// Auto-schedule using custom start time"));
  int e = lines.indexWhere((l) => l.contains("Kampskjema tildelt automatisk"), s);
  
  if (s != -1 && e != -1) {
    String origAuto = """    // Auto-schedule if tournament has start_time configured
    final tourDoc = await FirebaseFirestore.instance.collection('tournaments').doc(widget.tournamentId).get();
    final td = tourDoc.data() ?? {};
    final startTimeStr = td['start_time'] as String?;
    if (startTimeStr != null && _selectedCategoryId != null) {
      final parts = startTimeStr.split(':');
      if (parts.length == 2) {
        final startMinutes = (int.tryParse(parts[0]) ?? 9) * 60 + (int.tryParse(parts[1]) ?? 0);
        final duration = (td['match_duration_minutes'] as num?)?.toInt() ?? 60;
        final courts = (td['courts_count'] as num?)?.toInt() ?? 4;
        final startDate = td['start_date'] as String? ?? 'Kampdag';
        final endDate = td['end_date'] as String? ?? startDate;
        await _autoScheduleForCategory(
          _selectedCategoryId!,
          startMinutes: startMinutes,
          matchDurationMinutes: duration,
          courtsCount: courts,
          startDate: startDate,
          endDate: endDate,
        );
        _snack("Kampskjema tildelt automatisk fra \$startTimeStr.");
      }
    }""";
    
    lines.replaceRange(s, e + 1, origAuto.split('\n'));
    print("Fixed auto schedule block");
  } else {
    print("Could not find auto schedule block");
  }

  file.writeAsStringSync(lines.join('\n'));
}
