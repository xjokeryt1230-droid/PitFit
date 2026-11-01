import 'dart:async';

import 'package:flutter/material.dart';

import 'workout_plan_service.dart';

const Color _yellow = Color(0xFFFFD54F);
const Color _navy = Color(0xFF101827);
const Color _card = Color(0xFF1C2738);

const List<String> _exerciseLibrary = [
  'Przysiady',
  'Pompki',
  'Wykroki',
  'Deska',
  'Most biodrowy',
  'Bird dog',
  'Brzuszki',
  'Podciąganie',
  'Wiosłowanie hantlami',
  'Uginanie ramion z hantlami',
  'Wyciskanie hantli',
  'Martwy ciąg z hantlami',
  'Pajacyki',
  'Marsz w miejscu',
  'Bieg w miejscu',
  'Skakanka',
  'Rozciąganie',
  'Własne ćwiczenie',
];

class WorkoutPlansScreen extends StatefulWidget {
  final String username;
  final Future<void> Function(String title)? onStartWorkout;

  const WorkoutPlansScreen({
    super.key,
    required this.username,
    this.onStartWorkout,
  });

  @override
  State<WorkoutPlansScreen> createState() => _WorkoutPlansScreenState();
}

class _WorkoutPlansScreenState extends State<WorkoutPlansScreen> {
  List<Map<String, Object?>> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await WorkoutPlanService.instance.getPlans(widget.username);

      if (!mounted) return;

      setState(() {
        _plans = plans;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);
      _message('Nie udało się wczytać planów: $e');
    }
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _createPlan() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _PlanNameDialog(
        title: 'Nowy plan',
        actionLabel: 'Utwórz',
        hintText: 'Np. Trening poniedziałkowy',
      ),
    );

    if (name == null || name.trim().isEmpty) return;

    try {
      await WorkoutPlanService.instance.createPlan(
        username: widget.username,
        name: name.trim(),
      );

      if (!mounted) return;

      await _loadPlans();
      _message('Plan został utworzony.');
    } catch (e) {
      _message('Nie udało się utworzyć planu: $e');
    }
  }

  Future<void> _openPlan(int planId) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return WorkoutPlanEditorScreen(
            username: widget.username,
            planId: planId,
            onStartWorkout: widget.onStartWorkout,
          );
        },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    if (mounted) await _loadPlans();
  }

  Future<void> _renamePlan(Map<String, Object?> plan) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _PlanNameDialog(
        title: 'Zmień nazwę planu',
        actionLabel: 'Zapisz',
        initialName: plan['name'] as String,
      ),
    );

    if (name == null || name.trim().isEmpty) return;

    try {
      await WorkoutPlanService.instance.renamePlan(
        planId: plan['id'] as int,
        username: widget.username,
        name: name.trim(),
      );

      if (!mounted) return;

      await _loadPlans();
      _message('Nazwa planu została zmieniona.');
    } catch (e) {
      _message('Nie udało się zmienić nazwy planu: $e');
    }
  }

  Future<void> _deletePlan(Map<String, Object?> plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Usunąć plan?'),
        content: Text(
          'Plan „${plan['name']}” i wszystkie jego ćwiczenia '
          'zostaną usunięte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await WorkoutPlanService.instance.deletePlan(
        planId: plan['id'] as int,
        username: widget.username,
      );

      if (!mounted) return;

      await _loadPlans();
      _message('Plan został usunięty.');
    } catch (e) {
      _message('Nie udało się usunąć planu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'workout_plans_new',
        onPressed: _createPlan,
        backgroundColor: _yellow,
        foregroundColor: _navy,
        elevation: 5,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'NOWY PLAN',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _yellow))
          : RefreshIndicator(
              color: _yellow,
              backgroundColor: _card,
              onRefresh: _loadPlans,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),
                children: [
                  // NAGŁÓWEK
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'STREFA TRENINGU',
                              style: TextStyle(
                                color: _yellow.withValues(alpha: 0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 7),
                            const Text(
                              'Moje plany',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 29,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _yellow.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: _yellow.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.fitness_center_rounded,
                          color: _yellow,
                          size: 25,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Twórz treningi, dobieraj ćwiczenia i układaj '
                    'własną kolejność.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // PANEL INFORMACYJNY
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF293A52), Color(0xFF172438), _navy],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: _yellow.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TWÓJ TRENING. TWOJE ZASADY.',
                                style: TextStyle(
                                  color: _yellow,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Buduj swoją formę krok po kroku.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                'Liczba Twoich planów: ${_plans.length}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.bolt_rounded,
                          color: _yellow.withValues(alpha: 0.9),
                          size: 43,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),

                  // LISTA PLANÓW
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Twoje treningi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${_plans.length} ${_plans.length == 1 ? 'plan' : 'planów'}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_plans.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 30,
                      ),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _yellow.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: _yellow.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.add_task_rounded,
                              color: _yellow,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Stwórz swój pierwszy plan!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 9),
                          const Text(
                            'Nadaj mu nazwę, dodaj ćwiczenia i '
                            'dopasuj trening do swoich potrzeb.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white60,
                              height: 1.5,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            'Użyj przycisku „Nowy plan”, aby zacząć.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _yellow,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._plans.asMap().entries.map((entry) {
                      final index = entry.key;
                      final plan = entry.value;
                      final id = plan['id'] as int;
                      final name = plan['name'] as String;
                      final count = plan['exercise_count'] as int;

                      final exerciseLabel = count == 1
                          ? 'ćwiczenie'
                          : count >= 2 && count <= 4
                          ? 'ćwiczenia'
                          : 'ćwiczeń';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 13),
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.07),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(19),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(19),
                            onTap: () => _openPlan(id),
                            child: Padding(
                              padding: const EdgeInsets.all(15),
                              child: Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: _yellow.withValues(alpha: 0.13),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: const Icon(
                                      Icons.fitness_center_rounded,
                                      color: _yellow,
                                      size: 25,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'PLAN ${index + 1}',
                                          style: const TextStyle(
                                            color: _yellow,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          '$count $exerciseLabel',
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Opcje planu',
                                    icon: const Icon(
                                      Icons.more_vert,
                                      color: Colors.white70,
                                    ),
                                    color: _card,
                                    onSelected: (action) {
                                      if (action == 'edit') {
                                        _openPlan(id);
                                      } else if (action == 'rename') {
                                        _renamePlan(plan);
                                      } else if (action == 'delete') {
                                        _deletePlan(plan);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text(
                                          'Edytuj plan',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'rename',
                                        child: Text(
                                          'Zmień nazwę',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text(
                                          'Usuń plan',
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: _yellow,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class WorkoutPlanEditorScreen extends StatefulWidget {
  final String username;
  final int planId;
  final Future<void> Function(String title)? onStartWorkout;

  const WorkoutPlanEditorScreen({
    super.key,
    required this.username,
    required this.planId,
    this.onStartWorkout,
  });

  @override
  State<WorkoutPlanEditorScreen> createState() =>
      _WorkoutPlanEditorScreenState();
}

class _WorkoutPlanEditorScreenState extends State<WorkoutPlanEditorScreen> {
  Map<String, Object?>? _plan;
  List<Map<String, Object?>> _exercises = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _loadPlan() async {
    try {
      final plan = await WorkoutPlanService.instance.getPlan(
        widget.planId,
        widget.username,
      );

      if (!mounted) return;

      if (plan == null) {
        setState(() => _loading = false);
        _message('Nie znaleziono planu.');
        Navigator.pop(context);
        return;
      }

      setState(() {
        _plan = plan;
        _exercises = (plan['exercises'] as List)
            .map((item) => Map<String, Object?>.from(item as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);
      _message('Nie udało się wczytać planu: $e');
    }
  }

  Future<void> _renamePlan() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _PlanNameDialog(
        title: 'Nazwa planu',
        actionLabel: 'Zapisz',
        initialName: _plan?['name'] as String? ?? '',
      ),
    );

    if (name == null || name.trim().isEmpty) return;

    try {
      await WorkoutPlanService.instance.renamePlan(
        planId: widget.planId,
        username: widget.username,
        name: name.trim(),
      );

      if (!mounted) return;

      await _loadPlan();
    } catch (e) {
      _message('Nie udało się zmienić nazwy planu: $e');
    }
  }

  Future<void> _editExercise({Map<String, Object?>? exercise}) async {
    final result = await showGeneralDialog<_ExerciseDraft>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Dialog ćwiczenia',
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: _ExerciseDialog(exercise: exercise),
          ),
        );
      },
    );

    if (result == null || !mounted) return;

    setState(() => _busy = true);

    try {
      if (exercise == null) {
        await WorkoutPlanService.instance.addExercise(
          planId: widget.planId,
          name: result.name,
          sets: result.sets,
          reps: result.reps,
          durationSeconds: result.durationSeconds,
          notes: result.notes,
          restSeconds: result.restSeconds,
        );
      } else {
        await WorkoutPlanService.instance.updateExercise(
          exerciseId: exercise['id'] as int,
          planId: widget.planId,
          name: result.name,
          sets: result.sets,
          reps: result.reps,
          durationSeconds: result.durationSeconds,
          notes: result.notes,
          restSeconds: result.restSeconds,
        );
      }

      await _loadPlan();
    } catch (e) {
      _message('Nie udało się zapisać ćwiczenia: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteExercise(Map<String, Object?> exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Usunąć ćwiczenie?'),
        content: Text('Usunąć „${exercise['name']}” z tego planu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await WorkoutPlanService.instance.deleteExercise(
        exerciseId: exercise['id'] as int,
        planId: widget.planId,
      );

      if (!mounted) return;

      await _loadPlan();
    } catch (e) {
      _message('Nie udało się usunąć ćwiczenia: $e');
    }
  }

  Future<void> _moveExercise(int index, int destination) async {
    if (destination < 0 || destination >= _exercises.length) return;

    try {
      await WorkoutPlanService.instance.moveExercise(
        planId: widget.planId,
        fromIndex: index,
        toIndex: destination,
      );

      if (!mounted) return;

      await _loadPlan();
    } catch (e) {
      _message('Nie udało się zmienić kolejności: $e');
    }
  }

  Future<void> _openRestTimer(Map<String, Object?> exercise) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _RestTimerDialog(
        exerciseName: exercise['name'] as String,
        initialSeconds: exercise['rest_seconds'] as int? ?? 90,
      ),
    );
  }

  int get _estimatedMinutes {
    var seconds = 0;

    for (final exercise in _exercises) {
      final duration = exercise['duration_seconds'] as int;
      final sets = exercise['sets'] as int;
      final reps = exercise['reps'] as int;
      final rest = exercise['rest_seconds'] as int? ?? 90;

      if (duration > 0) {
        seconds += duration * sets;
      } else {
        seconds += sets * reps * 4;
      }

      seconds += (sets - 1).clamp(0, 100) * rest;
    }

    return (seconds / 60).ceil();
  }

  Future<void> _finishPlan() async {
    final name = _plan?['name'] as String? ?? 'Mój trening';

    if (_exercises.isEmpty) {
      _message('Dodaj przynajmniej jedno ćwiczenie.');
      return;
    }

    if (widget.onStartWorkout != null) {
      await widget.onStartWorkout!(name);

      if (mounted) await _loadPlan();
    } else {
      _message('Plan jest gotowy do treningu.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _navy,
        body: Center(child: CircularProgressIndicator(color: _yellow)),
      );
    }

    if (_plan == null) {
      return const Scaffold(
        backgroundColor: _navy,
        body: Center(
          child: Text(
            'Nie znaleziono planu.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final planName = _plan!['name'] as String;

    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PITFIT  /  TRENING',
              style: TextStyle(
                color: _yellow,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              planName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Zmień nazwę planu',
            onPressed: _renamePlan,
            icon: const Icon(Icons.edit_outlined, color: _yellow),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'workout_editor_add_exercise',
        onPressed: _busy ? null : () => _editExercise(),
        backgroundColor: _yellow,
        foregroundColor: _navy,
        elevation: 4,
        icon: const Icon(Icons.add, size: 22),
        label: const Text(
          'DODAJ ĆWICZENIE',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6),
        ),
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator(color: _yellow))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
              children: [
                // Nagłówek planu
                const Text(
                  'TWÓJ PLAN',
                  style: TextStyle(
                    color: _yellow,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  planName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),

                // Podsumowanie planu
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF26364B), _card],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _yellow.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.insights_outlined,
                            color: _yellow,
                            size: 20,
                          ),
                          const SizedBox(width: 9),
                          const Expanded(
                            child: Text(
                              'PODSUMOWANIE',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.8,
                              ),
                            ),
                          ),
                          Text(
                            '${_exercises.length} ćwiczeń',
                            style: const TextStyle(
                              color: _yellow,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _summaryItem(
                              Icons.timer_outlined,
                              '$_estimatedMinutes min',
                              'SZACOWANY CZAS',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 42,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          Expanded(
                            child: _summaryItem(
                              Icons.fitness_center,
                              '${_exercises.length}',
                              'ĆWICZENIA',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Sekcja ćwiczeń
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PLAN TRENINGOWY',
                            style: TextStyle(
                              color: _yellow,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Kolejność ćwiczeń',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${_exercises.length.toString().padLeft(2, '0')} POZ.',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Wybierz ćwiczenie, aby edytować jego parametry. '
                  'Menu pozwala zmienić kolejność lub usunąć pozycję.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                if (_exercises.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 30,
                    ),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.fitness_center, color: _yellow, size: 38),
                        SizedBox(height: 14),
                        Text(
                          'ZACZNIJ BUDOWAĆ PLAN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Dodaj pierwsze ćwiczenie, aby przygotować '
                          'swój trening.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white60,
                            height: 1.5,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                ..._exercises.asMap().entries.map((entry) {
                  final index = entry.key;
                  final exercise = entry.value;

                  final duration = exercise['duration_seconds'] as int;
                  final sets = exercise['sets'] as int;
                  final reps = exercise['reps'] as int;
                  final rest = exercise['rest_seconds'] as int? ?? 90;
                  final notes = exercise['notes'] as String;

                  final prescription = duration > 0
                      ? '$sets ser.  ·  $duration s na serię'
                      : '$sets ser.  ×  $reps powt.';

                  return Container(
                    key: ValueKey(exercise['id']),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(17),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(17),
                        onTap: () => _editExercise(exercise: exercise),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(13, 14, 7, 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Numer ćwiczenia
                              Container(
                                width: 39,
                                height: 39,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _yellow,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${index + 1}'.padLeft(2, '0'),
                                  style: const TextStyle(
                                    color: _navy,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 13),

                              // Informacje o ćwiczeniu
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      exercise['name'] as String,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 9),
                                    Text(
                                      prescription,
                                      style: const TextStyle(
                                        color: _yellow,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.hourglass_bottom,
                                          size: 13,
                                          color: Colors.white54,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Przerwa: $rest s',
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (notes.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        notes,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Timer i menu
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Timer odpoczynku',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _openRestTimer(exercise),
                                    icon: const Icon(
                                      Icons.timer_outlined,
                                      color: _yellow,
                                      size: 21,
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Opcje ćwiczenia',
                                    icon: const Icon(
                                      Icons.more_vert,
                                      color: Colors.white70,
                                      size: 21,
                                    ),
                                    onSelected: (action) {
                                      if (action == 'edit') {
                                        _editExercise(exercise: exercise);
                                      } else if (action == 'delete') {
                                        _deleteExercise(exercise);
                                      } else if (action == 'up') {
                                        _moveExercise(index, index - 1);
                                      } else if (action == 'down') {
                                        _moveExercise(index, index + 1);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edytuj'),
                                      ),
                                      PopupMenuItem(
                                        value: 'up',
                                        enabled: index > 0,
                                        child: const Text('Przesuń wyżej'),
                                      ),
                                      PopupMenuItem(
                                        value: 'down',
                                        enabled: index < _exercises.length - 1,
                                        child: const Text('Przesuń niżej'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Usuń'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 16),

                // Zmiana nazwy
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  onPressed: _renamePlan,
                  icon: const Icon(Icons.drive_file_rename_outline),
                  label: const Text(
                    'ZMIENIAJ NAZWĘ PLANU',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Rozpoczęcie treningu
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _yellow,
                    foregroundColor: _navy,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  onPressed: _finishPlan,
                  icon: const Icon(Icons.play_arrow_rounded, size: 24),
                  label: const Text(
                    'ROZPOCZNIJ TRENING',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _summaryItem(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: _yellow, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExerciseDraft {
  final String name;
  final int sets;
  final int reps;
  final int durationSeconds;
  final int restSeconds;
  final String notes;

  const _ExerciseDraft({
    required this.name,
    required this.sets,
    required this.reps,
    required this.durationSeconds,
    required this.restSeconds,
    required this.notes,
  });
}

class _ExerciseDialog extends StatefulWidget {
  final Map<String, Object?>? exercise;

  const _ExerciseDialog({this.exercise});

  @override
  State<_ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends State<_ExerciseDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _customName;
  late final TextEditingController _sets;
  late final TextEditingController _reps;
  late final TextEditingController _duration;
  late final TextEditingController _restSeconds;
  late final TextEditingController _notes;

  late String _selectedName;
  late bool _timed;

  bool get _isCustom => _selectedName == 'Własne ćwiczenie';

  @override
  void initState() {
    super.initState();

    final exercise = widget.exercise;
    final existingName = exercise?['name'] as String?;

    _selectedName =
        existingName != null && _exerciseLibrary.contains(existingName)
        ? existingName
        : 'Własne ćwiczenie';

    _customName = TextEditingController(
      text: existingName != null && !_exerciseLibrary.contains(existingName)
          ? existingName
          : '',
    );

    _sets = TextEditingController(text: '${exercise?['sets'] ?? 3}');

    _reps = TextEditingController(text: '${exercise?['reps'] ?? 10}');

    _duration = TextEditingController(
      text: '${exercise?['duration_seconds'] ?? 0}',
    );

    _restSeconds = TextEditingController(
      text: '${exercise?['rest_seconds'] ?? 90}',
    );

    _notes = TextEditingController(text: exercise?['notes'] as String? ?? '');

    _timed = (exercise?['duration_seconds'] as int? ?? 0) > 0;
  }

  @override
  void dispose() {
    _customName.dispose();
    _sets.dispose();
    _reps.dispose();
    _duration.dispose();
    _restSeconds.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _validateNumber(String? value, {required int min, required int max}) {
    final number = int.tryParse(value ?? '');

    if (number == null || number < min || number > max) {
      return 'Wpisz liczbę od $min do $max.';
    }

    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _isCustom ? _customName.text.trim() : _selectedName;

    if (name.isEmpty || name == 'Własne ćwiczenie') return;

    Navigator.pop(
      context,
      _ExerciseDraft(
        name: name,
        sets: int.parse(_sets.text),
        reps: int.parse(_reps.text),
        durationSeconds: _timed ? int.parse(_duration.text) : 0,
        restSeconds: int.parse(_restSeconds.text),
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.exercise != null;

    InputDecoration fieldDecoration({
      required String label,
      String? hint,
      String? helper,
      IconData? icon,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        prefixIcon: icon == null ? null : Icon(icon, color: _yellow, size: 19),
        filled: true,
        fillColor: _navy,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
        helperStyle: const TextStyle(color: Colors.white54, fontSize: 11),
        counterStyle: const TextStyle(color: Colors.white38),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _yellow, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      );
    }

    return AlertDialog(
      backgroundColor: _card,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: _yellow.withValues(alpha: 0.18)),
      ),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
      contentPadding: const EdgeInsets.fromLTRB(22, 10, 22, 8),
      actionsPadding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _yellow.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              isEditing ? Icons.edit_outlined : Icons.fitness_center,
              color: _yellow,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PITFIT  /  PLAN TRENINGOWY',
                  style: TextStyle(
                    color: _yellow,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEditing ? 'Edytuj ćwiczenie' : 'Dodaj ćwiczenie',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'WYBIERZ ĆWICZENIE',
                  style: TextStyle(
                    color: _yellow,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 9),

                DropdownButtonFormField<String>(
                  initialValue: _selectedName,
                  isExpanded: true,
                  dropdownColor: _card,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: fieldDecoration(
                    label: 'Biblioteka ćwiczeń',
                    icon: Icons.fitness_center,
                  ),
                  items: _exerciseLibrary.map((name) {
                    return DropdownMenuItem(
                      value: name,
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedName = value);
                  },
                ),

                if (_isCustom) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customName,
                    autofocus: false,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(color: Colors.white),
                    decoration: fieldDecoration(
                      label: 'Nazwa własnego ćwiczenia',
                      hint: 'Wpisz nazwę',
                      icon: Icons.edit_outlined,
                    ),
                    validator: (value) {
                      if (_isCustom &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Wpisz nazwę ćwiczenia.';
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 22),
                const Text(
                  'PARAMETRY TRENINGU',
                  style: TextStyle(
                    color: _yellow,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _sets,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: fieldDecoration(
                    label: 'Liczba serii',
                    hint: 'Np. 3',
                    icon: Icons.repeat,
                  ),
                  validator: (value) =>
                      _validateNumber(value, min: 1, max: 100),
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _restSeconds,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: fieldDecoration(
                    label: 'Odpoczynek między seriami (sekundy)',
                    hint: 'Np. 90',
                    helper: 'Wpisz 0, aby wyłączyć odpoczynek.',
                    icon: Icons.hourglass_bottom,
                  ),
                  validator: (value) =>
                      _validateNumber(value, min: 0, max: 3600),
                ),

                const SizedBox(height: 18),

                // Przełącznik ćwiczenia na czas
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _timed
                          ? _yellow.withValues(alpha: 0.45)
                          : Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _timed,
                    activeThumbColor: _yellow,
                    activeTrackColor: _yellow.withValues(alpha: 0.3),
                    inactiveThumbColor: Colors.white70,
                    inactiveTrackColor: Colors.white12,
                    title: const Text(
                      'Ćwiczenie na czas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: const Text(
                      'Np. deska lub marsz',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    secondary: const Icon(Icons.timer_outlined, color: _yellow),
                    onChanged: (value) {
                      setState(() => _timed = value);
                    },
                  ),
                ),

                const SizedBox(height: 12),

                if (_timed)
                  TextFormField(
                    controller: _duration,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: fieldDecoration(
                      label: 'Sekundy na serię',
                      hint: 'Np. 30',
                      icon: Icons.timer,
                    ),
                    validator: (value) =>
                        _validateNumber(value, min: 1, max: 86400),
                  )
                else
                  TextFormField(
                    controller: _reps,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: fieldDecoration(
                      label: 'Powtórzenia w serii',
                      hint: 'Np. 10',
                      icon: Icons.repeat_one,
                    ),
                    validator: (value) =>
                        _validateNumber(value, min: 1, max: 10000),
                  ),

                const SizedBox(height: 22),
                const Text(
                  'DODATKOWE INFORMACJE',
                  style: TextStyle(
                    color: _yellow,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: Colors.white),
                  decoration: fieldDecoration(
                    label: 'Notatka (opcjonalnie)',
                    hint: 'Np. spokojne tempo, zwróć uwagę na technikę',
                    icon: Icons.notes,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        SizedBox(
          height: 46,
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'ANULUJ',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.6),
            ),
          ),
        ),
        SizedBox(
          height: 46,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _yellow,
              foregroundColor: _navy,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _submit,
            icon: const Icon(Icons.check, size: 18),
            label: const Text(
              'ZAPISZ',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}

class _RestTimerDialog extends StatefulWidget {
  final String exerciseName;
  final int initialSeconds;

  const _RestTimerDialog({
    required this.exerciseName,
    required this.initialSeconds,
  });

  @override
  State<_RestTimerDialog> createState() => _RestTimerDialogState();
}

class _RestTimerDialogState extends State<_RestTimerDialog> {
  Timer? _timer;
  late int _remainingSeconds;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.initialSeconds.clamp(0, 3600);
  }

  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  void _start() {
    if (_running || _remainingSeconds <= 0) return;

    setState(() => _running = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 1) {
        timer.cancel();

        setState(() {
          _remainingSeconds = 0;
          _running = false;
        });
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;

    setState(() => _running = false);
  }

  void _reset([int? seconds]) {
    _timer?.cancel();
    _timer = null;

    setState(() {
      _running = false;
      _remainingSeconds = (seconds ?? widget.initialSeconds).clamp(0, 3600);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds = widget.initialSeconds.clamp(0, 3600);
    final progress = totalSeconds > 0
        ? (_remainingSeconds / totalSeconds).clamp(0.0, 1.0)
        : 0.0;

    final isFinished = _remainingSeconds == 0;

    return AlertDialog(
      backgroundColor: _card,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: _yellow.withValues(alpha: 0.2)),
      ),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
      actionsPadding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      title: const Row(
        children: [
          Icon(Icons.timer_outlined, color: _yellow, size: 23),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'TIMER ODPOCZYNKU',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),

            // Nazwa ćwiczenia
            Text(
              widget.exerciseName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 26),

            // Okrągły licznik
            SizedBox(
              width: 218,
              height: 218,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: 1,
                      strokeWidth: 7,
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      color: isFinished ? Colors.white24 : _yellow,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                  Container(
                    width: 184,
                    height: 184,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _navy,
                      border: Border.all(
                        color: _yellow.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFinished
                            ? Icons.check_circle_outline
                            : _running
                            ? Icons.hourglass_bottom
                            : Icons.self_improvement,
                        color: _yellow,
                        size: 27,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _formattedTime,
                        style: const TextStyle(
                          fontSize: 45,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          fontFeatures: [FontFeature.tabularFigures()],
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isFinished
                            ? 'GOTOWE'
                            : _running
                            ? 'ODPOCZYNEK'
                            : 'PRZERWA',
                        style: const TextStyle(
                          color: _yellow,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // Szybki wybór czasu
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'USTAW CZAS PRZERWY',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [30, 60, 90, 120].map((seconds) {
                final selected = _remainingSeconds == seconds;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        foregroundColor: selected ? _navy : Colors.white70,
                        backgroundColor: selected
                            ? _yellow
                            : Colors.transparent,
                        side: BorderSide(
                          color: selected
                              ? _yellow
                              : Colors.white.withValues(alpha: 0.16),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      onPressed: () => _reset(seconds),
                      child: Text(
                        '${seconds}s',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 19),

            // Start / pauza
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _yellow,
                  foregroundColor: _navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _running
                    ? _pause
                    : isFinished
                    ? null
                    : _start,
                icon: Icon(
                  _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 25,
                ),
                label: Text(
                  _running ? 'WSTRZYMAJ' : 'ROZPOCZNIJ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Reset
            TextButton.icon(
              onPressed: () => _reset(),
              icon: const Icon(Icons.restart_alt, size: 19),
              label: const Text('Przywróć początkowy czas'),
              style: TextButton.styleFrom(foregroundColor: Colors.white60),
            ),

            if (isFinished) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _yellow.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: _yellow, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Koniec przerwy! Czas na kolejną serię.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _yellow,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.white70),
          child: const Text('ZAMKNIJ'),
        ),
      ],
    );
  }
}

class _PlanNameDialog extends StatefulWidget {
  final String title;
  final String actionLabel;
  final String? initialName;
  final String? hintText;

  const _PlanNameDialog({
    required this.title,
    required this.actionLabel,
    this.initialName,
    this.hintText,
  });

  @override
  State<_PlanNameDialog> createState() => _PlanNameDialogState();
}

class _PlanNameDialogState extends State<_PlanNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();

    if (name.isEmpty) return;

    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _card,
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: false,
        maxLength: 60,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Nazwa planu',
          hintText: widget.hintText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _yellow,
            foregroundColor: _navy,
          ),
          onPressed: _submit,
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
