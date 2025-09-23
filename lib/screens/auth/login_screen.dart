import 'package:flutter/material.dart';

import 'authentication_screen.dart';

/// Legacy entry point kept for backwards compatibility.
///
/// The full authentication experience now lives in [AuthenticationScreen].
/// Other parts of the app that still reference [LoginScreen] will render
/// the new flow without any additional changes.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthenticationScreen();
  }
}
