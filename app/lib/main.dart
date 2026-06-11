import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const EnrollmentApp());
}

class EnrollmentApp extends StatelessWidget {
  const EnrollmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthPass Enrollment',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _Placeholder(),
    );
  }
}

/// Temporary landing page — confirms the app is wired to Firebase.
/// Replaced by the admin portal in M2.
class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HEALTH ACCESS BUNDLE',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.secondary, letterSpacing: 1.6)),
                  const SizedBox(height: 8),
                  Text('Group Enrollment Platform',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('Connected to Firebase. Admin portal coming next (M2).',
                      style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
