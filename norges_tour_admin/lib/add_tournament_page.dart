import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddTournamentPage extends StatefulWidget {
  const AddTournamentPage({super.key});

  @override
  State<AddTournamentPage> createState() => _AddTournamentPageState();
}

class _AddTournamentPageState extends State<AddTournamentPage> {
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  int _courtsCount = 4;
  DateTime? _startDate;
  DateTime? _endDate;
  final List<Map<String, dynamic>> _categories = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? DateTime.now() : (_startDate ?? DateTime.now());
    final first = isStart ? DateTime(2024) : (_startDate ?? DateTime(2024));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _showAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    int maxTeams = 24;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text("Legg til klasse"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: "Klassenavn *",
                  hintText: "f.eks. Menn Elite",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: maxTeams,
                decoration: const InputDecoration(
                  labelText: "Maks antall lag",
                  border: OutlineInputBorder(),
                ),
                items: [8, 12, 16, 20, 24, 32, 40, 48]
                    .map((n) => DropdownMenuItem(value: n, child: Text("$n lag")))
                    .toList(),
                onChanged: (v) => setDlg(() => maxTeams = v ?? 24),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Avbryt")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) {
                  setState(() => _categories.add({'name': name, 'max_teams': maxTeams}));
                  Navigator.pop(ctx);
                }
              },
              child: const Text("Legg til"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _locationCtrl.text.trim().isEmpty ||
        _startDate == null ||
        _endDate == null) {
      _snack("Fyll ut navn, sted og begge datoer!");
      return;
    }
    if (_categories.isEmpty) {
      _snack("Legg til minst én klasse (f.eks. Menn Elite).");
      return;
    }

    String fmt(DateTime d) =>
        "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";

    try {
      final tourRef = await FirebaseFirestore.instance.collection('tournaments').add({
        'name': _nameCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'start_date': fmt(_startDate!),
        'end_date': fmt(_endDate!),
        'image_url': _imageUrlCtrl.text.trim(),
        'courts_count': _courtsCount,
        'status': 'upcoming',
        'created_at': FieldValue.serverTimestamp(),
      });

      final batch = FirebaseFirestore.instance.batch();
      for (final cat in _categories) {
        final catRef = FirebaseFirestore.instance.collection('categories').doc();
        batch.set(catRef, {
          'tournament_id': tourRef.id,
          'name': cat['name'],
          'max_teams': cat['max_teams'],
          'created_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (mounted) {
        _snack("Turnering og klasser opprettet!");
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _snack("Feil: $e");
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String _fmtDate(DateTime d) => "${d.day}.${d.month}.${d.year}";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ny Turnering"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionTitle("Turneringsinfo"),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Turneringsnavn *",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.emoji_events),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(
                    labelText: "Sted / By *",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _imageUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: "Bilde URL (valgfritt)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.image),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _courtsCount,
                  decoration: const InputDecoration(
                    labelText: "Antall baner",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.grid_view),
                  ),
                  items: [2, 3, 4, 5, 6, 8, 10, 12]
                      .map((n) => DropdownMenuItem(value: n, child: Text("$n baner")))
                      .toList(),
                  onChanged: (v) => setState(() => _courtsCount = v ?? 4),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(_startDate == null ? "Startdato *" : _fmtDate(_startDate!)),
                        onPressed: () => _pickDate(true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event, size: 16),
                        label: Text(_endDate == null ? "Sluttdato *" : _fmtDate(_endDate!)),
                        onPressed: () => _pickDate(false),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _sectionTitle("Klasser"),
                    ElevatedButton.icon(
                      onPressed: _showAddCategoryDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Legg til klasse"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_categories.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Ingen klasser lagt til enda.\nF.eks. \"Menn Elite\" eller \"Mixed Open\"",
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...List.generate(_categories.length, (i) {
                    final cat = _categories[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: Text("${i + 1}",
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        title: Text(cat['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Maks ${cat['max_teams']} lag"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => setState(() => _categories.removeAt(i)),
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 32),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text("OPPRETT TURNERING"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[900],
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      );
}
