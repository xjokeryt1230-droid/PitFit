import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart';

class _ResultItem {
  const _ResultItem({required this.details, required this.date});

  final String details;
  final DateTime? date;
}

class ExerciseHistoryScreen extends StatefulWidget {
  const ExerciseHistoryScreen({
    super.key,
    required this.exerciseName,
    required this.records,
  });

  final String exerciseName;
  final List<Map<String, Object?>> records;

  @override
  State<ExerciseHistoryScreen> createState() => _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState extends State<ExerciseHistoryScreen> {
  final TextEditingController _dateController = TextEditingController();
  late final List<_ResultItem> _items;
  DateTime? _selectedDay;
  String? _dateError;

  @override
  void initState() {
    super.initState();

    final items = widget.records.map((record) {
      final raw = record['recorded_at'];
      final weight = record['weight'] as num?;
      final reps = record['reps'] as num?;
      final duration = record['duration_seconds'] as num?;

      final details = <String>[];

      if (weight != null) {
        details.add('${weight.toString()} kg');
      }

      if (reps != null) {
        details.add('${reps.toInt()} powt.');
      }

      if (duration != null) {
        final seconds = duration.toInt();
        details.add('${seconds ~/ 60} min ${seconds % 60} s');
      }

      return _ResultItem(
        details: details.isEmpty ? 'Brak szczegółów' : details.join(' · '),
        date: raw is String ? DateTime.tryParse(raw)?.toLocal() : null,
      );
    }).toList();

    items.sort((a, b) {
      final dateA = a.date;
      final dateB = b.date;

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      return dateB.compareTo(dateA);
    });

    _items = items;
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  String _formatDay(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';

  String _formatDateTime(DateTime date) =>
      '${_formatDay(date)} · '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  List<_ResultItem> get _visible {
    final day = _selectedDay;
    if (day == null) return _items;

    return _items.where((item) {
      final date = item.date;
      return date != null &&
          date.year == day.year &&
          date.month == day.month &&
          date.day == day.day;
    }).toList();
  }

  void _onDateChanged(String value) {
    final text = value.trim();

    if (text.isEmpty) {
      setState(() {
        _selectedDay = null;
        _dateError = null;
      });
      return;
    }

    final match = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$').firstMatch(text);

    if (match == null) {
      setState(() {
        _selectedDay = null;
        _dateError =
            text.length >= 10 ? 'Wpisz datę w formacie DD.MM.RRRR.' : null;
      });
      return;
    }

    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);

    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      setState(() {
        _selectedDay = null;
        _dateError = 'Taka data nie istnieje.';
      });
      return;
    }

    setState(() {
      _selectedDay = parsed;
      _dateError = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pl', 'PL'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: pitFitYellow,
              onPrimary: pitFitNavy,
              surface: pitFitCard,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedDay = DateUtils.dateOnly(picked);
      _dateError = null;
      _dateController.text = _formatDay(picked);
    });
  }

  void _clear() {
    _dateController.clear();
    setState(() {
      _selectedDay = null;
      _dateError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final day = _selectedDay;

    final summary = day == null
        ? 'Wszystkie wyniki (${visible.length})'
        : 'Wyniki z ${_formatDay(day)} (${visible.length})';

    final emptyMessage = widget.records.isEmpty
        ? 'Nie zapisano jeszcze żadnych wyników.'
        : 'Brak wyników z tego dnia.';

    return Scaffold(
      backgroundColor: pitFitNavy,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historia wyników',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              widget.exerciseName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _dateController,
                    keyboardType: TextInputType.datetime,
                    maxLength: 10,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    style: const TextStyle(color: Colors.white),
                    onChanged: _onDateChanged,
                    decoration: InputDecoration(
                      labelText: 'Szukaj po dacie',
                      hintText: 'DD.MM.RRRR',
                      counterText: '',
                      errorText: _dateError,
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: pitFitYellow,
                      ),
                      suffixIcon: _dateController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Wyczyść',
                              onPressed: _clear,
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white60,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton.filled(
                    tooltip: 'Wybierz z kalendarza',
                    onPressed: _pickDate,
                    style: IconButton.styleFrom(
                      backgroundColor: pitFitYellow,
                      foregroundColor: pitFitNavy,
                      minimumSize: const Size(52, 52),
                    ),
                    icon: const Icon(Icons.calendar_month_rounded),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                summary,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        emptyMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      final date = item.date;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: pitFitCard,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.045),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: pitFitYellow.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(
                                Icons.trending_up_rounded,
                                color: pitFitYellow,
                                size: 23,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.details,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    date == null
                                        ? 'Data nieznana'
                                        : _formatDateTime(date),
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}