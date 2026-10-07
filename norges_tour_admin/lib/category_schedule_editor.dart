import 'package:flutter/material.dart';
import 'schedule_logic.dart';
import 'theme/app_colors.dart';

/// Én klasse i editoren.
class ScheduleCategoryEntry {
  final String key;
  final String name;
  const ScheduleCategoryEntry(this.key, this.name);
}

/// Felles editor for baner og starttid per runde, per klasse.
/// Brukes både ved oppretting og redigering av turnering.
class CategoryScheduleEditor extends StatelessWidget {
  final List<ScheduleCategoryEntry> categories;
  final int courtsCount;
  final Map<String, CategorySchedule> value;
  final ValueChanged<Map<String, CategorySchedule>> onChanged;

  const CategoryScheduleEditor({
    super.key,
    required this.categories,
    required this.courtsCount,
    required this.value,
    required this.onChanged,
  });

  CategorySchedule _get(String k) => value[k] ?? const CategorySchedule();

  void _set(String k, CategorySchedule s) {
    final m = Map<String, CategorySchedule>.from(value);
    m[k] = s;
    onChanged(m);
  }

  /// Fordeler banene i sammenhengende blokker: 6 baner / 2 klasser → 1-3 og 4-6.
  void _splitEvenly() {
    final m = <String, CategorySchedule>{};
    final n = categories.length;
    final base = courtsCount ~/ n;
    final extra = courtsCount % n;
    int next = 1;
    for (int i = 0; i < n; i++) {
      final size = base + (i < extra ? 1 : 0);
      final courts = [for (int c = 0; c < size; c++) next + c];
      next += size;
      m[categories[i].key] = _get(categories[i].key).copyWith(courts: courts);
    }
    onChanged(m);
  }

  Future<void> _pickTime(BuildContext context, String catKey, String roundKey) async {
    final cur = parseHm(_get(catKey).roundTimes[roundKey]);
    final t = await showTimePicker(
      context: context,
      initialTime: cur != null
          ? TimeOfDay(hour: cur ~/ 60, minute: cur % 60)
          : const TimeOfDay(hour: 9, minute: 0),
    );
    if (t == null) return;
    final times = Map<String, String>.from(_get(catKey).roundTimes);
    times[roundKey] = fmtMinutes(t.hour * 60 + t.minute);
    _set(catKey, _get(catKey).copyWith(roundTimes: times));
  }

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    // Baner som er valgt av mer enn én klasse (kan gi overlapp hvis tidene er like)
    final usage = <int, int>{};
    for (final c in categories) {
      for (final n in _get(c.key).courts) {
        usage[n] = (usage[n] ?? 0) + 1;
      }
    }
    final shared = usage.entries.where((e) => e.value > 1).map((e) => e.key).toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Velg hvilke baner hver klasse spiller på og når hver runde starter. "
          "Gi klassene ulike baner for at de skal kunne spille samtidig. "
          "Ikke valgte baner = alle baner. Runder uten tid starter rett etter forrige runde.",
          style: TextStyle(fontSize: 12, color: AppColors.adminTextSecondary),
        ),
        const SizedBox(height: 8),
        if (categories.length > 1)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _splitEvenly,
              icon: const Icon(Icons.call_split, size: 16),
              label: const Text("Del baner likt mellom klassene"),
            ),
          ),
        const SizedBox(height: 8),
        for (final cat in categories) _card(context, cat),
        if (shared.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "Obs: Bane ${shared.join(', ')} er valgt av flere klasser. "
              "Sørg for at starttidene ikke overlapper.",
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
      ],
    );
  }

  Widget _card(BuildContext context, ScheduleCategoryEntry cat) {
    final s = _get(cat.key);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cat.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            const Text("Baner",
                style: TextStyle(fontSize: 12, color: AppColors.adminTextSecondary)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (int n = 1; n <= courtsCount; n++)
                  FilterChip(
                    label: Text("$n"),
                    selected: s.courts.contains(n),
                    onSelected: (sel) {
                      final courts = List<int>.from(s.courts);
                      sel ? courts.add(n) : courts.remove(n);
                      courts.sort();
                      _set(cat.key, s.copyWith(courts: courts));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text("Starttid per runde",
                style: TextStyle(fontSize: 12, color: AppColors.adminTextSecondary)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final rk in CategorySchedule.roundKeys)
                  _timeChip(context, cat.key, rk, s),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeChip(BuildContext context, String catKey, String rk, CategorySchedule s) {
    final t = s.roundTimes[rk];
    return InputChip(
      avatar: const Icon(Icons.access_time, size: 16),
      label: Text("${CategorySchedule.roundLabels[rk]}: ${t ?? 'auto'}"),
      onPressed: () => _pickTime(context, catKey, rk),
      onDeleted: t == null
          ? null
          : () {
              final times = Map<String, String>.from(s.roundTimes)..remove(rk);
              _set(catKey, s.copyWith(roundTimes: times));
            },
    );
  }
}
