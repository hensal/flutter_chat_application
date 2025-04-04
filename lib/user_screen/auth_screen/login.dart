import 'package:chat_application/user_screen/chat_screen/chatlist.dart';
import 'package:chat_application/service/auth_service/login.dart'; // Import AuthService
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _emailErrorMessage = '';
  String _passwordErrorMessage = '';
  bool _passwordVisible = false;
  bool _rememberMe = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _loadCredentials();
    signInSilently();
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
final GoogleSignIn _googleSignIn = GoogleSignIn(
  clientId: "417534979445-uufua4l4sq9a9e1lq6ccv2t1u1j53jju.apps.googleusercontent.com",
  scopes: ['email', 'profile', 'openid'],
);

void signInSilently() {
  _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) async {
    print('signInSilently triggered!');
    print(account);

    if (account != null) {
      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;
      final String? accessToken = auth.accessToken;

      if (idToken != null && accessToken != null) {
        final response = await _authService.loginWithGoogle(idToken, accessToken);
        if (response['success']) {
          if (mounted) context.go('/chatlist');
        } else {
          _showErrorMessage(response['message']);
        }
      }
    }
  });

  if (kIsWeb) {
    print('Skipping silent sign-in on web');
    return;
  }

  _googleSignIn.signInSilently();
}


Future<void> _loginWithGoogle() async {
  try {
    final GoogleSignInAccount? user = await _googleSignIn.signIn();

    if (user == null) {
      print("Google Sign-In cancelled");
      return;
    }

    if (kIsWeb) {
      _showErrorMessage("Google Sign-In works, but ID Token is unavailable on Web using google_sign_in. Use Firebase Auth or GIS instead.");
      return;
    }

    final GoogleSignInAuthentication auth = await user.authentication;
    final String? idToken = auth.idToken;
    final String? accessToken = auth.accessToken;

    print("ID Token: $idToken");
    print("Access Token: $accessToken");

    if (idToken != null && accessToken != null) {
      final response = await _authService.loginWithGoogle(idToken, accessToken);
      if (response['success']) {
        context.go('/chatlist');
      } else {
        _showErrorMessage(response['message']);
      }
    } else {
      _showErrorMessage("ID Token or Access Token is null");
    }
  } catch (e) {
    print("Error signing in with Google: $e");
    _showErrorMessage('Google sign-in failed.');
  }
}

  // Check if the user is already logged in
  Future<void> _checkLoginStatus() async {
    bool loggedIn = await _authService.isLoggedIn();
    if (loggedIn) {
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

  // Email validation function
  bool _isEmailValid(String email) {
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _login() async {
    final BuildContext ctx = context;
    setState(() {
      _isLoading = true;
      _emailErrorMessage = '';
      _passwordErrorMessage = '';
    });

    final email = _emailController.text;
    final password = _passwordController.text;
    // Validate email and password
    if (!_isEmailValid(email)) {
      setState(() {
        _isLoading = false;
        _emailErrorMessage = 'Please enter a valid email address.';
      });
      return;
    }
    final response = await _authService.login(email, password);
    setState(() {
      _isLoading = false;
    });

    if (response['success']) {
      await _saveCredentials();

      if (ctx.mounted) {
        ctx.go('/chatlist');
      }
    } else {
      if (ctx.mounted) {
        setState(() {
          if (response['message'] == "Email not found") {
            _emailErrorMessage = 'No account found with this email.';
          } else if (response['message'] == "Password is wrong") {
            _passwordErrorMessage = 'Password is incorrect';
          } else {
            _passwordErrorMessage = response['message'];
          }
        });
      }
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
                errorText:
                    _emailErrorMessage.isNotEmpty ? _emailErrorMessage : null,
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
                    _passwordVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _passwordVisible = !_passwordVisible;
                    });
                  },
                ),
                hintText: 'Password',
                border: const OutlineInputBorder(),
                errorText: _passwordErrorMessage.isNotEmpty
                    ? _passwordErrorMessage
                    : null, // Display password error message
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
                onPressed:
                    _isLoading ? null : _login, // Disable button during loading
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
                    context.go('/forgot-password');
                  },
                  child: const Text('Forgot password?'),
                ),
                TextButton(
                  onPressed: () {
                    context.go('/signup');
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
                onPressed:
                    _loginWithGoogle, // Call the method when button is pressed
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
