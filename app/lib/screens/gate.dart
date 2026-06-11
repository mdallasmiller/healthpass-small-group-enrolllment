import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'admin_shell.dart';
import 'login_screen.dart';

/// Routes between login, admin portal, and the not-authorized state based on
/// the current auth + admin status.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authState,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }
        final user = snap.data;
        if (user == null) return const LoginScreen();
        return AdminGate(user: user);
      },
    );
  }
}

class AdminGate extends StatefulWidget {
  final User user;
  const AdminGate({super.key, required this.user});

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  final _admin = AdminService();
  late Future<bool> _isAdmin;

  @override
  void initState() {
    super.initState();
    _isAdmin = _admin.isAdmin(widget.user.uid);
  }

  void _refresh() => setState(() => _isAdmin = _admin.isAdmin(widget.user.uid));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isAdmin,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }
        if (snap.data == true) return const AdminShell();
        return NotAuthorizedScreen(user: widget.user, onGranted: _refresh);
      },
    );
  }
}

/// Shown when a signed-in user is not (yet) an admin. Offers to claim the first
/// admin slot, and otherwise displays the UID for manual provisioning.
class NotAuthorizedScreen extends StatefulWidget {
  final User user;
  final VoidCallback onGranted;
  const NotAuthorizedScreen({super.key, required this.user, required this.onGranted});

  @override
  State<NotAuthorizedScreen> createState() => _NotAuthorizedScreenState();
}

class _NotAuthorizedScreenState extends State<NotAuthorizedScreen> {
  final _admin = AdminService();
  bool _busy = false;
  String? _message;

  Future<void> _claim() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final granted = await _admin.bootstrapFirstAdmin();
      if (granted) {
        widget.onGranted();
      } else {
        setState(() => _message =
            'An administrator already exists. Ask them to add you under /admins.');
      }
    } catch (e) {
      setState(() => _message =
          'Could not reach the access service. Ask an admin to add a document at '
          'admins/${widget.user.uid}, or deploy Cloud Functions first.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Admin Portal'),
                    const SizedBox(height: 10),
                    Text('Access required', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      'You\'re signed in as ${widget.user.email}, but this account '
                      'is not an administrator yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 20),
                    _UidRow(uid: widget.user.uid),
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      Text(_message!,
                          style: const TextStyle(color: Color(0xFF8A3A33), fontSize: 13.5)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _claim,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4, color: Colors.white),
                            )
                          : const Text('Claim admin access'),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => AuthService().signOut(),
                        child: const Text('Sign out'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UidRow extends StatelessWidget {
  final String uid;
  const _UidRow({required this.uid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(uid,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12.5, color: AppColors.ink)),
          ),
          IconButton(
            tooltip: 'Copy UID',
            icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.muted),
            onPressed: () => Clipboard.setData(ClipboardData(text: uid)),
          ),
        ],
      ),
    );
  }
}
