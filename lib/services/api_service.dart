import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Using ADB reverse → localhost works
  static const String baseUrl = "http://127.0.0.1:9000";

  static Future<List<dynamic>> getRecommendations(String skills) async {
    try {
      final url = Uri.parse("$baseUrl/recommend?user_skills=$skills");

      print("Calling API: $url");

      final response = await http.get(url);

      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["recommended_opportunities"] != null) {
          return data["recommended_opportunities"];
        } else {
          return [];
        }
      } else {
        print("API failed");
        return [];
      }
    } catch (e) {
      print("ERROR: $e");
      return [];
    }
  }
}