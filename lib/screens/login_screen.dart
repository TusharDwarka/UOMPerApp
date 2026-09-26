import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

class LoginScreen extends StatefulWidget {
  /// When true the screen was opened from Settings to upgrade a guest
  /// account; it pops itself after success.
  final bool upgradeGuest;
  const LoginScreen({super.key, this.upgradeGuest = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late bool _isLogin = !widget.upgradeGuest;
  bool _isLoading = false;
  String? _error;
  String? _info;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text; // never trim passwords

    String? error;
    if (email.isEmpty || password.isEmpty) {
      error = 'Please fill in all fields';
    } else if (!_isLogin) {
      if (_nameController.text.trim().isEmpty) {
        error = 'Tell us your name (shown to your groups)';
      } else if (password != _confirmPasswordController.text) {
        error = 'Passwords do not match';
      } else if (password.length < 8) {
        error = 'Password must be at least 8 characters';
      }
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _info = null;
    });
    try {
      if (_isLogin) {
        await _authService.signInWithEmail(email, password);
      } else {
        await _authService.signUpWithEmail(email, password, displayName: _nameController.text);
      }
      if (widget.upgradeGuest && mounted) Navigator.of(context).pop(true);
      // Otherwise the auth StreamBuilder in main.dart takes over.
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email above first');
      return;
    }
    try {
      await _authService.sendPasswordReset(email);
      setState(() {
        _error = null;
        _info = 'Password reset link sent to $email';
      });
    } catch (e) {
      setState(() => _error = AuthService.friendlyError(e));
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not continue. Check your internet.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: widget.upgradeGuest ? AppBar(title: const Text('Create account')) : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
                    child: Icon(Icons.school_rounded, color: p.onInk, size: 30),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    _isLogin ? 'Welcome\nback' : 'Join your\ncohort',
                    style: TextStyle(fontSize: 46, height: 1.02, fontWeight: FontWeight.w300, letterSpacing: -1.8, color: p.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isLogin
                        ? 'Sign in to sync your phone and PC.'
                        : widget.upgradeGuest
                            ? 'Your guest data stays — it just gets a login.'
                            : 'One account for your phone, laptop and study groups.',
                    style: TextStyle(fontSize: 15, color: p.textSecondary),
                  ),
                  const SizedBox(height: 28),
                  PillSegmented<bool>(
                    values: const [true, false],
                    selected: _isLogin,
                    labelOf: (v) => v ? 'Sign in' : 'Sign up',
                    onChanged: (v) => setState(() {
                      _isLogin = v;
                      _error = null;
                      _info = null;
                    }),
                  ),
                  const SizedBox(height: 18),
                  SoftCard(
                    padding: const EdgeInsets.all(18),
                    child: AutofillGroup(
                      child: Column(
                        children: [
                          if (!_isLogin) ...[
                            _field(_nameController, 'Your name', Icons.person_outline_rounded,
                                autofill: const [AutofillHints.name], capitalization: TextCapitalization.words),
                            const SizedBox(height: 12),
                          ],
                          _field(_emailController, 'Email', Icons.alternate_email_rounded,
                              keyboard: TextInputType.emailAddress, autofill: const [AutofillHints.email]),
                          const SizedBox(height: 12),
                          _field(
                            _passwordController,
                            'Password',
                            Icons.lock_outline_rounded,
                            obscure: _obscurePassword,
                            autofill: [_isLogin ? AutofillHints.password : AutofillHints.newPassword],
                            onSubmitted: _isLogin ? (_) => _submit() : null,
                            suffix: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          if (!_isLogin) ...[
                            const SizedBox(height: 12),
                            _field(_confirmPasswordController, 'Confirm password', Icons.lock_outline_rounded,
                                obscure: true, onSubmitted: (_) => _submit()),
                          ],
                          if (_isLogin)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(onPressed: _isLoading ? null : _forgotPassword, child: const Text('Forgot password?')),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null || _info != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: (_error != null ? Colors.red : Colors.green).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Icon(_error != null ? Icons.error_outline : Icons.mark_email_read_outlined,
                              size: 18, color: _error != null ? Colors.red[400] : Colors.green[600]),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_error ?? _info!,
                                style: TextStyle(color: _error != null ? Colors.red[400] : Colors.green[700], fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: _isLoading
                        ? Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6, color: p.accent)))
                        : InkPillButton(
                            label: _isLogin ? 'Sign in' : (widget.upgradeGuest ? 'Save my account' : 'Create account'),
                            icon: Icons.arrow_forward_rounded,
                            expand: true,
                            onPressed: _submit,
                          ),
                  ),
                  if (!widget.upgradeGuest) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: _isLoading ? null : _continueAsGuest,
                        child: Text('Continue as guest (this device only)', style: TextStyle(color: p.textSecondary, fontSize: 13)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 14, color: p.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Passwords are handled by Firebase Auth and stored only as a salted hash — never by this app.',
                          style: TextStyle(fontSize: 11, color: p.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType? keyboard,
    bool obscure = false,
    Widget? suffix,
    Iterable<String>? autofill,
    TextCapitalization capitalization = TextCapitalization.none,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      autofillHints: autofill,
      textCapitalization: capitalization,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, size: 20), suffixIcon: suffix),
    );
  }
}
