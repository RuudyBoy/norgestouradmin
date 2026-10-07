import 'dart:io';

void main() {
  final file = File('lib/tournament_control_page.dart');
  var text = file.readAsStringSync();
  
  // 1. Remove the dialog wrapper method
  int s1 = text.indexOf("  Future<void> _generateGroupStage() async {");
  int e1 = text.indexOf("  Future<void> _executeGenerateGroupStage(int customStartMinutes, List<int> customCourts) async {");
  if (s1 != -1 && e1 != -1) {
    text = text.replaceRange(s1, e1, "");
  }
  
  // 2. Rename _executeGenerateGroupStage to _generateGroupStage
  text = text.replaceFirst("  Future<void> _executeGenerateGroupStage(int customStartMinutes, List<int> customCourts) async {", "  Future<void> _generateGroupStage() async {");

  // 3. Remove the category update logic
  String catUpdate = """      await FirebaseFirestore.instance.collection('categories').doc(_selectedCategoryId).set({
        'court_numbers': customCourts,
      }, SetOptions(merge: true));

""";
  text = text.replaceFirst(catUpdate, "");

  // 4. Restore the auto-schedule logic
  String customAuto = """    // Auto-schedule using custom start time
    final tourDoc = await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .get();
    final td = tourDoc.data() ?? {};
    final duration = (td['match_duration_minutes'] as num?)?.toInt() ?? 60;
    final startDate = td['start_date'] as String? ?? 'Kampdag';
    final endDate = td['end_date'] as String? ?? startDate;
    await _autoScheduleForCategory(
      _selectedCategoryId!,
      startMinutes: customStartMinutes,
      matchDurationMinutes: duration,
      courtsCount: customCourts.length,
      startDate: startDate,
      endDate: endDate,
    );
    _snack("Kampskjema tildelt automatisk.");""";
    
  String origAuto = """    // Auto-schedule if tournament has start_time configured
    final tourDoc = await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .get();
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
    
  if (text.contains(customAuto)) {
    text = text.replaceFirst(customAuto, origAuto);
    print("Fixed auto schedule block");
  } else {
    print("Could not find auto schedule block");
  }

  file.writeAsStringSync(text);
}
