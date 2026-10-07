import 'dart:io';
void main() {
  final file = File('lib/tournament_control_page.dart');
  var text = file.readAsStringSync();
  
  int start = text.indexOf("Widget _buildPublishButtonInline() {");
  int end = text.indexOf("  Widget _buildCategoryMenu() {");
  if (start != -1 && end != -1) {
    text = text.replaceRange(start, end, """  Widget _buildPublishButtonInline() {
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
    print("Button replaced.");
  }

  file.writeAsStringSync(text);
}
