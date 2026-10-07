import 'dart:io';
void main() {
  final file = File('lib/tournament_control_page.dart');
  var text = file.readAsStringSync();
  
  int start = text.indexOf("Future<void> _publishCategory() async {");
  int end = text.indexOf("  String _oppsettRoundLabel(String r)");
  if (start != -1 && end != -1) {
    text = text.replaceRange(start, end, """  Future<void> _publishCategory() async {
    final snap = await FirebaseFirestore.instance.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snap.docs) { batch.update(doc.reference, {'published': true}); }
    await batch.commit();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hele turneringen er nå publisert offentlig')));
  }

  Future<void> _unpublishCategory() async {
    final snap = await FirebaseFirestore.instance.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snap.docs) { batch.update(doc.reference, {'published': false}); }
    await batch.commit();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hele turneringen er nå skjult')));
  }

""");
    print("Publish replaced.");
  }

  file.writeAsStringSync(text);
}
