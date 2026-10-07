import 'dart:io';

void main() {
  final file = File('lib/edit_tournament_page.dart');
  var text = file.readAsStringSync();
  
  text = text.replaceFirst(
    "class _CategoryAdminDialog extends StatelessWidget {\n  final String tournamentId;\n  const _CategoryAdminDialog({required this.tournamentId});",
    "class _CategoryAdminDialog extends StatelessWidget {\n  final String tournamentId;\n  final int courtsCount;\n  const _CategoryAdminDialog({required this.tournamentId, required this.courtsCount});"
  );
  
  text = text.replaceAll("class _CategoryAdminDialog extends StatelessWidget {\r\n  final String tournamentId;\r\n  const _CategoryAdminDialog({required this.tournamentId});",
  "class _CategoryAdminDialog extends StatelessWidget {\r\n  final String tournamentId;\r\n  final int courtsCount;\r\n  const _CategoryAdminDialog({required this.tournamentId, required this.courtsCount});");

  file.writeAsStringSync(text);
}
