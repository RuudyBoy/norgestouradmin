import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme/app_colors.dart';
import 'theme/app_text_styles.dart';

class EditTournamentPage extends StatefulWidget {
  final String tournamentId;
  final Map<String, dynamic> initialData;

  const EditTournamentPage({
    super.key,
    required this.tournamentId,
    required this.initialData,
  });

  @override
  State<EditTournamentPage> createState() => _EditTournamentPageState();
}

class _EditTournamentPageState extends State<EditTournamentPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _imageUrlCtrl;
  late final TextEditingController _maxTotalCtrl;
  late final TextEditingController _customTypeCtrl;

  late int _courtsCount;
  late int _matchDurationMinutes;
  TimeOfDay? _startTime;
  late String _selectedTypeId;
  late bool _hasDivisionPlay;
  late int _div1Size;
  late String _tournamentStatus;
  late String _registrationStatus;

  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _registrationDeadline;
  TimeOfDay? _endTime;
  bool _isSaving = false;

  static const _typeLabels = {
    'nt_master': 'NT Master',
    'nt_open': 'NT Open',
    'nt_topp_x': 'NT Topp X',
    'rt_master': 'RT Master',
    'rt_open': 'RT Open',
    'nm': 'NM',
    'nm_jr': 'NM Junior',
    'king_queen': 'King & Queen',
    'custom': 'Egendefinert format',
  };

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _nameCtrl = TextEditingController(text: d['name'] ?? '');
    _locationCtrl = TextEditingController(text: d['location'] ?? '');
    _imageUrlCtrl = TextEditingController(text: d['image_url'] ?? '');
    _courtsCount = (d['courts_count'] as num?)?.toInt() ?? 4;
    _matchDurationMinutes = (d['match_duration_minutes'] as num?)?.toInt() ?? 60;
    _selectedTypeId = d['tournament_type'] as String? ?? 'nt_master';
    _hasDivisionPlay = d['has_division_play'] as bool? ?? true;
    _div1Size = (d['div1_size'] as num?)?.toInt() ?? 16;
    _tournamentStatus = d['status'] as String? ?? 'upcoming';
    _registrationStatus = d['registration_status'] as String? ?? 'open';

    // Parse dates DD.MM.YYYY
    _startDate = _parseDate(d['start_date']);
    _endDate = _parseDate(d['end_date']);
    _registrationDeadline = _parseDate(d['registration_deadline']);

    final rawStartTime = d['start_time'] as String?;
    if (rawStartTime != null) {
      final parts = rawStartTime.split(':');
      if (parts.length == 2) {
        _startTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
    
    final rawEndTime = d['end_time'] as String?;
    if (rawEndTime != null) {
      final parts = rawEndTime.split(':');
      if (parts.length == 2) {
        _endTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 17,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
    
    _maxTotalCtrl = TextEditingController(text: d['max_teams_total']?.toString() ?? '');
    _customTypeCtrl = TextEditingController(text: _selectedTypeId == 'custom' ? (d['tournament_type_label'] ?? '') : '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _imageUrlCtrl.dispose();
    _maxTotalCtrl.dispose();
    _customTypeCtrl.dispose();
    super.dispose();
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    try {
      final parts = raw.toString().split('.');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
    } catch (_) {}
    return null;
  }

  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";

  Future<void> _pickDate(String which) async {
    final now = DateTime.now();
    final initial = which == 'start'
        ? (_startDate ?? now)
        : which == 'end'
            ? (_endDate ?? _startDate ?? now)
            : (_registrationDeadline ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() {
      if (which == 'start') {
        _startDate = picked;
      } else if (which == 'end') {
        _endDate = picked;
      } else {
        _registrationDeadline = picked;
      }
    });
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack("Turneringsnavn kan ikke være tomt.");
      return;
    }
    if (_selectedTypeId == 'custom' && _customTypeCtrl.text.trim().isEmpty) {
      _snack("Navn på egendefinert format kan ikke være tomt.");
      return;
    }
    if (_startTime == null || _endTime == null) {
      _snack("Både starttid og sluttid må være valgt!");
      return;
    }
    int? mt = int.tryParse(_maxTotalCtrl.text.trim());
    if (mt == null) {
      _snack("Maks lag totalt må være et tall.");
      return;
    }
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .update({
        'name': _nameCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'image_url': _imageUrlCtrl.text.trim(),
        'courts_count': _courtsCount,
        'match_duration_minutes': _matchDurationMinutes,
        if (_startTime != null)
          'start_time': '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}',
        if (_endTime != null)
          'end_time': '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
        'max_teams_total': int.tryParse(_maxTotalCtrl.text.trim()),
        'tournament_type': _selectedTypeId,
        'tournament_type_label': _selectedTypeId == 'custom' ? _customTypeCtrl.text.trim() : (_typeLabels[_selectedTypeId] ?? _selectedTypeId),
        'has_division_play': _hasDivisionPlay,
        'div1_size': _hasDivisionPlay ? _div1Size : 0,
        'status': _tournamentStatus,
        'registration_status': _registrationStatus,
        if (_startDate != null) 'start_date': _fmtDate(_startDate!),
        if (_endDate != null) 'end_date': _fmtDate(_endDate!),
        if (_registrationDeadline != null)
          'registration_deadline': _fmtDate(_registrationDeadline!),
        'updated_at': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _snack("Turnering oppdatert!");
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _snack("Feil: $e");
        setState(() => _isSaving = false);
      }
    }
  }

  // ─── Klasse-administrasjon ─────────────────────────────────────────────────
  Future<void> _showCategoryAdmin() async {
    showDialog(
      context: context,
      builder: (ctx) => _CategoryAdminDialog(tournamentId: widget.tournamentId),
    );
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rediger turnering"),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.adminText)),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: Icon(Icons.save, color: Theme.of(context).colorScheme.primary),
              label: Text("Lagre", style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // ─── STATUS ──────────────────────────────────────────────────
              _section("Turneringsstatus"),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _statusCard(
                      "Turneringsstatus",
                      _tournamentStatus,
                      {'upcoming': 'Kommende', 'active': 'Pågår', 'finished': 'Avsluttet'},
                      {'upcoming': AppColors.adminOrange, 'active': AppColors.green, 'finished': AppColors.adminTextSecondary},
                      (v) => setState(() => _tournamentStatus = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statusCard(
                      "Påmelding",
                      _registrationStatus,
                      {'open': 'Åpen', 'closed': 'Lukket'},
                      {'open': AppColors.green, 'closed': AppColors.adminOrange},
                      (v) => setState(() => _registrationStatus = v),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // ─── GRUNNINFO ───────────────────────────────────────────────
              _section("Grunninfo"),
              const SizedBox(height: 12),
              _field(_nameCtrl, "Turneringsnavn *", Icons.emoji_events),
              const SizedBox(height: 10),
              _field(_locationCtrl, "Sted / By", Icons.location_on),
              const SizedBox(height: 10),
              _field(_imageUrlCtrl, "Bilde URL", Icons.image),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(child: _dateBtn("Startdato", _startDate, 'start')),
                  const SizedBox(width: 10),
                  Expanded(child: _dateBtn("Sluttdato", _endDate, 'end')),
                ],
              ),
              const SizedBox(height: 8),
              _dateBtn("Påmeldingsfrist", _registrationDeadline, 'deadline',
                  icon: Icons.lock_clock, color: AppColors.adminOrange),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // ─── TURNERINGSTYPE ──────────────────────────────────────────
              _section("Turneringstype"),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedTypeId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _typeLabels.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedTypeId = v ?? _selectedTypeId),
              ),
              if (_selectedTypeId == 'custom') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _customTypeCtrl,
                  decoration: const InputDecoration(
                    labelText: "Navn på format *",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // ─── FORMAT ──────────────────────────────────────────────────
              _section("Format & Baner"),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _courtsCount,
                      decoration: const InputDecoration(
                        labelText: "Antall baner",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.grid_view),
                      ),
                      items: [2, 3, 4, 5, 6, 8, 10, 12]
                          .map((n) =>
                              DropdownMenuItem(value: n, child: Text("$n baner")))
                          .toList(),
                      onChanged: (v) => setState(() => _courtsCount = v ?? 4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _matchDurationMinutes,
                      decoration: const InputDecoration(
                        labelText: "Tid per kamp",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.timer),
                      ),
                      items: const [
                        DropdownMenuItem(value: 40, child: Text("40 min")),
                        DropdownMenuItem(value: 50, child: Text("50 min")),
                        DropdownMenuItem(value: 60, child: Text("60 min")),
                      ],
                      onChanged: (v) =>
                          setState(() => _matchDurationMinutes = v ?? 60),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(
                        Icons.access_time,
                        size: 16,
                        color: _startTime != null ? AppColors.adminOrange : AppColors.adminTextSecondary,
                      ),
                      label: Text(
                        _startTime != null
                            ? 'Starttid: ${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                            : 'Starttid *',
                        style: TextStyle(
                          color: _startTime != null ? AppColors.adminOrange : AppColors.adminTextSecondary,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _startTime != null ? AppColors.adminOrange : AppColors.adminTextSecondary,
                        ),
                      ),
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
                        );
                        if (t != null) setState(() => _startTime = t);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(
                        Icons.access_time,
                        size: 16,
                        color: _endTime != null ? AppColors.adminOrange : AppColors.adminTextSecondary,
                      ),
                      label: Text(
                        _endTime != null
                            ? 'Sluttid: ${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
                            : 'Sluttid *',
                        style: TextStyle(
                          color: _endTime != null ? AppColors.adminOrange : AppColors.adminTextSecondary,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _endTime != null ? AppColors.adminOrange : AppColors.adminTextSecondary,
                        ),
                      ),
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: _endTime ?? const TimeOfDay(hour: 17, minute: 0),
                        );
                        if (t != null) setState(() => _endTime = t);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // ─── KAPASITET ─────────────────────────────────────────────
              _section("Kapasitet"),
              const SizedBox(height: 12),
              TextField(
                controller: _maxTotalCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Maks lag totalt",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.group),
                ),
              ),
              const SizedBox(height: 12),

              SwitchListTile(
                title: const Text("Divisjonsspill",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text("A/B/C-divisjoner basert på ranking"),
                value: _hasDivisionPlay,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _hasDivisionPlay = v),
              ),
              if (_hasDivisionPlay) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _div1Size,
                  decoration: const InputDecoration(
                    labelText: "Lag i 1. divisjon (A)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.looks_one),
                  ),
                  items: [8, 16, 24, 32]
                      .map((n) =>
                          DropdownMenuItem(value: n, child: Text("$n lag")))
                      .toList(),
                  onChanged: (v) => setState(() => _div1Size = v ?? 16),
                ),
              ],

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // ─── KLASSER ─────────────────────────────────────────────────
              _section("Klasser"),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _showCategoryAdmin,
                icon: const Icon(Icons.edit),
                label: const Text("Administrer klasser"),
              ),

              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text("LAGRE ENDRINGER"),
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
    );
  }

  Widget _section(String title) => Text(title,
      style: AppText.dispH2());

  Widget _field(TextEditingController ctrl, String label, IconData icon) =>
      TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
      );

  Widget _dateBtn(String label, DateTime? date, String which,
      {IconData icon = Icons.calendar_today, Color color = AppColors.adminTextSecondary}) =>
      OutlinedButton.icon(
        icon: Icon(icon, size: 15, color: date != null ? null : color),
        label: Text(
          date != null ? "$label: ${_fmtDate(date)}" : "$label (ikke satt)",
          style: TextStyle(color: date != null ? null : color),
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: date != null ? AppColors.adminTextSecondary : color),
        ),
        onPressed: () => _pickDate(which),
      );

  Widget _statusCard(
    String title,
    String current,
    Map<String, String> labels,
    Map<String, Color> colors,
    void Function(String) onChanged,
  ) {
    final color = colors[current] ?? AppColors.adminTextSecondary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
        color: color.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontSize: 11, color: AppColors.adminTextSecondary)),
          const SizedBox(height: 6),
          DropdownButton<String>(
            value: current,
            isDense: true,
            underline: const SizedBox(),
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 14),
            items: labels.entries
                .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value,
                        style: TextStyle(color: colors[e.key] ?? AppColors.adminTextSecondary))))
                .toList(),
            onChanged: (v) => v != null ? onChanged(v) : null,
          ),
        ],
      ),
    );
  }
}

// ─── Dialog: Administrer klasser ─────────────────────────────────────────────
class _CategoryAdminDialog extends StatelessWidget {
  final String tournamentId;
  const _CategoryAdminDialog({required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Klasser"),
      content: SizedBox(
        width: 400,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('categories')
              .where('tournament_id', isEqualTo: tournamentId)
              .snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                  height: 80, child: Center(child: CircularProgressIndicator()));
            }
            final cats = snap.data!.docs;
            if (cats.isEmpty) {
              return const Text("Ingen klasser registrert.");
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: cats.map((cat) {
                final d = cat.data() as Map<String, dynamic>;
                return ListTile(
                  dense: true,
                  title: Text(d['name'] ?? ''),
                  subtitle: Text("Maks ${d['max_teams'] ?? '-'} lag"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        tooltip: "Rediger",
                        onPressed: () => _editCategory(context, cat),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18, color: AppColors.adminOrange),
                        tooltip: "Slett",
                        onPressed: () => _deleteCategory(context, cat),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text("Lukk")),
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text("Ny klasse"),
          style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
          onPressed: () => _addCategory(context),
        ),
      ],
    );
  }

  void _editCategory(BuildContext context, DocumentSnapshot cat) {
    final d = cat.data() as Map<String, dynamic>;
    final nameCtrl = TextEditingController(text: d['name'] ?? '');
    final maxCtrl = TextEditingController(text: d['max_teams']?.toString() ?? '24');

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
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text("Avbryt")),
            ElevatedButton(
              onPressed: () async {
                int mt = int.tryParse(maxCtrl.text.trim()) ?? 24;
                await cat.reference
                    .update({'name': nameCtrl.text.trim(), 'max_teams': mt});
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text("Lagre"),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteCategory(BuildContext context, DocumentSnapshot cat) async {
    final d = cat.data() as Map<String, dynamic>;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Slett klasse"),
        content: Text("Slett \"${d['name']}\"? Dette fjerner ikke lag/kamper i klassen."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Avbryt")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.adminOrange, foregroundColor: AppColors.adminText),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Slett"),
          ),
        ],
      ),
    );
    if (ok == true) await cat.reference.delete();
  }

  void _addCategory(BuildContext context) {
    final nameCtrl = TextEditingController();
    int maxTeams = 24;

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
                        DropdownMenuItem(value: n, child: Text("$n lag")))
                    .toList(),
                onChanged: (v) => set(() => maxTeams = v ?? maxTeams),
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
