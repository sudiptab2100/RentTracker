import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/phone_number.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_providers.dart';
import '../../widgets/phone_field.dart';
import '../../widgets/ui_helpers.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  PhoneNumber _phone = PhoneNumber.empty;
  final _code = TextEditingController();
  bool _loading = false;
  bool _codeSent = false;
  String? _verificationId;
  int? _resendToken;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_phone.number.length != 10) {
      showSnack(context, 'Enter a valid 10-digit number', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).verifyPhoneNumber(
            phoneNumber: _phone.e164,
            resendToken: _resendToken,
            onAutoVerify: (credential) async {
              await ref
                  .read(authServiceProvider)
                  .signInWithPhoneCredential(credential);
            },
            codeSent: (verificationId, token) {
              if (!mounted) return;
              setState(() {
                _verificationId = verificationId;
                _resendToken = token;
                _codeSent = true;
                _loading = false;
              });
              showSnack(context, 'Verification code sent.');
            },
            onError: (e) {
              if (!mounted) return;
              setState(() => _loading = false);
              showSnack(context, e.message, isError: true);
            },
          );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showSnack(context, '$e', isError: true);
      }
    }
  }

  Future<void> _verify() async {
    if (_verificationId == null) return;
    if (_code.text.trim().length < 4) {
      showSnack(context, 'Enter the code you received', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(authServiceProvider)
          .signInWithSmsCode(_verificationId!, _code.text);
    } on AuthException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } on FirebaseAuthException catch (e) {
      if (mounted) showSnack(context, e.message ?? 'Verification failed', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Phone sign in')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.sms_outlined, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  if (!_codeSent)
                    PhoneField(
                      label: 'Phone number',
                      icon: Icons.phone_outlined,
                      initial: _phone,
                      onChanged: (v) => _phone = v,
                    )
                  else
                    Text('Code sent to ${_phone.display}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium),
                  if (_codeSent) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Verification code',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading
                        ? null
                        : _codeSent
                            ? _verify
                            : _sendCode,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_codeSent ? 'Verify & sign in' : 'Send code'),
                  ),
                  if (_codeSent)
                    TextButton(
                      onPressed: _loading ? null : _sendCode,
                      child: const Text('Resend code'),
                    ),
                  TextButton(
                    onPressed: _loading ? null : () => context.pop(),
                    child: const Text('Back to sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
