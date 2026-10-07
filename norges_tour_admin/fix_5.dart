import 'dart:io';
void main() {
  final file = File('lib/tournament_control_page.dart');
  var text = file.readAsStringSync();
  
  // 5. publish batch
  int pubStart = text.indexOf("Future<void> _publishCategory() async {");
  int pubEndStr = text.indexOf("void _deleteCategory() {");
  if (pubStart != -1 && pubEndStr != -1) {
    int pubEnd = text.lastIndexOf("  }\n\n", pubEndStr) + 4;
    text = text.replaceRange(pubStart, pubEnd, """  Future<void> _publishCategory() async {
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
    print("Fix 5a applied.");
  }

  // 6. inline publish button
  int btnStart = text.indexOf("Widget _buildPublishButtonInline() {");
  int btnEndStr = text.indexOf("Widget _buildCategoryMenu() {");
  if (btnStart != -1 && btnEndStr != -1) {
    int btnEnd = text.lastIndexOf("  }\n\n", btnEndStr) + 4;
    text = text.replaceRange(btnStart, btnEnd, """  Widget _buildPublishButtonInline() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).limit(1).snapshots(),
      builder: (ctx, snap) {
        bool isPub = false;
        if (snap.hasData && snap.data!.docs.isNotEmpty) {
          isPub = (snap.data!.docs.first.data() as Map)['published'] == true;
        }
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: isPub ? AppColors.adminSurfaceElevated : AppColors.coral,
            foregroundColor: isPub ? AppColors.adminTextSecondary : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          icon: Icon(isPub ? Icons.visibility_off : Icons.visibility, size: 20),
          label: Text(isPub ? "Skjul turnering" : "Publiser turnering offentlig"),
          onPressed: () { if (isPub) _unpublishCategory(); else _publishCategory(); },
        );
      },
    );
  }

""");
    print("Fix 5b applied.");
  }
  
  file.writeAsStringSync(text);
}
