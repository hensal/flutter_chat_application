import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _baseUrl = 'http://localhost:5003'; 

  // Register a new user
  Future<Map<String, dynamic>> registerUser(String name, String email, String password) async {
    final Uri url = Uri.parse('$_baseUrl/register');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );

    if (response.statusCode == 201) {
      return {'success': true, 'message': 'User registered successfully'};
    } else {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return {'success': false, 'message': data['message'] ?? 'Registration failed'};
    }
  }
}
