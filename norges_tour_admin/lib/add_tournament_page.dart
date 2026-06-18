import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme/app_colors.dart';
import 'theme/app_text_styles.dart';

// ─── Turneringstyper med metadata ──────────────────────────────────────────
class TournamentTypeConfig {
  final String id;
  final String label;
  final String shortLabel;
  final Color color;
  final int defaultMaxTeamsPerClass;
  final int defaultDiv1Size; // 0 = ingen divisjonsspill
  final String rankingCategory; // for poengberegning
  final String description;

  const TournamentTypeConfig({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.color,
    required this.defaultMaxTeamsPerClass,
    required this.defaultDiv1Size,
    required this.rankingCategory,
    required this.description,
  });
}

const _tournamentTypes = [
  TournamentTypeConfig(
    id: 'nt_master',
    label: 'NT Master',
    shortLabel: 'NT Master',
    color: Color(0xFF1565C0),
    defaultMaxTeamsPerClass: 64,
    defaultDiv1Size: 16,
    rankingCategory: 'NT Master sr',
    description: 'Norgestour Master – divisjonsspill, 16 lag i 1. div. Maks 64 lag.',
  ),
  TournamentTypeConfig(
    id: 'nt_open',
    label: 'NT Open',
    shortLabel: 'NT Open',
    color: Color(0xFF1976D2),
    defaultMaxTeamsPerClass: 32,
    defaultDiv1Size: 16,
    rankingCategory: 'RT Open sr og jr',
    description: 'Norgestour Open – 8 eller 16 lag i 1. div avhengig av påmeldte.',
  ),
  TournamentTypeConfig(
    id: 'nt_topp_x',
    label: 'NT Topp X',
    shortLabel: 'NT Topp X',
    color: Color(0xFF0288D1),
    defaultMaxTeamsPerClass: 24,
    defaultDiv1Size: 0,
    rankingCategory: 'NT Open',
    description: 'Norgestour Topp X – uten divisjonsspill.',
  ),
  TournamentTypeConfig(
    id: 'rt_master',
    label: 'RT Master',
    shortLabel: 'RT Master',
    color: Color(0xFF2E7D32),
    defaultMaxTeamsPerClass: 32,
    defaultDiv1Size: 8,
    rankingCategory: 'RT Master sr',
    description: 'Regional Tour Master – kan spilles med eller uten divisjonsspill.',
  ),
  TournamentTypeConfig(
    id: 'rt_open',
    label: 'RT Open',
    shortLabel: 'RT Open',
    color: Color(0xFF388E3C),
    defaultMaxTeamsPerClass: 24,
    defaultDiv1Size: 0,
    rankingCategory: 'RT Open sr og jr',
    description: 'Regional Tour Open – kan spilles med eller uten divisjonsspill.',
  ),
  TournamentTypeConfig(
    id: 'nm',
    label: 'Norgesmesterskap',
    shortLabel: 'NM',
    color: Color(0xFFB71C1C),
    defaultMaxTeamsPerClass: 48,
    defaultDiv1Size: 16,
    rankingCategory: 'NM Sr',
    description: 'NM – divisjonsspill ved flere enn 32 påmeldte.',
  ),
  TournamentTypeConfig(
    id: 'nm_jr',
    label: 'NM Junior',
    shortLabel: 'NM Jr',
    color: Color(0xFFE53935),
    defaultMaxTeamsPerClass: 32,
    defaultDiv1Size: 16,
    rankingCategory: 'NM jr',
    description: 'NM Junior (U19/U21).',
  ),
  TournamentTypeConfig(
    id: 'king_queen',
    label: 'King & Queen',
    shortLabel: 'K&Q',
    color: Color(0xFF6A1B9A),
    defaultMaxTeamsPerClass: 32,
    defaultDiv1Size: 0,
    rankingCategory: 'RT Open sr og jr',
    description: 'King & Queen of the Court – uten divisjonsspill.',
  ),
];

class AddTournamentPage extends StatefulWidget {
  const AddTournamentPage({super.key});

  @override
  State<AddTournamentPage> createState() => _AddTournamentPageState();
}

class _AddTournamentPageState extends State<AddTournamentPage> {
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();

  String _selectedTypeId = 'nt_master';
  int _courtsCount = 6;
  int _matchDurationMinutes = 60;
  bool _hasDivisionPlay = true;
  int _div1Size = 16;

  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _registrationDeadline;

  // 'men' | 'women' | 'both'
  String _genderSelection = 'both';

  TournamentTypeConfig get _selectedType =>
      _tournamentTypes.firstWhere((t) => t.id == _selectedTypeId);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  void _onTypeChanged(String? newId) {
    if (newId == null) return;
    final cfg = _tournamentTypes.firstWhere((t) => t.id == newId);
    setState(() {
      _selectedTypeId = newId;
      _hasDivisionPlay = cfg.defaultDiv1Size > 0;
      _div1Size = cfg.defaultDiv1Size > 0 ? cfg.defaultDiv1Size : 8;
      // Oppdater maks lag i kategorier til ny default hvis de ikke er endret
    });
  }

  Future<void> _pickDate(String which) async {
    final now = DateTime.now();
    DateTime initial;
    DateTime first;

    if (which == 'start') {
      initial = _startDate ?? now;
      first = DateTime(2024);
    } else if (which == 'end') {
      initial = _endDate ?? (_startDate ?? now);
      first = _startDate ?? DateTime(2024);
    } else {
      // registration deadline
      initial = _registrationDeadline ?? now;
      first = DateTime(2024);
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (which == 'start') {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
        } else if (which == 'end') {
          _endDate = picked;
        } else {
          _registrationDeadline = picked;
        }
      });
    }
  }

  List<String> get _categoryNames {
    if (_genderSelection == 'men') return ['Menn'];
    if (_genderSelection == 'women') return ['Damer'];
    return ['Menn', 'Damer'];
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _locationCtrl.text.trim().isEmpty ||
        _startDate == null ||
        _endDate == null) {
      _snack("Fyll ut navn, sted og begge datoer!");
      return;
    }
    if (_registrationDeadline == null) {
      _snack("Sett påmeldingsfrist!");
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
        'registration_deadline': fmt(_registrationDeadline!),
        'image_url': _imageUrlCtrl.text.trim(),
        'courts_count': _courtsCount,
        'tournament_type': _selectedTypeId,
        'tournament_type_label': _selectedType.label,
        'ranking_category': _selectedType.rankingCategory,
        'match_duration_minutes': _matchDurationMinutes,
        'has_division_play': _hasDivisionPlay,
        'div1_size': _hasDivisionPlay ? _div1Size : 0,
        'status': 'upcoming',
        'registration_status': 'open',
        'created_at': FieldValue.serverTimestamp(),
      });

      final batch = FirebaseFirestore.instance.batch();
      for (final name in _categoryNames) {
        final catRef = FirebaseFirestore.instance.collection('categories').doc();
        batch.set(catRef, {
          'tournament_id': tourRef.id,
          'name': name,
          'max_teams': _selectedType.defaultMaxTeamsPerClass,
          'tournament_type': _selectedTypeId,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (mounted) {
        _snack("Turnering opprettet! Påmelding er nå åpen.");
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
    final typeColor = _selectedType.color;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ny Turnering"),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── TURNERINGSTYPE ────────────────────────────────────────
                _sectionTitle("Turneringstype"),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tournamentTypes.map((t) {
                    final selected = t.id == _selectedTypeId;
                    return GestureDetector(
                      onTap: () => _onTypeChanged(t.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? t.color : AppColors.adminTextSecondary,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? t.color : AppColors.adminTextSecondary,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          t.shortLabel,
                          style: TextStyle(
                            color: selected ? AppColors.adminText : AppColors.adminTextSecondary,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: typeColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: typeColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedType.description,
                          style: TextStyle(color: typeColor, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 20),

                // ─── TURNERINGSINFO ────────────────────────────────────────
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

                // Datoer
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate('start'),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_today, size: 16),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _startDate == null ? "Startdato *" : _fmtDate(_startDate!),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate('end'),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.event, size: 16),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _endDate == null ? "Sluttdato *" : _fmtDate(_endDate!),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _registrationDeadline == null
                          ? AppColors.adminOrange
                          : AppColors.adminTextSecondary,
                    ),
                  ),
                  onPressed: () => _pickDate('deadline'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_clock, size: 16, color: AppColors.adminOrange),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _registrationDeadline == null
                              ? "Påmeldingsfrist *"
                              : "Frist: ${_fmtDate(_registrationDeadline!)}",
                          style: TextStyle(
                            color: _registrationDeadline == null ? AppColors.adminOrange : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 20),

                // ─── FORMAT-INNSTILLINGER ──────────────────────────────────
                _sectionTitle("Format & Baner"),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _courtsCount,
                        decoration: const InputDecoration(
                          labelText: "Antall baner",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.grid_view),
                        ),
                        items: [2, 3, 4, 5, 6, 8, 10, 12]
                            .map((n) => DropdownMenuItem(value: n, child: Text("$n baner")))
                            .toList(),
                        onChanged: (v) => setState(() => _courtsCount = v ?? 6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _matchDurationMinutes,
                        decoration: const InputDecoration(
                          labelText: "Tid per kamp",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.timer),
                        ),
                        items: [
                          const DropdownMenuItem(value: 40, child: Text("40 min")),
                          const DropdownMenuItem(value: 50, child: Text("50 min")),
                          const DropdownMenuItem(value: 60, child: Text("60 min")),
                        ],
                        onChanged: (v) => setState(() => _matchDurationMinutes = v ?? 60),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Divisjonsspill toggle
                if (_selectedType.id != 'nt_topp_x' &&
                    _selectedType.id != 'king_queen') ...[
                  SwitchListTile(
                    title: const Text("Divisjonsspill",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        "Del lag i A/B/C-divisjoner basert på ranking"),
                    value: _hasDivisionPlay,
                    activeColor: Theme.of(context).colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _hasDivisionPlay = v),
                  ),
                  if (_hasDivisionPlay) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _div1Size,
                      decoration: const InputDecoration(
                        labelText: "Lag i 1. divisjon (A)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.looks_one),
                        helperText:
                            "Seed 1–N går til 1. div, resten fordeles automatisk",
                      ),
                      items: [8, 16, 24, 32]
                          .map((n) =>
                              DropdownMenuItem(value: n, child: Text("$n lag")))
                          .toList(),
                      onChanged: (v) => setState(() => _div1Size = v ?? 16),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                      ),
                      child: Text(
                        "Lag seedes automatisk etter rankingpoeng:\n"
                        "• Seed 1–$_div1Size → 1. div (A)\n"
                        "• Seed ${_div1Size + 1}–${_div1Size * 2} → 2. div (B)\n"
                        "• Seed ${_div1Size * 2 + 1}+ → 3. div (C)\n"
                        "Puljevinner B-div spiller playoff mot taper A-div (opprykk/nedrykk).",
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 20),

                // ─── KJØNN ─────────────────────────────────────────────────
                _sectionTitle("Kjønn"),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _genderChip('men', 'Menn', Icons.male),
                    const SizedBox(width: 10),
                    _genderChip('women', 'Damer', Icons.female),
                    const SizedBox(width: 10),
                    _genderChip('both', 'Begge', Icons.people),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Oppretter automatisk: ${_categoryNames.join(' og ')}",
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),

                const SizedBox(height: 32),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text("OPPRETT TURNERING"),
                    style: ElevatedButton.styleFrom(
                      textStyle: AppText.uiCta,
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

  Widget _genderChip(String value, String label, IconData icon) {
    final selected = _genderSelection == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _genderSelection = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? Theme.of(context).colorScheme.primary : AppColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? AppColors.adminText : AppColors.adminTextSecondary, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.adminText : AppColors.adminTextSecondary,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: AppText.dispH2(),
      );
}
