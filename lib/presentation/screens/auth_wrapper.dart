import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/di/injection_container.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';
import 'main_shell.dart';

/// Wraps application flow based on authentication state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = sl<AuthService>();
    
    return StreamBuilder<User?>(
      stream: authService.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          
          if (user == null) {
            return const LoginScreen();
          } else {
             // Return the Main Shell
             return const MainShell(); 
          }
        }
        
        // Loading state while checking auth
        return const Scaffold(
          backgroundColor: Color(0xFF0F172A),
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
