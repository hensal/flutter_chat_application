//import 'package:chat_application/chart.dart'; // Import your ChatScreen
import 'package:chat_application/chatlist.dart';
import 'package:chat_application/service/login.dart'; // Import AuthService
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login Page',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _passwordVisible = false;
  bool _rememberMe = false; // Remember Me checkbox state
  final AuthService _authService = AuthService();

  // Check login status when the widget is initialized
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _loadCredentials();
  }

  // Check if the user is already logged in
  Future<void> _checkLoginStatus() async {
    bool loggedIn = await _authService.isLoggedIn();
    if (loggedIn) {
      // Navigate to ChatScreen if user is logged in
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ChatListScreen()),
      );
    }
  }

  // Load saved credentials (if any)
  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedEmail = prefs.getString('email');
    String? savedPassword = prefs.getString('password');
    bool savedRememberMe = prefs.getBool('remember_me') ?? false;

    if (savedRememberMe) {
      _emailController.text = savedEmail ?? '';
      _passwordController.text = savedPassword ?? '';
      setState(() {
        _rememberMe = savedRememberMe;
      });
    }
  }

  // Save credentials if Remember Me is checked
  Future<void> _saveCredentials() async {
    if (_rememberMe) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('email', _emailController.text);
      await prefs.setString('password', _passwordController.text);
      await prefs.setBool('remember_me', true);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('email');
      await prefs.remove('password');
      await prefs.remove('remember_me');
    }
  }

  // Login function
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = ''; // Clear any previous error message
    });

    final email = _emailController.text;
    final password = _passwordController.text;

    // Call the login method from AuthService
    final response = await _authService.login(email, password);

    setState(() {
      _isLoading = false;
    });

    if (response['success']) {
      // Handle successful login, for example, navigate to the home screen
      await _saveCredentials(); // Save credentials if Remember Me is checked
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ChatListScreen()),
      );
    } else {
      // Display error message if login fails
      setState(() {
        _errorMessage = response['message'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Text(
              'Chat Application',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.email),
                hintText: 'Email address',
                border: const OutlineInputBorder(),
                errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: !_passwordVisible,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _passwordVisible = !_passwordVisible;
                    });
                  },
                ),
                hintText: 'Password',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: (bool? value) {
                    setState(() {
                      _rememberMe = value!;
                    });
                  },
                ),
                const Text("Remember me"),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.green,
                ),
                onPressed: _isLoading ? null : _login, // Disable button during loading
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Log in',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    // Navigate to Forgot Password page (Placeholder)
                  },
                  child: const Text('Forgot password?'),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to Sign Up page (Placeholder)
                  },
                  child: const Text('Sign up'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('OR'),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.g_mobiledata, color: Colors.blueAccent),
                onPressed: () {
                  // Implement Google Login
                },
                label: const Text(
                  'Log in with Google',
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
