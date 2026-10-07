import 'dart:io';

void main() {
  final file = File('lib/edit_tournament_page.dart');
  var text = file.readAsStringSync();
  
  String addOld = """  void _addCategory(BuildContext context) {
    final nameCtrl = TextEditingController();
    int maxTeams = 24;
    String selectedGender = 'Mix';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text("Ny klasse"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: "Klassenavn", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: maxTeams,
                decoration: const InputDecoration(
                    labelText: "Maks lag", border: OutlineInputBorder()),
                items: [8, 12, 16, 20, 24, 32, 40, 48, 64]
                    .map((n) =>
                        DropdownMenuItem(value: n, child: Text("\$n lag")))
                    .toList(),
                onChanged: (v) => set(() => maxTeams = v ?? maxTeams),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedGender,
                decoration: const InputDecoration(
                    labelText: "Kjnn (krav)", border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'M', child: Text("Menn")),
                  DropdownMenuItem(value: 'K', child: Text("Kvinner")),
                  DropdownMenuItem(value: 'Mix', child: Text("Mix (pen)")),
                ],
                onChanged: (v) => set(() => selectedGender = v ?? 'Mix'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text("Avbryt")),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                await FirebaseFirestore.instance.collection('categories').add({
                  'tournament_id': tournamentId,
                  'name': name,
                  'gender': selectedGender,
                  'max_teams': maxTeams,
                  'created_at': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text("Legg til"),
            ),
          ],
        ),
      ),
    );
  }""";

  String editOld = """  void _editCategory(BuildContext context, DocumentSnapshot cat) {
    final d = cat.data() as Map<String, dynamic>;
    final nameCtrl = TextEditingController(text: d['name'] ?? '');
    final maxCtrl = TextEditingController(text: d['max_teams']?.toString() ?? '24');
    String selectedGender = d['gender'] ?? 'Mix';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text("Rediger klasse"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: "Klassenavn", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: maxCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: "Maks lag", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: ['M', 'K', 'Mix'].contains(selectedGender) ? selectedGender : 'Mix',
                decoration: const InputDecoration(
                    labelText: "Kjnn (krav)", border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'M', child: Text("Menn")),
                  DropdownMenuItem(value: 'K', child: Text("Kvinner")),
                  DropdownMenuItem(value: 'Mix', child: Text("Mix (pen)")),
                ],
                onChanged: (v) => set(() => selectedGender = v ?? 'Mix'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text("Avbryt")),
            ElevatedButton(
              onPressed: () async {
                int mt = int.tryParse(maxCtrl.text.trim()) ?? 24;
                await cat.reference.update({
                  'name': nameCtrl.text.trim(),
                  'max_teams': mt,
                  'gender': selectedGender,
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text("Lagre"),
            ),
          ],
        ),
      ),
    );
  }""";
  
  // Actually, I can just use a regex to match the methods exactly since encoding might mess up 'Kjønn (krav)'.
  print("Use regex or string replacements for add/edit");
}
