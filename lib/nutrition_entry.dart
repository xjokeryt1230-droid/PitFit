
import 'package:cloud_firestore/cloud_firestore.dart';

class NutritionEntry {
  const NutritionEntry({
    required this.id,
    required this.name,
    required this.mealType,
    required this.portionGrams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.consumedAt,
  });

  final String id;
  final String name;
  final String mealType;
  final double portionGrams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime consumedAt;

  static const mealTypes = [
    'Śniadanie',
    'Obiad',
    'Kolacja',
    'Przekąska',
  ];

  static double _number(
    Map<String, dynamic> data,
    String key,
  ) {
    final value = data[key];
    if (value is num) return value.toDouble();
    throw FormatException('Nieprawidłowe pole: $key');
  }

  factory NutritionEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw const FormatException('Brak danych posiłku.');
    }

    final timestamp = data['consumedAt'];
    if (timestamp is! Timestamp) {
      throw const FormatException('Nieprawidłowa data posiłku.');
    }

    final name = data['name'];
    final mealType = data['mealType'];

    if (name is! String ||
        mealType is! String ||
        !mealTypes.contains(mealType)) {
      throw const FormatException('Nieprawidłowe dane posiłku.');
    }

    return NutritionEntry(
      id: snapshot.id,
      name: name,
      mealType: mealType,
      portionGrams: _number(data, 'portionGrams'),
      calories: _number(data, 'calories'),
      protein: _number(data, 'protein'),
      carbs: _number(data, 'carbs'),
      fat: _number(data, 'fat'),
      consumedAt: timestamp.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name.trim(),
        'mealType': mealType,
        'portionGrams': portionGrams,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'consumedAt': Timestamp.fromDate(consumedAt),
      };

  void validate() {
    if (name.trim().isEmpty || name.trim().length > 120) {
      throw ArgumentError('Podaj nazwę posiłku (do 120 znaków).');
    }

    if (!mealTypes.contains(mealType)) {
      throw ArgumentError('Wybierz prawidłowy typ posiłku.');
    }

    if (!portionGrams.isFinite ||
        portionGrams <= 0 ||
        portionGrams > 100000) {
      throw ArgumentError('Porcja musi być większa od zera.');
    }

    final values = [calories, protein, carbs, fat];
    if (values.any((v) => !v.isFinite || v < 0 || v > 1000000)) {
      throw ArgumentError(
        'Wartości odżywcze muszą być nieujemnymi liczbami.',
      );
    }
  }
  
}
