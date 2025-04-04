import 'dart:convert';
import 'package:http/http.dart' as http;

class ResetPasswordService {
  static Future<Map<String, dynamic>> resetPassword(String email, String newPassword) async {
    final url = Uri.parse('http://localhost:5003/reset-password');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'newPassword': newPassword}),
      );

      final Map<String, dynamic> responseData = json.decode(response.body);

      // Ensure response contains success flag
      return {
        'success': responseData['success'] ?? false,  // Default to false if missing
        'message': responseData['message'] ?? 'Unknown error occurred',
      };

    } catch (error) {
      return {
        'success': false,
        'message': 'An error occurred: $error',
      };
    }
  }
}
