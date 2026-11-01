import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  test('PitFit ma poprawnie zdefiniowane kolory marki', () {
    expect(pitFitYellow.toARGB32(), 0xFFFFD54F);
    expect(pitFitNavy.toARGB32(), 0xFF101827);
    expect(pitFitCard.toARGB32(), 0xFF1C2738);
  });

  test('katalog ćwiczeń zawiera podstawowe ćwiczenia', () {
    expect(findExerciseInfo('pompki'), isNotNull);
    expect(findExerciseInfo('Przysiady'), isNotNull);
    expect(findExerciseInfo('plank'), isNotNull);
  });

  test('wyszukiwanie ćwiczeń ignoruje wielkość liter i spacje', () {
    expect(findExerciseInfo('  POMPKI  ')?.name, 'Pompki');
  });

  test('nieznane ćwiczenie zwraca null', () {
    expect(findExerciseInfo('nieistniejące ćwiczenie'), isNull);
  });
}