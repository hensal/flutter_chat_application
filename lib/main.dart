import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:chat_application/user_screen/chat_screen/chatlist.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:chat_application/user_screen/auth_screen/forgot_password.dart';
import 'package:chat_application/user_screen/auth_screen/login.dart';
import 'package:chat_application/user_screen/auth_screen/reset_password_screen.dart';
import 'package:chat_application/user_screen/auth_screen/sign_up_screen.dart';

void main() {
  setUrlStrategy(PathUrlStrategy());  // This removes the '#' from the URL
  //GoogleSignInPlatform.instance = GoogleSignInWeb();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final GoRouter _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/chatlist',
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const CreateAccountPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final String? email = state.uri.queryParameters['email'];
          return ResetPasswordPage(email: email ?? '');
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Chat App',
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
