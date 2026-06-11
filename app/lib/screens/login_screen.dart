import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _isSignUp = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (_isSignUp) {
        await _auth.signUp(_email.text, _password.text);
      } else {
        await _auth.signIn(_email.text, _password.text);
      }
      // AuthGate handles navigation on success.
    } catch (e) {
      setState(() => _error = AuthService.describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final form = _buildForm(context);
          if (!wide) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Padding(padding: const EdgeInsets.all(24), child: form),
                  ),
                ),
              ),
            );
          }
          return Row(
            children: [
              Expanded(flex: 5, child: _Hero()),
              Expanded(
                flex: 6,
                child: Center(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Padding(padding: const EdgeInsets.all(40), child: form),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Eyebrow('Admin Portal'),
          const SizedBox(height: 10),
          Text(_isSignUp ? 'Create admin account' : 'Sign in',
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            _isSignUp
                ? 'Set up the first administrator for this workspace.'
                : 'Manage groups, rates, and enrollment campaigns.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 28),
          LabeledField(
            label: 'Email',
            child: TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              decoration: const InputDecoration(hintText: 'you@company.com'),
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Enter a valid email.' : null,
            ),
          ),
          const SizedBox(height: 18),
          LabeledField(
            label: 'Password',
            child: TextFormField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(hintText: '••••••••'),
              onFieldSubmitted: (_) => _submit(),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'At least 6 characters.' : null,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(_error!),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : Text(_isSignUp ? 'Create account' : 'Sign in'),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _isSignUp = !_isSignUp;
                        _error = null;
                      }),
              child: Text(_isSignUp
                  ? 'Have an account? Sign in'
                  : 'First time setup? Create admin account'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.coralSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.coralLine),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.coralStrong, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Color(0xFF8A3A33), fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.navy2],
        ),
      ),
      padding: const EdgeInsets.all(56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const BrandWordmark(size: 24),
          const SizedBox(height: 40),
          const Eyebrow('Health Access Bundle'),
          const SizedBox(height: 14),
          Text(
            'Small Group\nEnrollment Platform',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: Colors.white, fontSize: 34, height: 1.15),
          ),
          const SizedBox(height: 18),
          Text(
            'Configure groups and rates, invite employees with secure links, '
            'and track enrollment from one place.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 15, height: 1.6),
          ),
        ],
      ),
    );
  }
}
