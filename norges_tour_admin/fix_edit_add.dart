import 'dart:io';

void main() {
  final file = File('lib/edit_tournament_page.dart');
  var text = file.readAsStringSync();
  
  int sAdd = text.indexOf("  void _addCategory(BuildContext context) {");
  int eAdd = text.indexOf("  void _editCategory", sAdd);
  int eEdit = text.indexOf("  void _deleteCategory", eAdd);

  if (sAdd != -1 && eAdd != -1 && eEdit != -1) {
    String newMethods = """
  void _addCategory(BuildContext context) {
    final nameCtrl = TextEditingController();
    int maxTeams = 24;
    String selectedGender = 'Mix';
    
    List<int> selectedCourts = List.generate(courtsCount, (i) => i + 1);
    TimeOfDay? selectedStart;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text("Ny klasse"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: "Klassenavn", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: maxTeams,
                  decoration: const InputDecoration(labelText: "Maks lag", border: OutlineInputBorder()),
                  items: [8, 12, 16, 20, 24, 32, 40, 48, 64].map((n) => DropdownMenuItem(value: n, child: Text("\$n lag"))).toList(),
                  onChanged: (v) => set(() => maxTeams = v ?? maxTeams),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedGender,
                  decoration: const InputDecoration(labelText: "Kjnn (krav)", border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'M', child: Text("Menn")),
                    DropdownMenuItem(value: 'K', child: Text("Kvinner")),
                    DropdownMenuItem(value: 'Mix', child: Text("Mix (pen)")),
                  ],
                  onChanged: (v) => set(() => selectedGender = v ?? 'Mix'),
                ),
                const SizedBox(height: 16),
                const Text("Baner for denne klassen:", style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8,
                  children: List.generate(courtsCount, (i) {
                    final courtNum = i + 1;
                    final isSel = selectedCourts.contains(courtNum);
                    return FilterChip(
                      label: Text("Bane \$courtNum"),
                      selected: isSel,
                      onSelected: (val) {
                        set(() {
                          if (val) selectedCourts.add(courtNum);
                          else selectedCourts.remove(courtNum);
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 16),
                const Text("Første kamp starttid (valgfritt):", style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Text(selectedStart != null ? "\${selectedStart!.hour.toString().padLeft(2,'0')}:\${selectedStart!.minute.toString().padLeft(2,'0')}" : "Bruk turneringens standard", style: const TextStyle(fontSize: 14)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.access_time),
                      onPressed: () async {
                        final time = await showTimePicker(context: context, initialTime: selectedStart ?? const TimeOfDay(hour: 9, minute: 0));
                        if (time != null) set(() => selectedStart = time);
                      },
                    ),
                    if (selectedStart != null)
                      IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: () => set(() => selectedStart = null)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Avbryt")),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                
                Map<String, String> roundTimes = {};
                if (selectedStart != null) {
                  roundTimes['1'] = "\${selectedStart!.hour.toString().padLeft(2,'0')}:\${selectedStart!.minute.toString().padLeft(2,'0')}";
                }

                await FirebaseFirestore.instance.collection('categories').add({
                  'tournament_id': tournamentId,
                  'name': name,
                  'gender': selectedGender,
                  'max_teams': maxTeams,
                  'court_numbers': selectedCourts..sort(),
                  'round_start_times': roundTimes,
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

  void _editCategory(BuildContext context, DocumentSnapshot cat) {
    final d = cat.data() as Map<String, dynamic>;
    final nameCtrl = TextEditingController(text: d['name'] ?? '');
    final maxCtrl = TextEditingController(text: d['max_teams']?.toString() ?? '24');
    String selectedGender = d['gender'] ?? 'Mix';
    
    List<int> selectedCourts = (d['court_numbers'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.generate(courtsCount, (i) => i + 1);
    
    Map<String, dynamic> rt = d['round_start_times'] != null ? Map<String, dynamic>.from(d['round_start_times'] as Map) : {};
    TimeOfDay? selectedStart;
    if (rt['1'] != null) {
      final p = (rt['1'] as String).split(':');
      if (p.length == 2) selectedStart = TimeOfDay(hour: int.tryParse(p[0]) ?? 9, minute: int.tryParse(p[1]) ?? 0);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text("Rediger klasse"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: "Klassenavn", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Maks lag", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: ['M', 'K', 'Mix'].contains(selectedGender) ? selectedGender : 'Mix',
                  decoration: const InputDecoration(labelText: "Kjnn (krav)", border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'M', child: Text("Menn")),
                    DropdownMenuItem(value: 'K', child: Text("Kvinner")),
                    DropdownMenuItem(value: 'Mix', child: Text("Mix (pen)")),
                  ],
                  onChanged: (v) => set(() => selectedGender = v ?? 'Mix'),
                ),
                const SizedBox(height: 16),
                const Text("Baner for denne klassen:", style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8,
                  children: List.generate(courtsCount, (i) {
                    final courtNum = i + 1;
                    final isSel = selectedCourts.contains(courtNum);
                    return FilterChip(
                      label: Text("Bane \$courtNum"),
                      selected: isSel,
                      onSelected: (val) {
                        set(() {
                          if (val) selectedCourts.add(courtNum);
                          else selectedCourts.remove(courtNum);
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 16),
                const Text("Første kamp starttid (valgfritt):", style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Text(selectedStart != null ? "\${selectedStart!.hour.toString().padLeft(2,'0')}:\${selectedStart!.minute.toString().padLeft(2,'0')}" : "Bruk turneringens standard", style: const TextStyle(fontSize: 14)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.access_time),
                      onPressed: () async {
                        final time = await showTimePicker(context: context, initialTime: selectedStart ?? const TimeOfDay(hour: 9, minute: 0));
                        if (time != null) set(() => selectedStart = time);
                      },
                    ),
                    if (selectedStart != null)
                      IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: () => set(() => selectedStart = null)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Avbryt")),
            ElevatedButton(
              onPressed: () async {
                int mt = int.tryParse(maxCtrl.text.trim()) ?? 24;
                
                if (selectedStart != null) {
                  rt['1'] = "\${selectedStart!.hour.toString().padLeft(2,'0')}:\${selectedStart!.minute.toString().padLeft(2,'0')}";
                } else {
                  rt.remove('1');
                }

                await cat.reference.update({
                  'name': nameCtrl.text.trim(),
                  'max_teams': mt,
                  'gender': selectedGender,
                  'court_numbers': selectedCourts..sort(),
                  'round_start_times': rt,
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
    text = text.replaceRange(sAdd, eEdit, newMethods);
    print("Replaced add/edit successfully");
  } else {
    print("Could not find bounds");
  }
  file.writeAsStringSync(text);
}
