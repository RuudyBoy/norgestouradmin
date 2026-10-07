import 'dart:io';

void main() {
  final file = File('lib/edit_tournament_page.dart');
  var text = file.readAsStringSync();
  
  // Update _showCategoryAdmin
  text = text.replaceFirst(
    "builder: (ctx) => _CategoryAdminDialog(tournamentId: widget.tournamentId),",
    "builder: (ctx) => _CategoryAdminDialog(tournamentId: widget.tournamentId, courtsCount: _courtsCount),"
  );
  
  // Update _CategoryAdminDialog definition
  text = text.replaceFirst(
    "class _CategoryAdminDialog extends StatelessWidget {\n  final String tournamentId;\n  const _CategoryAdminDialog({required this.tournamentId});",
    "class _CategoryAdminDialog extends StatelessWidget {\n  final String tournamentId;\n  final int courtsCount;\n  const _CategoryAdminDialog({required this.tournamentId, required this.courtsCount});"
  );
  
  file.writeAsStringSync(text);
  print("Updated courtsCount passing");
}
