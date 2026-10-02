// lib/services/api_service.dart
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  // Cambia con l'URL di produzione quando sarà il momento; probabilmente lo passiamo da .env 
  static const String baseUrl = 'http://10.0.2.2:8000/api'; 

  static Future<Map<String, String>> _getHeaders() async {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;
    
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> get(String endpoint) async {
    final headers = await _getHeaders();
    return http.get(Uri.parse('$baseUrl$endpoint'), headers: headers);
  }

  static Future<http.Response> post(String endpoint, String body) async {
    final headers = await _getHeaders();
    return http.post(Uri.parse('$baseUrl$endpoint'), headers: headers, body: body);
  }
}