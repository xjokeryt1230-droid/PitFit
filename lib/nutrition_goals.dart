class NutritionGoals {
  const NutritionGoals({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  static const defaults = NutritionGoals(
    calories: 2000,
    protein: 100,
    carbs: 250,
    fat: 65,
  );

  Map<String, dynamic> toFirestore() => {
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };

  factory NutritionGoals.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return defaults;

    double readNumber(String key, double fallback) {
      final value = data[key];

      return value is num && value.isFinite && value >= 0
          ? value.toDouble()
          : fallback;
    }

    return NutritionGoals(
      calories: readNumber('calories', defaults.calories),
      protein: readNumber('protein', defaults.protein),
      carbs: readNumber('carbs', defaults.carbs),
      fat: readNumber('fat', defaults.fat),
    );
  }

  void validate() {
    final values = [calories, protein, carbs, fat];

    if (values.any((value) => !value.isFinite || value < 0)) {
      throw ArgumentError('Cele muszą być nieujemnymi liczbami.');
    }
  }

  /// Energia wynikająca z zapisanych wartości makroskładników.
  double get caloriesFromMacros => protein * 4 + carbs * 4 + fat * 9;

  /// Kontrola rozbieżności między kaloriami i makrami.
  /// To diagnostyka danych, nie sposób ustalania celów.
  bool get hasConsistentEnergy {
    if (!calories.isFinite || calories <= 0) {
      return false;
    }

    final difference = (caloriesFromMacros - calories).abs();

    return difference / calories <= 0.05;
  }
}
