import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddTournamentPage extends StatefulWidget {
  const AddTournamentPage({super.key});

  @override
  State<AddTournamentPage> createState() => _AddTournamentPageState();
}

class _AddTournamentPageState extends State<AddTournamentPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  
  // Nå har vi to dato-variabler
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  // Velg Startdato
  Future<void> _pickStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedStartDate = picked;
        // Nullstill sluttdato hvis den er før startdatoen (UX-forbedring)
        if (_selectedEndDate != null && _selectedEndDate!.isBefore(picked)) {
          _selectedEndDate = null;
        }
      });
    }
  }

  // Velg Sluttdato
  Future<void> _pickEndDate() async {
    if (_selectedStartDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Velg startdato først!")),
      );
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate!, // Start kalenderen på startdatoen
      firstDate: _selectedStartDate!,   // Kan ikke velge før startdatoen
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedEndDate = picked;
      });
    }
  }

  Future<void> _saveTournament() async {
    // 1. Sjekk at alt er fylt ut
    if (_nameController.text.isEmpty || 
        _locationController.text.isEmpty || 
        _selectedStartDate == null || 
        _selectedEndDate == null) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fyll ut navn, sted og begge datoer!")),
      );
      return;
    }

    // 2. Formater datoene pent (f.eks "20.11.2025")
    String start = "${_selectedStartDate!.day}.${_selectedStartDate!.month}.${_selectedStartDate!.year}";
    String end = "${_selectedEndDate!.day}.${_selectedEndDate!.month}.${_selectedEndDate!.year}";

    // 3. Lagre til Firebase
    await FirebaseFirestore.instance.collection('tournaments').add({
      'name': _nameController.text,
      'location': _locationController.text,
      'start_date': start,
      'end_date': end,  // <-- Nytt felt!
      'status': 'upcoming',
      'created_at': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Turnering opprettet!")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ny Turnering")),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32.0),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Opprett ny turnering", 
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 32),
                  
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Turneringsnavn",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.emoji_events),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: "Sted / By",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.map),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- DATO VELGERE ---
                  Row(
                    children: [
                      // Startdato
                      Expanded(
                        child: ListTile(
                          title: Text(
                            _selectedStartDate == null 
                                ? "Startdato" 
                                : "${_selectedStartDate!.day}/${_selectedStartDate!.month}"
                          ),
                          subtitle: const Text("Fra"),
                          leading: const Icon(Icons.calendar_today),
                          tileColor: Colors.grey[100],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onTap: _pickStartDate,
                        ),
                      ),
                      
                      const SizedBox(width: 16), // Mellomrom

                      // Sluttdato
                      Expanded(
                        child: ListTile(
                          title: Text(
                            _selectedEndDate == null 
                                ? "Sluttdato" 
                                : "${_selectedEndDate!.day}/${_selectedEndDate!.month}"
                          ),
                          subtitle: const Text("Til"),
                          leading: const Icon(Icons.event),
                          tileColor: Colors.grey[100],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onTap: _pickEndDate,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saveTournament,
                      icon: const Icon(Icons.save),
                      label: const Text("LAGRE TURNERING"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}