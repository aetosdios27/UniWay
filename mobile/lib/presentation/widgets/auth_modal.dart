import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../../core/services/google_sign_in_service.dart';

class AuthModal extends StatefulWidget {
  final AuthController authController;
  final String? prompt;
  final VoidCallback? onSuccess;
  final GoogleIdentityProvider? googleProvider;

  const AuthModal({
    super.key,
    required this.authController,
    this.prompt,
    this.onSuccess,
    this.googleProvider,
  });

  static Future<void> show(
    BuildContext context, {
    required AuthController authController,
    String? prompt,
    VoidCallback? onSuccess,
    GoogleIdentityProvider? googleProvider,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AuthModal(
        authController: authController,
        prompt: prompt,
        onSuccess: onSuccess,
        googleProvider: googleProvider,
      ),
    );

    if (!authController.isAuthenticated && !authController.isGuest) {
      await authController.continueAsGuest();
    }
  }

  @override
  State<AuthModal> createState() => _AuthModalState();
}

class _AuthModalState extends State<AuthModal> {
  bool _isSignUp = false;
  bool _isGooglePending = false;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _obscurePassword = true;

  GoogleIdentityProvider get _googleProvider =>
      widget.googleProvider ?? GoogleSignInService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final navigator = Navigator.of(context);

    bool success = false;
    if (_isSignUp) {
      success = await widget.authController.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
      );
    } else {
      success = await widget.authController.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }

    if (!mounted) return;
    if (success) {
      navigator.pop();
      widget.onSuccess?.call();
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGooglePending = true);
    try {
      final navigator = Navigator.of(context);
      final idToken = await _googleProvider.getIdToken();
      if (!mounted) return;
      if (idToken == null) return;

      final success = await widget.authController.loginWithGoogle(idToken);
      if (!mounted) return;
      if (success) {
        navigator.pop();
        widget.onSuccess?.call();
      }
    } on GoogleSignInUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _isGooglePending = false);
    }
  }

  Future<void> _continueAsGuest() async {
    final navigator = Navigator.of(context);
    await widget.authController.continueAsGuest();
    if (!mounted) return;
    navigator.pop();
  }

  InputDecoration _decoration(ThemeData theme, {required String label, Widget? prefixIcon, Widget? suffixIcon}) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color),
        );

    return InputDecoration(
      labelText: label,
      floatingLabelStyle: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      border: border(theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      enabledBorder: border(theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      focusedBorder: border(theme.colorScheme.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedBuilder(
      animation: widget.authController,
      builder: (context, _) {
        final isLoading = widget.authController.isLoading;
        final errorMsg = widget.authController.errorMessage;
        final busy = isLoading || _isGooglePending;

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: bottomInset + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    _isSignUp ? 'Create UniWay Account' : 'Sign in to UniWay',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.prompt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.prompt!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Sign In')),
                      ButtonSegment(value: true, label: Text('Create Account')),
                    ],
                    selected: {_isSignUp},
                    showSelectedIcon: false,
                    onSelectionChanged: busy
                        ? null
                        : (val) {
                            setState(() {
                              _isSignUp = val.first;
                              _obscurePassword = true;
                            });
                          },
                  ),
                  const SizedBox(height: 20),
                  if (errorMsg != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 18,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMsg,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_isSignUp) ...[
                    TextFormField(
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      style: theme.textTheme.bodyLarge,
                      decoration: _decoration(
                        theme,
                        label: 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: theme.textTheme.bodyLarge,
                    decoration: _decoration(
                      theme,
                      label: 'Email Address',
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!val.contains('@') || !val.contains('.')) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    style: theme.textTheme.bodyLarge,
                    decoration: _decoration(
                      theme,
                      label: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (_isSignUp && val.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : Text(
                            _isSignUp ? 'Create Account' : 'Sign In',
                            style: theme.textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: busy ? null : _signInWithGoogle,
                    icon: _isGooglePending
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : const Icon(Icons.g_mobiledata, size: 24),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: busy ? null : _continueAsGuest,
                      child: Text(
                        'Continue as Guest',
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
