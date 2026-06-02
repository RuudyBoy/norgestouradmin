import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart'; // For å kunne navigere tilbake til Dashboard

class AllPlayersPage extends StatefulWidget {
  const AllPlayersPage({super.key});

  @override
  State<AllPlayersPage> createState() => _AllPlayersPageState();
}

class _AllPlayersPageState extends State<AllPlayersPage> {
  
  // --- FUNKSJON: LEGG TIL ELLER REDIGER SPILLER ---
  void _showPlayerDialog({String? docId, Map<String, dynamic>? existingData}) {
    
    final TextEditingController firstNameController = TextEditingController(text: existingData?['first_name']);
    final TextEditingController lastNameController = TextEditingController(text: existingData?['last_name']);
    final TextEditingController clubController = TextEditingController(text: existingData?['club']);
    final TextEditingController heightController = TextEditingController(text: existingData?['height']?.toString());
    final TextEditingController imageUrlController = TextEditingController(text: existingData?['image_url']);

    String? selectedPosition = existingData?['position'];
    final validPositions = ["Blokker", "Forsvar", "Allround"];
    if (!validPositions.contains(selectedPosition)) selectedPosition = null;

    showDialog(
      context: context,
      builder: (context) {
        // Vi bruker StatefulBuilder for å kunne oppdatere forhåndsvisningen av bildet
        // med en gang du limer inn URL-en.
        return StatefulBuilder(
          builder: (context, setState) {
            
            // En liten lytter som oppdaterer bildet når teksten endres
            imageUrlController.addListener(() {
               if (imageUrlController.text.isNotEmpty) {
                 setState(() {}); 
               }
            });

            return AlertDialog(
              title: Text(docId != null ? "Rediger spiller" : "Registrer ny spiller"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- FORHÅNDSVISNING AV BILDE ---
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: imageUrlController.text.isNotEmpty
                          ? NetworkImage(imageUrlController.text)
                          : null,
                      child: imageUrlController.text.isEmpty
                          ? const Icon(Icons.person, size: 40, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // --- FELTER ---
                    TextField(controller: firstNameController, decoration: const InputDecoration(labelText: "Fornavn")),
                    const SizedBox(height: 8),
                    TextField(controller: lastNameController, decoration: const InputDecoration(labelText: "Etternavn")),
                    const SizedBox(height: 16),
                    Row(children: [
                        Expanded(child: TextField(controller: clubController, decoration: const InputDecoration(labelText: "Klubb"))),
                        const SizedBox(width: 16),
                        Expanded(child: TextField(controller: heightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Høyde (cm)"))),
                    ]),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPosition,
                      decoration: const InputDecoration(labelText: "Posisjon"),
                      items: validPositions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (val) => selectedPosition = val,
                    ),
                    const SizedBox(height: 16),
                    
                    // --- BILDE URL FELT ---
                    TextField(
                      controller: imageUrlController,
                      decoration: const InputDecoration(
                        labelText: "Bilde URL (Lim inn lenke)",
                        hintText: "https://eksempel.no/bilde.jpg",
                        prefixIcon: Icon(Icons.link),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Avbryt"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (firstNameController.text.isNotEmpty && lastNameController.text.isNotEmpty) {
                      
                      int? height = int.tryParse(heightController.text);

                      Map<String, dynamic> playerData = {
                        'first_name': firstNameController.text,
                        'last_name': lastNameController.text,
                        'club': clubController.text,
                        'height': height,
                        'position': selectedPosition ?? 'Ukjent',
                        'image_url': imageUrlController.text, // Lagrer bare teksten (URLen)
                      };

                      if (docId != null) {
                        // OPPDATER
                        await FirebaseFirestore.instance.collection('players').doc(docId).update(playerData);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Oppdatert!")));
                      } else {
                        // NY
                        playerData['created_at'] = FieldValue.serverTimestamp();
                        await FirebaseFirestore.instance.collection('players').add(playerData);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registrert!")));
                      }
                      
                      if (mounted) Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: docId != null ? Colors.orange[800] : Colors.green[800],
                    foregroundColor: Colors.white,
                  ),
                  child: Text(docId != null ? "Oppdater" : "Lagre"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Spillerdatabase"),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.green[800]),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text("Spike Dunk Admin", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  Text("Spillerdatabase", style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events),
              title: const Text('Turneringer'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminDashboard()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Spillerdatabase'),
              selected: true,
              selectedTileColor: Colors.green[100],
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPlayerDialog(),
        label: const Text("Ny Spiller"),
        icon: const Icon(Icons.person_add),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('players').orderBy('first_name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final players = snapshot.data?.docs ?? [];

          if (players.isEmpty) return const Center(child: Text("Ingen spillere i databasen."));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: players.length,
            itemBuilder: (context, index) {
              final data = players[index].data() as Map<String, dynamic>;
              final docId = players[index].id;
              
              final firstName = data['first_name'] ?? '';
              final lastName = data['last_name'] ?? '';
              final club = data['club'] ?? '';
              final position = data['position'] ?? '';
              final imageUrl = data['image_url'] ?? '';

              return Card(
                child: ListTile(
                  onTap: () => _showPlayerDialog(docId: docId, existingData: data),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.green[100],
                    backgroundImage: (imageUrl.isNotEmpty) 
                        ? NetworkImage(imageUrl) 
                        : null,
                    child: (imageUrl.isEmpty) 
                        ? Text(firstName.isNotEmpty ? firstName[0] : "?") 
                        : null,
                  ),
                  title: Text("$firstName $lastName", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("$position ${club.isNotEmpty ? '• $club' : ''}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit, color: Colors.orange, size: 20),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.grey),
                        onPressed: () {
                           FirebaseFirestore.instance.collection('players').doc(docId).delete();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}