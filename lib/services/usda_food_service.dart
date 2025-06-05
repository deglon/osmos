import 'dart:convert';
import 'package:http/http.dart' as http;

class USDAFoodService {
  static const String _apiKey = '9kCxYMOE2dxelNMawaHsnCocV6AMgYBliYBVsr3l';
  static const String _baseUrl = 'https://api.nal.usda.gov/fdc/v1';

  /// Search for foods by name. Returns a list of food items with their fdcId and description.
  Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    final url = Uri.parse(
      '$_baseUrl/foods/search?query=${Uri.encodeComponent(query)}&api_key=$_apiKey',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final foods = data['foods'] as List<dynamic>;
      return foods
          .map(
            (food) => {
              'fdcId': food['fdcId'],
              'description': food['description'],
              'brandName': food['brandName'],
              'dataType': food['dataType'],
            },
          )
          .toList();
    } else {
      throw Exception('Failed to search foods: ${response.statusCode}');
    }
  }

  /// Get nutrition details for a food by fdcId. Returns a map with calories, carbs, protein, fat, etc.
  Future<Map<String, dynamic>> getFoodDetails(int fdcId) async {
    final url = Uri.parse('$_baseUrl/food/$fdcId?api_key=$_apiKey');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final nutrients = data['foodNutrients'] as List<dynamic>;
      double? calories, carbs, protein, fat;
      for (var n in nutrients) {
        final id = n['nutrientId'] ?? n['nutrient']['id'];
        final value = n['value']?.toDouble();
        if (id == null || value == null) continue;
        if (id == 1008) calories = value;
        if (id == 1005) carbs = value;
        if (id == 1003) protein = value;
        if (id == 1004) fat = value;
      }
      return {
        'calories': calories,
        'carbs': carbs,
        'protein': protein,
        'fat': fat,
        'description': data['description'],
        'servingSize': data['servingSize'],
        'servingSizeUnit': data['servingSizeUnit'],
      };
    } else {
      throw Exception('Failed to get food details: ${response.statusCode}');
    }
  }
}
