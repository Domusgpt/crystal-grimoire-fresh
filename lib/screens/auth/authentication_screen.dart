import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/app_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/no_particles.dart';

class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({super.key});

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _appleSignInAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkAppleAvailability();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appService = context.watch<AppService>();

    return Scaffold(
      body: Stack(
        children: [
          // Mystical gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                colors: [
                  AppTheme.deepMystical,
                  AppTheme.darkViolet,
                  Colors.black,
                ],
                stops: [0.1, 0.6, 1.0],
              ),
            ),
          ),

          // Particle / holographic background
          const SimpleGradientParticles(particleCount: 6),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  _buildLogo(),
                  const SizedBox(height: 24),
                  _buildTitle(),
                  const SizedBox(height: 12),
                  _buildSubtitle(),
                  const SizedBox(height: 36),
                  _buildEmailField(),
                  const SizedBox(height: 16),
                  if (_isSignUp) _buildDisplayNameField(),
                  if (_isSignUp) const SizedBox(height: 16),
                  _buildPasswordField(),
                  const SizedBox(height: 12),
                  _buildForgotPassword(),
                  const SizedBox(height: 24),
                  _buildPrimaryButton(),
                  const SizedBox(height: 24),
                  _buildDivider(),
                  const SizedBox(height: 24),
                  _buildSocialButtons(),
                  const SizedBox(height: 24),
                  _buildToggleMode(),
                  if (appService.lastError != null) ...[
                    const SizedBox(height: 12),
                    _buildErrorBanner(appService.lastError!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppTheme.crystalGlow.withOpacity(0.85),
            AppTheme.amethystPurple.withOpacity(0.55),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.crystalGlow.withOpacity(0.25),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
      child: const Icon(
        Icons.diamond,
        size: 62,
        color: Colors.white,
      ),
    );
  }

  Widget _buildTitle() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          AppTheme.crystalGlow,
          AppTheme.mysticPink,
          AppTheme.cosmicPurple,
        ],
      ).createShader(bounds),
      child: Text(
        'Crystal Grimoire',
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildSubtitle() {
    final copy = _isSignUp
        ? 'Create your account to unlock AI rituals, moon ceremonies, and personalized crystal insights.'
        : 'Welcome back, luminous seeker. Sign in to continue your mystical journey.';
    return Text(
      copy,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white70,
            height: 1.4,
          ),
    );
  }

  Widget _buildEmailField() {
    return _AuthTextField(
      controller: _emailController,
      label: 'Email',
      icon: Icons.email_outlined,
      keyboardType: TextInputType.emailAddress,
    );
  }

  Widget _buildDisplayNameField() {
    return _AuthTextField(
      controller: _displayNameController,
      label: 'Display Name',
      icon: Icons.person_outline,
      textCapitalization: TextCapitalization.words,
    );
  }

  Widget _buildPasswordField() {
    return _AuthTextField(
      controller: _passwordController,
      label: 'Password',
      icon: Icons.lock_outline,
      obscureText: _obscurePassword,
      suffix: IconButton(
        onPressed: () {
          setState(() {
            _obscurePassword = !_obscurePassword;
          });
        },
        icon: Icon(
          _obscurePassword ? Icons.visibility_off : Icons.visibility,
          color: AppTheme.crystalGlow,
        ),
      ),
    );
  }

  Widget _buildForgotPassword() {
    if (_isSignUp) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => _showInfo(
          'Reset password coming soon. Until then, please reach out to support if you need assistance.',
        ),
        child: const Text(
          'Forgot password?',
          style: TextStyle(color: AppTheme.crystalGlow),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton() {
    final text = _isSignUp ? 'Create Account' : 'Sign In';
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitEmail,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.crystalGlow,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 8,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.0),
                  Colors.white.withOpacity(0.4),
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or continue with',
            style: TextStyle(color: Colors.white60),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.4),
                  Colors.white.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Column(
      children: [
        _SocialButton(
          icon: Icons.g_mobiledata,
          label: 'Continue with Google',
          onPressed: _isLoading ? null : _signInWithGoogle,
        ),
        const SizedBox(height: 16),
        if (_appleSignInAvailable)
          _SocialButton(
            icon: Icons.apple,
            label: 'Continue with Apple',
            onPressed: _isLoading ? null : _signInWithApple,
          ),
        const SizedBox(height: 16),
        _SocialButton(
          icon: Icons.auto_fix_high_outlined,
          label: 'Use App Anonymously (Preview)',
          onPressed: _isLoading ? null : _continueAnonymously,
        ),
      ],
    );
  }

  Widget _buildToggleMode() {
    final prompt = _isSignUp ? 'Already have an account? ' : "Need an account? ";
    final actionText = _isSignUp ? 'Sign In' : 'Create one';
    return TextButton(
      onPressed: () {
        setState(() {
          _isSignUp = !_isSignUp;
        });
      },
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white70),
          children: [
            TextSpan(text: prompt),
            TextSpan(
              text: actionText,
              style: const TextStyle(
                color: AppTheme.crystalGlow,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final displayName = _displayNameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter both email and password.');
      return;
    }

    if (_isSignUp && displayName.isEmpty) {
      _showError('Please choose a display name to personalize your experience.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isSignUp) {
        await AuthService.signUpWithEmail(
          email: email,
          password: password,
          displayName: displayName,
        );
      } else {
        await AuthService.signInWithEmail(
          email: email,
          password: password,
        );
      }
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final credential = await AuthService.signInWithGoogle();
      if (credential == null) {
        _showInfo('Google sign-in was cancelled.');
      }
    } catch (error) {
      _showError('Google sign-in failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithApple() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final credential = await AuthService.signInWithApple();
      if (credential == null) {
        _showInfo('Apple sign-in was cancelled.');
      }
    } catch (error) {
      _showError('Apple sign-in failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _continueAnonymously() async {
    try {
      setState(() {
        _isLoading = true;
      });
      await AuthService.signInAnonymously();
      _showInfo('Anonymous preview activated. Upgrade anytime to sync your journey.');
    } catch (error) {
      _showError('Unable to start anonymous session: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.cosmicPurple.withOpacity(0.8),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _checkAppleAvailability() async {
    try {
      final available = await SignInWithApple.isAvailable();
      if (mounted) {
        setState(() {
          _appleSignInAvailable = available;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _appleSignInAvailable = false;
        });
      }
    }
  }
}

class _AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final TextCapitalization textCapitalization;

  const _AuthTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(
          color: AppTheme.crystalGlow.withOpacity(0.25),
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        textCapitalization: textCapitalization,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppTheme.crystalGlow),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          border: InputBorder.none,
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _SocialButton({
equired this.icon, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 24),
        label: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(0.35)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        ),
      ),
    );
  }
}
