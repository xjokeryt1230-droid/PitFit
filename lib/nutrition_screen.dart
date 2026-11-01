import 'package:flutter/material.dart';
import 'barcode_scanner_screen.dart';
import 'nutrition_goals.dart';
import 'main.dart';
import 'nutrition_entry.dart';
import 'nutrition_service.dart';
import 'open_food_facts_service.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  final NutritionService _service = NutritionService();

  DateTime _selectedDay = DateUtils.dateOnly(DateTime.now());

  Future<void> _selectDay() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
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

    if (selected != null && mounted) {
      setState(() {
        _selectedDay = DateUtils.dateOnly(selected);
      });
    }
  }

  Future<void> _openEntryForm({NutritionEntry? entry}) async {
    final result = await showDialog<NutritionEntry>(
      context: context,
      builder: (_) => _NutritionEntryDialog(entry: entry),
    );

    if (result == null || !mounted) return;

    try {
      if (entry == null) {
        await _service.addEntry(result);
      } else {
        await _service.updateEntry(result);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            entry == null
                ? 'Posiłek został zapisany.'
                : 'Posiłek został zaktualizowany.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się zapisać posiłku: $e')),
      );
    }
  }

  Future<void> _deleteEntry(NutritionEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: pitFitCard,
        title: const Text('Usuń posiłek'),
        content: Text('Czy usunąć wpis „${entry.name}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _service.deleteEntry(entry.id);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Posiłek został usunięty.')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się usunąć posiłku: $e')),
      );
    }
  }

  Future<void> _openGoalsForm(NutritionGoals current) async {
    final result = await showDialog<NutritionGoals>(
      context: context,
      builder: (_) => _NutritionGoalsDialog(goals: current),
    );

    if (result == null || !mounted) return;

    try {
      await _service.saveGoals(result);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cele dzienne zostały zapisane.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się zapisać celów: $e')),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NutritionEntry>>(
      stream: _service.watchDay(_selectedDay),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: pitFitYellow,
                    size: 48,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Nie udało się wczytać dziennika',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sprawdź połączenie, logowanie i uprawnienia Firestore.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: pitFitYellow),
          );
        }

        final entries = snapshot.data!;
        final calories = entries.fold<double>(
          0,
          (sum, entry) => sum + entry.calories,
        );
        final protein = entries.fold<double>(
          0,
          (sum, entry) => sum + entry.protein,
        );
        final carbs = entries.fold<double>(
          0,
          (sum, entry) => sum + entry.carbs,
        );
        final fat = entries.fold<double>(0, (sum, entry) => sum + entry.fat);

        return Scaffold(
          backgroundColor: pitFitNavy,
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'nutrition_add_meal',
            onPressed: () => _openEntryForm(),
            backgroundColor: pitFitYellow,
            foregroundColor: pitFitNavy,
            elevation: 8,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Dodaj posiłek',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PITFIT / ODŻYWIANIE',
                          style: TextStyle(
                            color: pitFitYellow,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'Twój dziennik',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kontroluj swoje posiłki i zapisuj wpisy.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: pitFitYellow.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: pitFitYellow.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.restaurant_menu_rounded,
                      color: pitFitYellow,
                      size: 25,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Wybór dnia
              Material(
                color: pitFitCard,
                borderRadius: BorderRadius.circular(17),
                child: InkWell(
                  onTap: _selectDay,
                  borderRadius: BorderRadius.circular(17),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: pitFitYellow.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            color: pitFitYellow,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WYBRANY DZIEŃ',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(_selectedDay),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.edit_calendar_rounded,
                          color: pitFitYellow,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 17),

              // Podsumowanie dnia i cele
              StreamBuilder<NutritionGoals>(
                stream: _service.watchGoals(),
                builder: (context, goalsSnapshot) {
                  final goals = goalsSnapshot.data ?? NutritionGoals.defaults;

                  return Container(
                    padding: const EdgeInsets.all(19),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF26364B),
                          pitFitCard,
                          const Color(0xFF182333),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: pitFitYellow.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'PODSUMOWANIE DNIA',
                                style: TextStyle(
                                  color: pitFitYellow,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edytuj cele dzienne',
                              onPressed: () => _openGoalsForm(goals),
                              icon: const Icon(
                                Icons.tune_rounded,
                                color: pitFitYellow,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Zapisane wartości',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: pitFitNavy.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: pitFitYellow.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.local_fire_department_rounded,
                                  color: pitFitYellow,
                                  size: 27,
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'KALORIE',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.55,
                                        ),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${calories.round()} kcal',
                                      style: const TextStyle(
                                        color: pitFitYellow,
                                        fontSize: 25,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'z ${goals.calories.round()} kcal',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _GoalProgress(
                          label: 'Białko',
                          current: protein,
                          goal: goals.protein,
                          unit: 'g',
                        ),
                        const SizedBox(height: 17),
                        _GoalProgress(
                          label: 'Węglowodany',
                          current: carbs,
                          goal: goals.carbs,
                          unit: 'g',
                        ),
                        const SizedBox(height: 17),
                        _GoalProgress(
                          label: 'Tłuszcze',
                          current: fat,
                          goal: goals.fat,
                          unit: 'g',
                        ),
                        if (goalsSnapshot.hasError) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Nie udało się odczytać zapisanych celów. '
                            'Wyświetlono wartości domyślne.',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _openGoalsForm(goals),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: pitFitYellow,
                              side: BorderSide(
                                color: pitFitYellow.withValues(alpha: 0.45),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.edit_rounded, size: 17),
                            label: const Text('Edytuj cele dzienne'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 26),

              // Lista posiłków
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Twoje posiłki',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${entries.length} ${entries.length == 1 ? 'wpis' : 'wpisów'}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              if (entries.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    color: pitFitCard,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: pitFitYellow.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.no_meals_outlined,
                          color: pitFitYellow,
                          size: 31,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Twój dziennik jest pusty',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Dodaj pierwszy posiłek, aby pojawił się tutaj '
                        'wraz z zapisanymi wartościami.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 17),
                      FilledButton.icon(
                        onPressed: () => _openEntryForm(),
                        style: FilledButton.styleFrom(
                          backgroundColor: pitFitYellow,
                          foregroundColor: pitFitNavy,
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Dodaj posiłek'),
                      ),
                    ],
                  ),
                )
              else
                for (final mealType in NutritionEntry.mealTypes) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, top: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 21,
                          decoration: BoxDecoration(
                            color: pitFitYellow,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            mealType.toUpperCase(),
                            style: const TextStyle(
                              color: pitFitYellow,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.3,
                            ),
                          ),
                        ),
                        Text(
                          '${entries.where((entry) => entry.mealType == mealType).length}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...entries
                      .where((entry) => entry.mealType == mealType)
                      .map(
                        (entry) => Container(
                          margin: const EdgeInsets.only(bottom: 9),
                          decoration: BoxDecoration(
                            color: pitFitCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 7,
                            ),
                            leading: Container(
                              width: 43,
                              height: 43,
                              decoration: BoxDecoration(
                                color: pitFitYellow.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(
                                Icons.restaurant_rounded,
                                color: pitFitYellow,
                              ),
                            ),
                            title: Text(
                              entry.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${entry.portionGrams.toStringAsFixed(0)} g'
                                    '  ·  ${entry.calories.round()} kcal',
                                    style: const TextStyle(
                                      color: pitFitYellow,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'B: ${entry.protein.toStringAsFixed(1)} g'
                                    '  ·  W: ${entry.carbs.toStringAsFixed(1)} g'
                                    '  ·  T: ${entry.fat.toStringAsFixed(1)} g',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              iconColor: Colors.white70,
                              color: pitFitCard,
                              onSelected: (action) {
                                if (action == 'edit') {
                                  _openEntryForm(entry: entry);
                                } else if (action == 'delete') {
                                  _deleteEntry(entry);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit_outlined,
                                        color: pitFitYellow,
                                        size: 19,
                                      ),
                                      SizedBox(width: 9),
                                      Text('Edytuj'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                        size: 19,
                                      ),
                                      SizedBox(width: 9),
                                      Text('Usuń'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  if (!entries.any((entry) => entry.mealType == mealType))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 13, left: 14),
                      child: Text(
                        'Brak wpisów w tej sekcji',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.38),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 9),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _GoalProgress extends StatelessWidget {
  const _GoalProgress({
    required this.label,
    required this.current,
    required this.goal,
    required this.unit,
  });

  final String label;
  final double current;
  final double goal;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final progress = goal <= 0
        ? 0.0
        : (current / goal).clamp(0.0, 1.0).toDouble();

    final remaining = (goal - current).clamp(0.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${current.toStringAsFixed(1)} / ${goal.toStringAsFixed(1)} $unit',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(pitFitYellow),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          goal <= 0
              ? 'Nie ustawiono celu'
              : current >= goal
              ? 'Cel osiągnięty'
              : 'Pozostało ${remaining.toStringAsFixed(1)} $unit',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}

class _NutritionGoalsDialog extends StatefulWidget {
  const _NutritionGoalsDialog({required this.goals});

  final NutritionGoals goals;

  @override
  State<_NutritionGoalsDialog> createState() => _NutritionGoalsDialogState();
}

class _NutritionGoalsDialogState extends State<_NutritionGoalsDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;

  @override
  void initState() {
    super.initState();

    _calories = TextEditingController(text: _format(widget.goals.calories));
    _protein = TextEditingController(text: _format(widget.goals.protein));
    _carbs = TextEditingController(text: _format(widget.goals.carbs));
    _fat = TextEditingController(text: _format(widget.goals.fat));
  }

  double? _parse(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  String _format(double value) =>
      value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');

  @override
  void dispose() {
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final number = _parse(value ?? '');

    if (number == null || !number.isFinite) {
      return 'Wpisz prawidłową liczbę.';
    }
    if (number < 0) {
      return 'Cel nie może być ujemny.';
    }
    if (number > 1000000) {
      return 'Wartość jest zbyt duża.';
    }

    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      NutritionGoals(
        calories: _parse(_calories.text)!,
        protein: _parse(_protein.text)!,
        carbs: _parse(_carbs.text)!,
        fat: _parse(_fat.text)!,
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: _validate,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: pitFitCard,
      title: const Text('Cele dzienne'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Cele należy ustalać indywidualnie. '
                  'Zmiana kalorii nie zmienia automatycznie pozostałych wartości.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                _field(_calories, 'Kalorie (kcal)'),
                const SizedBox(height: 12),
                _field(_protein, 'Białko (g)'),
                const SizedBox(height: 12),
                _field(_carbs, 'Węglowodany (g)'),
                const SizedBox(height: 12),
                _field(_fat, 'Tłuszcze (g)'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: pitFitYellow,
            foregroundColor: pitFitNavy,
          ),
          child: const Text('Zapisz cele'),
        ),
      ],
    );
  }
}

class _NutritionEntryDialog extends StatefulWidget {
  const _NutritionEntryDialog({this.entry});

  final NutritionEntry? entry;

  @override
  State<_NutritionEntryDialog> createState() => _NutritionEntryDialogState();
}

class _NutritionEntryDialogState extends State<_NutritionEntryDialog> {
  final OpenFoodFactsService _foodService = OpenFoodFactsService();
  final _formKey = GlobalKey<FormState>();

  List<FoodProduct> _searchResults = [];
  FoodProduct? _selectedProduct;
  bool _searching = false;
  bool _lookingUpBarcode = false;
  String? _searchError;

  late final TextEditingController _nameController;
  late final TextEditingController _portionController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;

  late String _mealType;
  late DateTime _consumedAt;

  @override
  void initState() {
    super.initState();

    final entry = widget.entry;

    _nameController = TextEditingController(text: entry?.name ?? '');
    _portionController = TextEditingController(
      text: entry?.portionGrams.toString() ?? '',
    );
    _caloriesController = TextEditingController(
      text: entry?.calories.toString() ?? '',
    );
    _proteinController = TextEditingController(
      text: entry?.protein.toString() ?? '',
    );
    _carbsController = TextEditingController(
      text: entry?.carbs.toString() ?? '',
    );
    _fatController = TextEditingController(text: entry?.fat.toString() ?? '');

    _mealType = entry?.mealType ?? NutritionEntry.mealTypes.first;
    _consumedAt = entry?.consumedAt ?? DateTime.now();

    _portionController.addListener(_updateNutritionValues);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _portionController.removeListener(_updateNutritionValues);
    _portionController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _foodService.dispose();
    super.dispose();
  }

  double? _parseNumber(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  String? _validateNumber(
    String? value, {
    required String label,
    required bool mustBePositive,
  }) {
    final number = _parseNumber(value ?? '');

    if (number == null || !number.isFinite) {
      return 'Wpisz prawidłową liczbę.';
    }

    if (mustBePositive && number <= 0) {
      return '$label musi być większa od zera.';
    }

    if (!mustBePositive && number < 0) {
      return '$label nie może być ujemna.';
    }

    if (number > 1000000) {
      return 'Wartość jest zbyt duża.';
    }

    return null;
  }

  Future<void> _searchProducts() async {
    final query = _nameController.text.trim();

    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _searchError = 'Wpisz co najmniej 2 znaki.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _searching = true;
      _searchError = null;
      _searchResults = [];
    });

    try {
      final results = await _foodService.search(query);

      if (!mounted) return;

      setState(() {
        _searchResults = results;

        if (results.isEmpty) {
          _searchError =
              'Nie znaleziono produktów z kompletem wartości odżywczych.';
        }
      });
    } catch (e, stackTrace) {
      debugPrint('Błąd wyszukiwania produktów: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _searchError = 'Błąd wyszukiwania: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }
  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (code == null || !mounted) return;

    await _lookupBarcode(code);
  }

  Future<void> _lookupBarcode(String code) async {
    setState(() {
      _lookingUpBarcode = true;
      _searchError = null;
      _searchResults = [];
    });

    try {
      final product = await _foodService.getByBarcode(code);

      if (!mounted) return;

      if (product == null) {
        setState(() {
          _searchError =
              'Nie znaleziono produktu o kodzie $code. '
              'Wyszukaj go po nazwie albo wpisz wartości ręcznie.';
        });
        return;
      }

      _selectProduct(product);
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() => _searchError = e.message);
    } catch (e) {
      debugPrint('Błąd pobierania produktu po kodzie: $e');
      if (!mounted) return;
      setState(() {
        _searchError =
            'Nie udało się pobrać produktu. Sprawdź połączenie z internetem.';
      });
    } finally {
      if (mounted) {
        setState(() => _lookingUpBarcode = false);
      }
    }
  }
  void _selectProduct(FoodProduct product) {
    setState(() {
      _selectedProduct = product;
      _nameController.text = product.name;
      _searchResults = [];
      _searchError = null;
    });

    _updateNutritionValues();
  }

  void _updateNutritionValues() {
    final product = _selectedProduct;
    final grams = _parseNumber(_portionController.text);

    if (product == null || grams == null || grams <= 0) return;

    _caloriesController.text = product
        .forGrams(product.caloriesPer100g, grams)
        .toStringAsFixed(1);

    _proteinController.text = product
        .forGrams(product.proteinPer100g, grams)
        .toStringAsFixed(1);

    _carbsController.text = product
        .forGrams(product.carbsPer100g, grams)
        .toStringAsFixed(1);

    _fatController.text = product
        .forGrams(product.fatPer100g, grams)
        .toStringAsFixed(1);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    _updateNutritionValues();

    final entry = NutritionEntry(
      id: widget.entry?.id ?? '',
      name: _nameController.text.trim(),
      mealType: _mealType,
      portionGrams: _parseNumber(_portionController.text)!,
      calories: _parseNumber(_caloriesController.text)!,
      protein: _parseNumber(_proteinController.text)!,
      carbs: _parseNumber(_carbsController.text)!,
      fat: _parseNumber(_fatController.text)!,
      consumedAt: _consumedAt,
    );

    try {
      entry.validate();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }

    Navigator.of(context).pop(entry);
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _consumedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pl', 'PL'),
    );

    if (!mounted || date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_consumedAt),
    );

    if (!mounted || time == null) return;

    setState(() {
      _consumedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final productSelected = _selectedProduct != null;

    final dateLabel =
        '${_consumedAt.day.toString().padLeft(2, '0')}.'
        '${_consumedAt.month.toString().padLeft(2, '0')}.'
        '${_consumedAt.year}';

    final timeLabel =
        '${_consumedAt.hour.toString().padLeft(2, '0')}:'
        '${_consumedAt.minute.toString().padLeft(2, '0')}';

    return AlertDialog(
      backgroundColor: pitFitCard,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: pitFitYellow.withValues(alpha: 0.25)),
      ),
      titlePadding: const EdgeInsets.fromLTRB(22, 20, 14, 8),
      contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
      actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      title: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: pitFitYellow.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.restaurant_menu_rounded,
              color: pitFitYellow,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.entry == null ? 'Dodaj posiłek' : 'Edytuj posiłek',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'PITFIT / DZIENNIK ŻYWIENIA',
                  style: TextStyle(
                    color: pitFitYellow,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Zamknij',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Wyszukiwanie produktu
                const Text(
                  'PRODUKT',
                  style: TextStyle(
                    color: pitFitYellow,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameController,
                  maxLength: 120,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nazwa produktu',
                    hintText: 'Np. banan, jogurt naturalny',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: pitFitYellow,
                    ),
                    counterStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: pitFitNavy,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: pitFitYellow,
                        width: 1.4,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    if (_selectedProduct != null &&
                        value != _selectedProduct!.name) {
                      setState(() {
                        _selectedProduct = null;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Podaj nazwę produktu.';
                    }
                    return null;
                  },
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _searching ? null : _searchProducts,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF303D50),
                      foregroundColor: pitFitYellow,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: _searching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: pitFitYellow,
                            ),
                          )
                        : const Icon(Icons.travel_explore_rounded),
                    label: Text(
                      _searching
                          ? 'Wyszukiwanie produktów...'
                          : 'Szukaj w bazie produktów',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: (_searching || _lookingUpBarcode)
                        ? null
                        : _scanBarcode,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: pitFitYellow,
                      side: BorderSide(
                        color: pitFitYellow.withValues(alpha: 0.45),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: _lookingUpBarcode
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: pitFitYellow,
                            ),
                          )
                        : const Icon(Icons.qr_code_scanner_rounded),
                    label: Text(
                      _lookingUpBarcode
                          ? 'Pobieranie produktu...'
                          : 'Skanuj kod kreskowy',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Dane produktów: Open Food Facts',
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
                if (_searchError != null) ...[
                  const SizedBox(height: 9),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: Colors.orangeAccent.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      _searchError!,
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 13),
                  const Text(
                    'WYNIKI WYSZUKIWANIA',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 260),
                    decoration: BoxDecoration(
                      color: pitFitNavy,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Colors.white10),
                      itemBuilder: (context, index) {
                        final product = _searchResults[index];

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: pitFitYellow.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(
                              Icons.restaurant_rounded,
                              color: pitFitYellow,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.brand.isEmpty
                                      ? 'Marka nieznana'
                                      : product.brand,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${product.caloriesPer100g.toStringAsFixed(0)} kcal / 100 g',
                                  style: const TextStyle(
                                    color: pitFitYellow,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'B: ${product.proteinPer100g.toStringAsFixed(1)} g'
                                  ' · W: ${product.carbsPer100g.toStringAsFixed(1)} g'
                                  ' · T: ${product.fatPer100g.toStringAsFixed(1)} g',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          onTap: () => _selectProduct(product),
                        );
                      },
                    ),
                  ),
                ],

                // Wybrany produkt
                if (productSelected) ...[
                  const SizedBox(height: 13),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: pitFitYellow.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: pitFitYellow.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: pitFitYellow,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedProduct!.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedProduct!.brand.isEmpty
                                    ? 'Marka nieznana'
                                    : _selectedProduct!.brand,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                'Na 100 g: '
                                '${_selectedProduct!.caloriesPer100g.toStringAsFixed(0)} kcal'
                                ' · B: ${_selectedProduct!.proteinPer100g.toStringAsFixed(1)} g'
                                ' · W: ${_selectedProduct!.carbsPer100g.toStringAsFixed(1)} g'
                                ' · T: ${_selectedProduct!.fatPer100g.toStringAsFixed(1)} g',
                                style: const TextStyle(
                                  color: pitFitYellow,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Odłącz produkt',
                          onPressed: () {
                            setState(() => _selectedProduct = null);
                          },
                          icon: const Icon(Icons.close, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // Szczegóły posiłku
                const Text(
                  'SZCZEGÓŁY POSIŁKU',
                  style: TextStyle(
                    color: pitFitYellow,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 11),
                DropdownButtonFormField<String>(
                  initialValue: _mealType,
                  dropdownColor: pitFitCard,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Rodzaj posiłku',
                    prefixIcon: const Icon(
                      Icons.restaurant_menu_rounded,
                      color: pitFitYellow,
                    ),
                    filled: true,
                    fillColor: pitFitNavy,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: pitFitYellow),
                    ),
                  ),
                  items: NutritionEntry.mealTypes
                      .map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _mealType = value);
                    }
                  },
                ),
                const SizedBox(height: 13),
                _numberField(
                  controller: _portionController,
                  label: 'Porcja (g)',
                  positive: true,
                ),
                const SizedBox(height: 13),

                // Wartości odżywcze
                const Text(
                  'WARTOŚCI ODŻYWCZE',
                  style: TextStyle(
                    color: pitFitYellow,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 11),
                _numberField(
                  controller: _caloriesController,
                  label: 'Kalorie (kcal)',
                ),
                const SizedBox(height: 11),
                _numberField(
                  controller: _proteinController,
                  label: 'Białko (g)',
                ),
                const SizedBox(height: 11),
                _numberField(
                  controller: _carbsController,
                  label: 'Węglowodany (g)',
                ),
                const SizedBox(height: 11),
                _numberField(controller: _fatController, label: 'Tłuszcze (g)'),
                if (productSelected) ...[
                  const SizedBox(height: 9),
                  const Text(
                    'Wartości są obliczane na podstawie danych produktu '
                    'na 100 g. Możesz je ręcznie poprawić.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 19),

                // Data i godzina
                const Text(
                  'DATA I GODZINA',
                  style: TextStyle(
                    color: pitFitYellow,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 9),
                Material(
                  color: pitFitNavy,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: _pickDateTime,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            color: pitFitYellow,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  timeLabel,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.edit_calendar_rounded,
                            color: pitFitYellow,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj', style: TextStyle(color: Colors.white60)),
        ),
        FilledButton.icon(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: pitFitYellow,
            foregroundColor: pitFitNavy,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.check_rounded, size: 19),
          label: const Text(
            'Zapisz posiłek',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    bool positive = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: pitFitNavy,
        prefixIcon: const Icon(
          Icons.edit_outlined,
          color: pitFitYellow,
          size: 19,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: pitFitYellow, width: 1.4),
        ),
      ),
      validator: (value) =>
          _validateNumber(value, label: label, mustBePositive: positive),
    );
  }
}
