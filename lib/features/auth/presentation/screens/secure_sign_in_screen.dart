import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/apple_like_gradient.dart';
import '../../../../core/ui/uniform_app_bar.dart';
import '../../../../core/ui/app_snack_bar.dart';
import '../../../help_request/presentation/screens/home_screen.dart';
import '../providers/auth_provider.dart';

bool _isValidEmail(String value) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
}

class SecureSignInScreen extends StatefulWidget {
  const SecureSignInScreen({super.key});

  @override
  State<SecureSignInScreen> createState() => _SecureSignInScreenState();
}

class _SecureSignInScreenState extends State<SecureSignInScreen> {
  bool _isSignUpMode = false;
  bool _obscurePassword = true;

  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();

  final _signUpNameController = TextEditingController();
  final _signUpEmailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  final _signUpConfirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _signUpNameController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    _signUpConfirmPasswordController.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _showError(Object error) {
    final message = error is AuthException
        ? error.message
        : error.toString().replaceFirst('Exception: ', '');

    showGhmeraSnackBar(context, message: message, type: SnackBarType.error);
  }

  void _showInfo(String message) {
    showGhmeraSnackBar(context, message: message, type: SnackBarType.info);
  }

  Future<void> _handleSignIn() async {
    if (!_signInFormKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    try {
      await authProvider.signInWithEmailAndPassword(
        _signInEmailController.text.trim(),
        _signInPasswordController.text,
      );
      if (!mounted || !authProvider.isSignedIn) {
        return;
      }
      _goHome();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _handleSignUp() async {
    if (!_signUpFormKey.currentState!.validate()) {
      return;
    }

    final name = _signUpNameController.text.trim();
    final email = _signUpEmailController.text.trim().toLowerCase();
    final password = _signUpPasswordController.text;

    final authProvider = context.read<AuthProvider>();

    try {
      await authProvider.sendRegistrationCode(email: email, displayName: name);
    } catch (error) {
      _showError(error);
      return;
    }

    if (!mounted) return;
    _showInfo(
      'We sent a 6-digit verification code to $email from PEATECH SERVICES LLC.',
    );

    while (mounted) {
      final code = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _VerificationCodeDialog(
          email: email,
          title: 'Enter Verification Code',
          description:
              'Enter the 6-digit code sent to $email. Cancel and request a new code if it has expired.',
          buttonText: 'Verify & Finish Sign Up',
        ),
      );

      if (code == null || code.trim().isEmpty || !mounted) return;

      try {
        await authProvider.completeRegistration(
          email: email,
          code: code.trim(),
          password: password,
          displayName: name,
        );
        if (!mounted) return;
        if (authProvider.isSignedIn) _goHome();
        return;
      } catch (error) {
        if (!mounted) return;
        _showError(error);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) =>
          _EmailAddressDialog(initialEmail: _signInEmailController.text.trim()),
    );

    if (email == null || email.isEmpty || !mounted) return;

    final authProvider = context.read<AuthProvider>();

    try {
      await authProvider.sendPasswordResetCode(email);
    } catch (error) {
      _showError(error);
      return;
    }

    if (!mounted) return;
    _showInfo('A 6-digit password reset code has been sent to $email.');

    while (mounted) {
      final result = await showDialog<Map<String, String>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ResetPasswordDialog(email: email),
      );

      if (result == null || !mounted) return;

      try {
        await authProvider.completePasswordReset(
          email: email,
          code: result['code']!,
          newPassword: result['newPassword']!,
        );
        if (!mounted) return;
        _signInEmailController.text = email;
        _showInfo(
          'Your password has been reset. Please sign in with your new password.',
        );
        return;
      } catch (error) {
        if (!mounted) return;
        _showError(error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        leading: Navigator.of(context).canPop()
            ? uniformBackButton(context)
            : null,
        title: uniformAppBarTitle(
          context,
          title: _isSignUpMode ? 'Create Ghmera Account' : 'Secure Sign In',
          subtitle: _isSignUpMode
              ? 'Sign up with email and verify with a 6-digit code.'
              : 'Enter your email and password to access your dashboard.',
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: appleLikeScreenGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 30,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mode Selector Tabs
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _isSignUpMode = false),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !_isSignUpMode
                                        ? colorScheme.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: !_isSignUpMode
                                          ? Colors.white
                                          : const Color(0xFF50625F),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _isSignUpMode = true),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isSignUpMode
                                        ? colorScheme.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Sign Up',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: _isSignUpMode
                                          ? Colors.white
                                          : const Color(0xFF50625F),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (!_isSignUpMode) ...[
                        // SIGN IN FORM
                        Form(
                          key: _signInFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _signInEmailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Email Address',
                                  hintText: 'name@example.com',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: (val) {
                                  final text = val?.trim() ?? '';
                                  if (!_isValidEmail(text)) {
                                    return 'Please enter a valid email address.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _signInPasswordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleSignIn(),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: 'Enter your password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (val) {
                                  if ((val ?? '').isEmpty) {
                                    return 'Please enter your password.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: authProvider.isLoading
                                      ? null
                                      : _handleForgotPassword,
                                  child: const Text('Forgot password?'),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: authProvider.isLoading
                                      ? null
                                      : _handleSignIn,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    backgroundColor: colorScheme.primary,
                                  ),
                                  child: authProvider.isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // SIGN UP FORM
                        Form(
                          key: _signUpFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _signUpNameController,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  hintText: 'John Doe',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (val) {
                                  if ((val?.trim() ?? '').isEmpty) {
                                    return 'Please enter your full name.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _signUpEmailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Email Address',
                                  hintText: 'name@example.com',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: (val) {
                                  final text = val?.trim() ?? '';
                                  if (!_isValidEmail(text)) {
                                    return 'Please enter a valid email address.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _signUpPasswordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: 'At least 6 characters',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (val) {
                                  final text = val ?? '';
                                  if (text.length < 6) {
                                    return 'Password must be at least 6 characters.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _signUpConfirmPasswordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleSignUp(),
                                decoration: const InputDecoration(
                                  labelText: 'Confirm Password',
                                  hintText: 'Enter the password again',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                                validator: (val) {
                                  if (val != _signUpPasswordController.text) {
                                    return 'Passwords do not match.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: authProvider.isLoading
                                      ? null
                                      : _handleSignUp,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    backgroundColor: colorScheme.primary,
                                  ),
                                  child: authProvider.isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Sign Up & Get Code',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.mark_email_read_outlined,
                              color: Color(0xFF103B36),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Verification codes are sent from PEATECH SERVICES LLC (mail@peatechservice.com).',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF50625F),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailAddressDialog extends StatefulWidget {
  const _EmailAddressDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_EmailAddressDialog> createState() => _EmailAddressDialogState();
}

class _EmailAddressDialogState extends State<_EmailAddressDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_controller.text.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your account email address. We will send a 6-digit password reset code to your inbox.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'name@example.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) => _isValidEmail(value ?? '')
                  ? null
                  : 'Please enter a valid email address.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Send Reset Code')),
      ],
    );
  }
}

class _VerificationCodeDialog extends StatefulWidget {
  const _VerificationCodeDialog({
    required this.email,
    required this.title,
    required this.description,
    required this.buttonText,
  });

  final String email;
  final String title;
  final String description;
  final String buttonText;

  @override
  State<_VerificationCodeDialog> createState() =>
      _VerificationCodeDialogState();
}

class _VerificationCodeDialogState extends State<_VerificationCodeDialog> {
  final TextEditingController _codeController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(_codeController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.description),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              textInputAction: TextInputAction.done,
              maxLength: 6,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
              ),
              textAlign: TextAlign.center,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: '6-Digit Verification Code',
                hintText: '123456',
                counterText: '',
              ),
              validator: (val) {
                final text = val?.trim() ?? '';
                if (text.length != 6 || int.tryParse(text) == null) {
                  return 'Enter the valid 6-digit code.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.buttonText)),
      ],
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.email});

  final String email;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'code': _codeController.text.trim(),
      'newPassword': _passwordController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Complete Password Reset'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the 6-digit reset code sent to ${widget.email} and choose a new password.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              maxLength: 6,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                labelText: '6-Digit Reset Code',
                hintText: '123456',
                counterText: '',
              ),
              validator: (val) {
                final text = val?.trim() ?? '';
                if (text.length != 6 || int.tryParse(text) == null) {
                  return 'Enter the 6-digit code.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'New Password',
                hintText: 'At least 6 characters',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (val) {
                if ((val ?? '').length < 6) {
                  return 'Password must be at least 6 characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                hintText: 'Enter the new password again',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Passwords do not match.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Reset Password')),
      ],
    );
  }
}
