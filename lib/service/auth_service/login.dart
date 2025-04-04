import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences

class AuthService {
  static const String _baseUrl = 'http://localhost:5003'; // Your backend URL

  // Login method for email/password
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$_baseUrl/login');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      // Parse the response and save the token and user_id in SharedPreferences
      final data = json.decode(response.body);
      final token = data['token'];
      final userId = data['user_id']; // Now user_id is included in the response

      if (token != null && userId != null) {
        // Save token and user_id in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token); // Save the token
        await prefs.setInt('user_id', userId); // Save the user_id
        // Reload SharedPreferences to ensure token is saved
        await prefs.reload();
        // Print the token for debugging purposes
        print("Token saved: $token");
        print("User ID saved: $userId");
      }
      return {
        'success': true,
        'message': 'Login successful',
        'token': token,
        'user_id': userId,
      };
    } else {
      // If the login failed, handle the error more specifically
      final data = json.decode(response.body);
      String errorMessage = 'Failed to login: ${response.body}';

      if (data['message'] != null) {
        if (data['message'].contains('Email not found')) {
          errorMessage = 'Email not found'; // Custom message for email not found
        } else if (data['message'].contains('Invalid credentials, Please verify password')) {
          errorMessage = 'Password is wrong'; // Custom message for wrong password
        } else {
          errorMessage = data['message']; // Use the generic error message
        }
      }

      print("Login failed: $errorMessage");
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  // Google login method
Future<Map<String, dynamic>> loginWithGoogle(String idToken, String accessToken) async {
  final response = await http.post(
    Uri.parse('$_baseUrl/auth/google'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'idToken': idToken, 'accessToken': accessToken}),
  );

  if (response.statusCode == 200) {
    // Parse the response to extract user data
    final data = json.decode(response.body);
    final token = data['token'];
    final userId = data['user_id']; // Now user_id is included in the response

    if (token != null && userId != null) {
      // Save token and user_id in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token); // Save the token
      await prefs.setInt('user_id', userId); // Save the user_id
      // Reload SharedPreferences to ensure token is saved
      await prefs.reload();
      // Print the token for debugging purposes
      print("Token saved: $token");
      print("User ID saved: $userId");
    }
    return {
      'success': true,
      'message': 'Google login successful',
      'token': token,
      'user_id': userId,
    };
  } else {
    return {'success': false, 'message': 'Google login failed'};
  }
}

  // Method to check login status
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    print("Fetched token: $token");
    return token != null; // Return true if token exists, else false
  }

  // Method to logout (remove token and user_id)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token'); // Remove token from shared preferences
    await prefs.remove('user_id'); // Remove user_id from shared preferences
  }
}
