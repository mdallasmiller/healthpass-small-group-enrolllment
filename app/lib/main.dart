import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'screens/gate.dart';
import 'screens/enroll_entry_screen.dart';
import 'screens/hr_form_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final params = Uri.base.queryParameters;
  runApp(EnrollmentApp(
    enrollGroupId: params['g'],
    enrollEmployeeId: params['e'],
    hrGroupId: params['hr'],
  ));
}

class EnrollmentApp extends StatelessWidget {
  /// When the app is opened via a per-employee enrollment link
  /// (`?g=<groupId>&e=<employeeId>`) it routes to the enrollment portal
  /// instead of the admin app.
  final String? enrollGroupId;
  final String? enrollEmployeeId;

  /// When opened via an HR manager link (`?hr=<groupId>`)
  /// it routes to the HR form.
  final String? hrGroupId;

  const EnrollmentApp({
    super.key,
    this.enrollGroupId,
    this.enrollEmployeeId,
    this.hrGroupId,
  });

  @override
  Widget build(BuildContext context) {
    final isEnroll = enrollGroupId != null && enrollEmployeeId != null;
    final isHr = hrGroupId != null;
    return MaterialApp(
      title: 'HealthPass Enrollment',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: isHr
          ? HrFormScreen(groupId: hrGroupId!)
          : isEnroll
              ? EnrollEntryScreen(
                  groupId: enrollGroupId!,
                  employeeId: enrollEmployeeId!,
                )
              : const AuthGate(),
    );
  }
}
