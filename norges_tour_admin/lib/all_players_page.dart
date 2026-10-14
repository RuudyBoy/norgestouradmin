import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'admin_shell.dart';
import 'theme/app_colors.dart';
import 'theme/responsive_layout.dart';

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
    final TextEditingController top3Controller = TextEditingController(text: existingData?['top_3']?.toString() ?? '0');
    final TextEditingController firstPlacesController = TextEditingController(text: existingData?['first_places']?.toString() ?? '0');
    final TextEditingController rankingPointsController = TextEditingController(text: existingData?['ranking_points']?.toString() ?? '0');

    String? selectedPosition = existingData?['position'];
    final validPositions = ["Blokker", "Forsvar", "Allround"];
    if (!validPositions.contains(selectedPosition)) selectedPosition = null;

    String selectedGender = existingData?['gender']?.toString() ?? 'M';
    if (selectedGender != 'M' && selectedGender != 'K') {
      selectedGender = 'M';
    }

    showDialog(
      context: context,
      builder: (context) {
        // Vi bruker StatefulBuilder for å kunne oppdatere forhåndsvisningen av bildet
        // med en gang du limer inn URL-en.
        return StatefulBuilder(
          builder: (context, setState) {
            
            return AlertDialog(
              title: Text(docId != null ? "Rediger spiller" : "Registrer ny spiller"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- FORHÅNDSVISNING AV BILDE ---
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.adminTextSecondary,
                      backgroundImage: imageUrlController.text.isNotEmpty
                          ? NetworkImage(imageUrlController.text)
                          : null,
                      child: imageUrlController.text.isEmpty
                          ? const Icon(Icons.person, size: 40, color: AppColors.adminTextSecondary)
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
                    Row(children: [
                        Expanded(child: TextField(controller: top3Controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Topp 3"))),
                        const SizedBox(width: 16),
                        Expanded(child: TextField(controller: firstPlacesController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "1. plasser"))),
                    ]),
                    const SizedBox(height: 16),
                    TextField(controller: rankingPointsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Rankingpoeng")),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedGender,
                            decoration: const InputDecoration(labelText: "Kjønn"),
                            items: const [
                              DropdownMenuItem(value: 'M', child: Text("Mann")),
                              DropdownMenuItem(value: 'K', child: Text("Kvinne")),
                            ],
                            onChanged: (val) {
                              if (val != null) selectedGender = val;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedPosition,
                            decoration: const InputDecoration(labelText: "Posisjon"),
                            items: validPositions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                            onChanged: (val) {
                              selectedPosition = val;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // --- BILDE URL FELT ---
                    TextField(
                      controller: imageUrlController,
                      onChanged: (value) {
                        setState(() {});
                      },
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
                      int? top3 = int.tryParse(top3Controller.text);
                      int? firstPlaces = int.tryParse(firstPlacesController.text);
                      int? rankingPoints = int.tryParse(rankingPointsController.text);

                      Map<String, dynamic> playerData = {
                        'first_name': firstNameController.text,
                        'last_name': lastNameController.text,
                        'club': clubController.text,
                        'gender': selectedGender,
                        'height': height,
                        'position': selectedPosition ?? 'Ukjent',
                        'image_url': imageUrlController.text, // Lagrer bare teksten (URLen)
                        'top_3': top3 ?? 0,
                        'first_places': firstPlaces ?? 0,
                        'ranking_points': rankingPoints ?? 0,
                      };

                      if (docId != null) {
                        // OPPDATER
                        await FirebaseFirestore.instance.collection('players').doc(docId).update(playerData);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Oppdatert!")));
                      } else {
                        // NY
                        playerData['created_at'] = FieldValue.serverTimestamp();
                        await FirebaseFirestore.instance.collection('players').add(playerData);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registrert!")));
                      }
                      
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: docId != null ? AppColors.adminPrimaryHover : AppColors.green,
                    
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
        backgroundColor: AppColors.green,
        foregroundColor: AppColors.adminText,
        automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: "Gjør alle anonyme & legg til 20 tullespillere",
            onPressed: () async {
              final scaffold = ScaffoldMessenger.of(context);
              final random = Random();
              
              final maleNames = ["Lars", "Peder", "Ola", "Espen", "Kåre", "Jens", "Bjarne", "Simen", "Tore", "Gisle", "Knut", "Arne", "Bjørn", "Per", "Ole", "Hans", "Nils", "Jan", "Kjell", "Svein", "Geir", "Morten"];
              final femaleNames = ["Kari", "Marte", "Siri", "Nina", "Hanne", "Trine", "Lise", "Berit", "Inger", "Anna", "Eva", "Ida", "Linda", "Hilde", "Marianne", "Anita", "Bente", "Mona", "Heidi", "Tone"];
              final lastNames = ["Luring", "Karusell", "Ås", "Kirkerud", "Nordmann", "Askeladd", "Bentsen", "Snekker", "Jensen", "Nansen", "Betjent", "Håp", "Svingen", "Trapp", "Tang", "Lotte", "Gris", "Brun", "Knoph", "Isaksen", "Hansen", "Johansen", "Olsen", "Larsen", "Andersen", "Nilsen", "Pedersen", "Kristiansen", "Johnsen", "Karlsen"];

              WriteBatch batch = FirebaseFirestore.instance.batch();
              
              // 1. Endre eksisterende spillere (unntatt Christian Jørgensens ruud)
              final snap = await FirebaseFirestore.instance.collection('players').get();
              int nameIndex = 0;
              for (var doc in snap.docs) {
                final data = doc.data();
                final fName = data['first_name']?.toString().toLowerCase() ?? '';
                final lName = data['last_name']?.toString().toLowerCase() ?? '';
                
                if (fName.contains('christian') && (lName.contains('ruud') || lName.contains('jørgensen'))) {
                  continue; // La denne stå
                }
                
                final isMale = nameIndex % 2 == 0;
                final newFirst = isMale ? maleNames[random.nextInt(maleNames.length)] : femaleNames[random.nextInt(femaleNames.length)];
                final newLast = lastNames[random.nextInt(lastNames.length)];
                nameIndex++;
                
                batch.update(doc.reference, {
                  'first_name': newFirst,
                  'last_name': newLast,
                  'gender': isMale ? 'M' : 'K',
                });
              }

              // 2. Legg til 20 nye tullespillere (10 menn, 10 kvinner)
              for (int i = 0; i < 20; i++) {
                final isMale = i < 10;
                final fName = isMale ? maleNames[random.nextInt(maleNames.length)] : femaleNames[random.nextInt(femaleNames.length)];
                final lName = lastNames[random.nextInt(lastNames.length)];
                
                var docRef = FirebaseFirestore.instance.collection('players').doc();
                batch.set(docRef, {
                  "first_name": fName,
                  "last_name": lName,
                  "club": "Tulleklubb IL",
                  "gender": isMale ? 'M' : 'K',
                  "height": 180 + random.nextInt(20),
                  "position": random.nextBool() ? "Blokker" : "Forsvar",
                  "top_3": random.nextInt(10),
                  "first_places": random.nextInt(5),
                  "ranking_points": 500 + random.nextInt(1500),
                  "created_at": FieldValue.serverTimestamp(),
                  "image_url": "",
                });
              }

              await batch.commit();
              scaffold.showSnackBar(const SnackBar(content: Text("Anonymisert eksisterende og lagt til 20 tullespillere!")));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: AppColors.adminDanger),
            tooltip: "Slett alle spillere (Test)",
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Slett alle spillere?"),
                  content: const Text("Dette vil tømme databasen for spillere. Er du sikker?"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Avbryt")),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminDanger, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text("Slett alt"),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                final scaffold = ScaffoldMessenger.of(context);
                final snap = await FirebaseFirestore.instance.collection('players').get();
                WriteBatch batch = FirebaseFirestore.instance.batch();
                for (var doc in snap.docs) {
                  batch.delete(doc.reference);
                }
                await batch.commit();
                scaffold.showSnackBar(const SnackBar(content: Text("Alle spillere ble slettet!")));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.casino),
            tooltip: "Tilfeldigiser poeng (Test)",
            onPressed: () async {
              final scaffold = ScaffoldMessenger.of(context);
              final snap = await FirebaseFirestore.instance.collection('players').get();
              final random = Random();
              WriteBatch batch = FirebaseFirestore.instance.batch();
              for (var doc in snap.docs) {
                // Tilfeldig sum mellom 0 og 2000
                batch.update(doc.reference, {'ranking_points': random.nextInt(2000)});
              }
              await batch.commit();
              scaffold.showSnackBar(const SnackBar(content: Text("Alle spillere fikk tilfeldige poeng!")));
            },
          ),
        ],
      ),
      drawer: Responsive.isDesktopOrLarger(context)
          ? null
          : const AdminDrawer(selectedIndex: 1),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPlayerDialog(),
        label: const Text("Ny Spiller"),
        icon: const Icon(Icons.person_add),
        backgroundColor: AppColors.green,
        
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('players').orderBy('first_name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final players = snapshot.data?.docs ?? [];

          if (players.isEmpty) return const Center(child: Text("Ingen spillere i databasen."));

          return ResponsiveContainer.dashboard(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ResponsiveLayout.gridColumns(context, mobile: 1, tablet: 2, desktop: 3, ultrawide: 4),
                childAspectRatio: 3.5, // 3.5 looks like a good aspect ratio for ListTiles in a grid
                crossAxisSpacing: 16,
                mainAxisSpacing: 12,
                mainAxisExtent: 80, // Fixed height for cards
              ),
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
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    onTap: () => _showPlayerDialog(docId: docId, existingData: data),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: AppColors.green.withValues(alpha: 0.2),
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
                        const Icon(Icons.edit, color: AppColors.adminPrimary, size: 20),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete, color: AppColors.adminTextSecondary),
                          onPressed: () {
                             FirebaseFirestore.instance.collection('players').doc(docId).delete();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}