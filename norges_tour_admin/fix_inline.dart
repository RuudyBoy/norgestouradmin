import 'dart:io';

void main() {
  final file = File('lib/edit_tournament_page.dart');
  var lines = file.readAsLinesSync();

  // 1. Revert _addCategory to its original version
  int sAdd = lines.indexWhere((l) => l.contains("void _addCategory(BuildContext context) {"));
  int eAdd = lines.length - 1;

  // 2. Revert _editCategory to its original version
  int eEdit = lines.indexWhere((l) => l.contains("void _deleteCategory"));
  int sEdit = lines.indexWhere((l) => l.contains("void _editCategory("));

  String addContent = """
  void _addCategory(BuildContext context) {
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
  }
}
""";

  String editContent = """
  void _editCategory(BuildContext context, DocumentSnapshot cat) {
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
  }
""";

  // Replace add
  lines.replaceRange(sAdd, eAdd + 1, addContent.split('\n'));
  
  // Recalculate edit indices
  eEdit = lines.indexWhere((l) => l.contains("void _deleteCategory"));
  sEdit = lines.indexWhere((l) => l.contains("void _editCategory("));
  lines.replaceRange(sEdit, eEdit, editContent.split('\n'));

  // 3. Add _buildCategoryScheduleSection in _EditTournamentPageState
  int sKapasitet = lines.indexWhere((l) => l.contains("_section(\"Kapasitet\"),"));
  
  String scheduleSection = """
  Widget _buildCategoryScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section("Bane- og tidsoppsett per klasse"),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('categories')
              .where('tournament_id', isEqualTo: widget.tournamentId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final cats = snapshot.data!.docs;
            if (cats.isEmpty) {
              return const Text("Opprett klasser lengre ned p siden frst.", style: TextStyle(fontStyle: FontStyle.italic));
            }
            return Column(
              children: cats.map((cat) {
                final d = cat.data() as Map<String, dynamic>;
                final name = d['name'] ?? '';
                List<int> selectedCourts = (d['court_numbers'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.generate(_courtsCount, (i) => i + 1);
                
                Map<String, dynamic> rt = d['round_start_times'] != null ? Map<String, dynamic>.from(d['round_start_times'] as Map) : {};
                TimeOfDay? selectedStart;
                if (rt['1'] != null) {
                  final p = (rt['1'] as String).split(':');
                  if (p.length == 2) selectedStart = TimeOfDay(hour: int.tryParse(p[0]) ?? 9, minute: int.tryParse(p[1]) ?? 0);
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 16),
                        const Text("Baner for denne klassen:", style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: List.generate(_courtsCount, (i) {
                            final courtNum = i + 1;
                            final isSel = selectedCourts.contains(courtNum);
                            return FilterChip(
                              label: Text("Bane \$courtNum"),
                              selected: isSel,
                              onSelected: (val) async {
                                final newCourts = List<int>.from(selectedCourts);
                                if (val) newCourts.add(courtNum);
                                else newCourts.remove(courtNum);
                                newCourts.sort();
                                await cat.reference.update({'court_numbers': newCourts});
                              },
                            );
                          }),
                        ),
                        const SizedBox(height: 16),
                        const Text("Første kamp starttid (valgfritt):", style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(selectedStart != null ? "\${selectedStart!.hour.toString().padLeft(2,'0')}:\${selectedStart!.minute.toString().padLeft(2,'0')}" : "Bruk turneringens standard", style: const TextStyle(fontSize: 14)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.access_time),
                              onPressed: () async {
                                final time = await showTimePicker(context: context, initialTime: selectedStart ?? const TimeOfDay(hour: 9, minute: 0));
                                if (time != null) {
                                  rt['1'] = "\${time.hour.toString().padLeft(2,'0')}:\${time.minute.toString().padLeft(2,'0')}";
                                  await cat.reference.update({'round_start_times': rt});
                                }
                              },
                            ),
                            if (selectedStart != null)
                              IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: () async {
                                rt.remove('1');
                                await cat.reference.update({'round_start_times': rt});
                              }),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
      ],
    );
  }
""";

  lines.insert(sKapasitet, "              _buildCategoryScheduleSection(),");
  
  // find bottom of _EditTournamentPageState
  int eState = lines.indexWhere((l) => l.contains("class _CategoryAdminDialog extends StatelessWidget {"));
  // Insert before the class definition, which means after the last } of _EditTournamentPageState
  lines.insertAll(eState - 1, scheduleSection.split('\n'));
  
  file.writeAsStringSync(lines.join('\n'));
}
