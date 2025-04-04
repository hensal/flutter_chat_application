import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = 'http://localhost:5003';

  // Function to send the reset password email
  static Future<Map<String, dynamic>> sendResetLink(String email) async {
    final url = Uri.parse('$baseUrl/send-reset-link');
    final headers = {'Content-Type': 'application/json'};
    final body = json.encode({'email': email});

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Reset link sent successfully.'};
      } else {
        return {
          'success': false,
          'message': json.decode(response.body)['message']
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
