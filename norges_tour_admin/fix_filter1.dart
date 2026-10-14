import 'dart:io';

void main() {
  final file = File('lib/tournament_control_page.dart');
  var text = file.readAsStringSync();
  
  // Remove _buildInlineCategoryFilter() and its SizedBox from _buildOppsettSectionForCategory
  text = text.replaceFirst("""                      _buildInlineCategoryFilter(),
                      const SizedBox(width: 16),""", "");

  // Now modify _buildOppsettSection to include it at the top
  String newOppsettSection = """  Widget _buildOppsettSection() {
    Widget content;
    if (_selectedCategoryId == null) {
      content = const Center(child: Text("Velg en klasse."));
    } else if (_selectedCategoryId == 'all') {
      content = StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('categories').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("Ingen klasser funnet."));
          return ListView(
            children: docs.map((doc) => SizedBox(height: 1000, child: _buildOppsettSectionForCategory(doc.id, (doc.data() as Map)['name']))).toList(),
          );
        }
      );
    } else {
      content = _buildOppsettSectionForCategory(_selectedCategoryId!, null);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
          child: _buildInlineCategoryFilter(),
        ),
        Expanded(child: content),
      ],
    );
  }""";

  int s = text.indexOf("  Widget _buildOppsettSection() {");
  int e = text.indexOf("  Widget _buildOppsettSectionForCategory(String categoryId, String? categoryName) {");
  if (s != -1 && e != -1) {
    text = text.replaceRange(s, e, "$newOppsettSection\n");
    print("OppsettSection updated.");
  }
  
  file.writeAsStringSync(text);
}
