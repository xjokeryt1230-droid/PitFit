
import 'dart:convert';

import 'package:http/http.dart' as http;

class FoodProduct {
  const FoodProduct({
    required this.code,
    required this.name,
    required this.brand,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
  });

  final String code;
  final String name;
  final String brand;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;

  double forGrams(double valuePer100g, double grams) {
    return valuePer100g * grams / 100.0;
  }

  factory FoodProduct.fromJson(Map<String, dynamic> json) {
    final nutriments = json['nutriments'];

    if (nutriments is! Map<String, dynamic>) {
      throw const FormatException('Brak wartości odżywczych.');
    }

    double? readNumber(List<String> keys) {
      for (final key in keys) {
        final value = nutriments[key];

        if (value is num && value.isFinite && value >= 0) {
          return value.toDouble();
        }
      }

      return null;
    }

    final calories = readNumber([
      'energy-kcal_100g',
      'energy-kcal_value',
    ]);
    final protein = readNumber(['proteins_100g']);
    final carbs = readNumber(['carbohydrates_100g']);
    final fat = readNumber(['fat_100g']);

    if (calories == null ||
        protein == null ||
        carbs == null ||
        fat == null) {
      throw const FormatException(
        'Produkt nie ma kompletu wartości odżywczych.',
      );
    }

    final rawBrands = json['brands'];
    final brand = rawBrands is List
        ? rawBrands.map((value) => value.toString()).join(', ')
        : (rawBrands ?? '').toString();

    return FoodProduct(
      code: (json['code'] ?? '').toString(),
      name: (json['product_name'] ?? '').toString().trim(),
      brand: brand.trim(),
      caloriesPer100g: calories,
      proteinPer100g: protein,
      carbsPer100g: carbs,
      fatPer100g: fat,
    );
  }
}

class OpenFoodFactsService {
  OpenFoodFactsService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const _userAgent = 'PitFit/1.0';

  Future<List<FoodProduct>> search(String query) async {
    final term = query.trim();

    if (term.length < 2) {
      return [];
    }

    final uri = Uri.https(
      'search.openfoodfacts.org',
      '/search',
      {
        'q': term,
        'langs': 'pl,en',
        'page_size': '20',
      },
    );

    final response = await _client
        .get(
          uri,
          headers: {
            'User-Agent': _userAgent,
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Wyszukiwarka produktów jest chwilowo niedostępna '
        '(HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(
      utf8.decode(response.bodyBytes),
    );

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Nieprawidłowa odpowiedź wyszukiwarki.',
      );
    }

    final hits = decoded['hits'];

    if (hits is! List) {
      throw const FormatException(
        'Odpowiedź nie zawiera listy produktów.',
      );
    }

    final results = <FoodProduct>[];
    final seenCodes = <String>{};

    for (final item in hits) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      try {
        final product = FoodProduct.fromJson(item);

        if (product.name.isEmpty ||
            product.code.isEmpty ||
            !seenCodes.add(product.code)) {
          continue;
        }

        results.add(product);
      } on FormatException {
        // Pomijamy produkty bez wymaganych danych.
      }
    }

    return results;
  }
  Future<FoodProduct?> getByBarcode(String barcode) async {
    final code = barcode.trim();

    if (!RegExp(r'^\d{8,14}$').hasMatch(code)) {
      throw const FormatException(
        'Kod kreskowy powinien mieć od 8 do 14 cyfr.',
      );
    }

    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/$code.json',
      {'fields': 'code,product_name,product_name_pl,brands,nutriments'},
    );

    final response = await _client
        .get(
          uri,
          headers: {
            'User-Agent': _userAgent,
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 404) return null;

    if (response.statusCode != 200) {
      throw Exception(
        'Baza produktów jest chwilowo niedostępna '
        '(HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Nieprawidłowa odpowiedź bazy produktów.');
    }

    if (decoded['status'] != 1) return null;

    final product = decoded['product'];
    if (product is! Map<String, dynamic>) return null;

    final data = Map<String, dynamic>.from(product);
    data['code'] = (data['code'] ?? code).toString();

    final name = (data['product_name'] ?? '').toString().trim();
    final namePl = (data['product_name_pl'] ?? '').toString().trim();
    data['product_name'] =
        name.isNotEmpty ? name : (namePl.isNotEmpty ? namePl : 'Produkt $code');

    // Rzuca FormatException, jeśli produkt nie ma kompletu wartości odżywczych.
    return FoodProduct.fromJson(data);
  }
  void dispose() {
    _client.close();
  }
}
