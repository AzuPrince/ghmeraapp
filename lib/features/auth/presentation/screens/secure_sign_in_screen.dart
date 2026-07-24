import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/models/ghmera_models.dart';
import '../../../../core/ui/apple_like_gradient.dart';
import '../../../../core/ui/uniform_app_bar.dart';
import '../../../../core/ui/app_snack_bar.dart';
import '../../../help_request/presentation/screens/home_screen.dart';
import '../providers/auth_provider.dart';

class SecureSignInScreen extends StatefulWidget {
  const SecureSignInScreen({super.key});

  @override
  State<SecureSignInScreen> createState() => _SecureSignInScreenState();
}

class _SecureSignInScreenState extends State<SecureSignInScreen> {
  Future<void> _authenticateAndGoHome(AuthMethod method) async {
    final authProvider = context.read<AuthProvider>();

    try {
      await authProvider.signIn(method);
      if (!mounted || !authProvider.isSignedIn) {
        return;
      }

      _goHome();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _startPhoneVerification() async {
    final authProvider = context.read<AuthProvider>();

    try {
      String? phoneNumber = authProvider.pendingPhoneNumber;
      if (!authProvider.hasPendingPhoneVerification) {
        phoneNumber = await _promptForPhoneNumber();
        if (!mounted || phoneNumber == null) {
          return;
        }

        await authProvider.startPhoneNumberSignIn(phoneNumber);
      }

      if (!mounted) {
        return;
      }

      if (authProvider.isSignedIn) {
        _goHome();
        return;
      }

      if (!authProvider.hasPendingPhoneVerification) {
        throw const AuthException(
          'Verification is still pending. Please request the code again.',
        );
      }

      final smsCode = await _promptForSmsCode(
        authProvider.pendingPhoneNumber ?? phoneNumber ?? '',
      );
      if (!mounted || smsCode == null) {
        return;
      }

      await authProvider.confirmPhoneCode(smsCode);
      if (!mounted || !authProvider.isSignedIn) {
        return;
      }

      _goHome();
    } catch (error) {
      _showError(error);
    }
  }

  Future<String?> _promptForPhoneNumber() async {
    return showDialog<String>(
      context: context,
      builder: (_) => const _PhoneNumberDialog(),
    );
  }

  Future<String?> _promptForSmsCode(String phoneNumber) async {
    return showDialog<String>(
      context: context,
      builder: (_) => _SmsCodeDialog(phoneNumber: phoneNumber),
    );
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

    showGhmeraSnackBar(
      context,
      message: message,
      type: SnackBarType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final authOptions = <(AuthMethod, IconData, String)>[
      (AuthMethod.google, Icons.g_mobiledata_rounded, 'Continue with Google'),
      (AuthMethod.apple, Icons.apple_rounded, 'Continue with Apple'),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        leading: Navigator.of(context).canPop()
            ? uniformBackButton(context)
            : null,
        title: uniformAppBarTitle(
          context,
          title: 'Secure sign in',
          subtitle: 'Choose your trusted method to continue.',
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: appleLikeScreenGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
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
                      Text(
                        'Secure sign in',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF132B27),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Choose a secure sign-in method to continue into your help dashboard.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF50625F),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      for (final option in authOptions) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: authProvider.isLoading
                                ? null
                                : () => _authenticateAndGoHome(option.$1),
                            icon: authProvider.isBusy(option.$1)
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(option.$2),
                            label: Text(option.$3),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: authProvider.isLoading
                              ? null
                              : _startPhoneVerification,
                          icon: authProvider.isBusy(AuthMethod.phone)
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                  ),
                                )
                              : const Icon(Icons.phone_iphone_rounded),
                          label: Text(
                            authProvider.hasPendingPhoneVerification
                                ? 'Enter code and continue'
                                : 'Verify phone number',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'By continuing, you enter the live product shell backed by your database data for requests, matching, trust workflows, and wellbeing activity.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF60716D),
                          height: 1.4,
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

class _PhoneNumberDialog extends StatefulWidget {
  const _PhoneNumberDialog();

  @override
  State<_PhoneNumberDialog> createState() => _PhoneNumberDialogState();
}

class _PhoneNumberDialogState extends State<_PhoneNumberDialog> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Verify phone number'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '+233 555 123 456',
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.length < 7) {
              return 'Enter a valid phone number.';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Send code')),
      ],
    );
  }
}

class _SmsCodeDialog extends StatefulWidget {
  const _SmsCodeDialog({required this.phoneNumber});

  final String phoneNumber;

  @override
  State<_SmsCodeDialog> createState() => _SmsCodeDialogState();
}

class _SmsCodeDialogState extends State<_SmsCodeDialog> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Enter verification code'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.phoneNumber.isEmpty
                  ? 'Enter the SMS code you received.'
                  : 'Enter the SMS code sent to ${widget.phoneNumber}.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controller,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'SMS code',
                hintText: '123456',
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.length < 4) {
                  return 'Enter the verification code.';
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
        FilledButton(onPressed: _submit, child: const Text('Verify')),
      ],
    );
  }
}
