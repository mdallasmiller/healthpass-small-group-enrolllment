import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/employee.dart';
import '../models/group.dart';
import '../services/employee_service.dart';
import '../services/group_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// Landing screen for a per-employee enrollment link. Validates the access code
/// before letting the employee into the portal.
class EnrollEntryScreen extends StatefulWidget {
  final String groupId;
  final String employeeId;
  const EnrollEntryScreen({super.key, required this.groupId, required this.employeeId});

  @override
  State<EnrollEntryScreen> createState() => _EnrollEntryScreenState();
}

class _EnrollEntryScreenState extends State<EnrollEntryScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = true;
  String? _loadError;
  Group? _group;
  Employee? _employee;
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      final g = await GroupService().getGroup(widget.groupId);
      final e = await EmployeeService().getEmployee(widget.groupId, widget.employeeId);
      if (!mounted) return;
      if (g == null || e == null) {
        setState(() {
          _loading = false;
          _loadError = 'This enrollment link is invalid or has expired.';
        });
        return;
      }
      setState(() {
        _group = g;
        _employee = e;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'We could not open your enrollment right now. Please try again later.';
        });
      }
    }
  }

  void _submit() {
    final entered = _codeCtrl.text.trim().toUpperCase();
    if (entered.isEmpty) {
      setState(() => _codeError = 'Enter your access code.');
      return;
    }
    if (entered != _employee!.accessCode.toUpperCase()) {
      setState(() => _codeError = 'Incorrect access code. Please check and try again.');
      return;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => EnrollPortalPlaceholder(group: _group!, employee: _employee!),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: AppColors.coral),
                    )
                  : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: _loadError != null ? _errorBody() : _formBody(),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandWordmark(color: AppColors.navy, size: 22),
        const SizedBox(height: 24),
        const Icon(Icons.link_off_rounded, color: AppColors.coralStrong, size: 28),
        const SizedBox(height: 12),
        Text('Link not available', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(_loadError!,
            style: const TextStyle(color: AppColors.muted, height: 1.5)),
      ],
    );
  }

  Widget _formBody() {
    final theme = Theme.of(context);
    final first = _employee!.firstName.isEmpty ? 'there' : _employee!.firstName;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandWordmark(color: AppColors.navy, size: 22),
        const SizedBox(height: 26),
        Eyebrow(_group!.name),
        const SizedBox(height: 10),
        Text('Enroll in your benefits', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Hi $first, enter the access code from your invitation to begin.',
          style: const TextStyle(color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 26),
        LabeledField(
          label: 'Access code',
          child: TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              UpperCaseFormatter(),
              LengthLimitingTextInputFormatter(8),
            ],
            onSubmitted: (_) => _submit(),
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 6),
            decoration: const InputDecoration(hintText: 'XXXXXX'),
          ),
        ),
        if (_codeError != null) ...[
          const SizedBox(height: 12),
          Text(_codeError!,
              style: const TextStyle(color: AppColors.coralStrong, fontSize: 13.5)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: _submit, child: const Text('Continue')),
        ),
      ],
    );
  }
}

/// Forces typed text to uppercase (so codes match regardless of caps lock).
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// Placeholder shown after a valid code. The full enrollment portal is M5.
class EnrollPortalPlaceholder extends StatelessWidget {
  final Group group;
  final Employee employee;
  const EnrollPortalPlaceholder({super.key, required this.group, required this.employee});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
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
                    const BrandWordmark(color: AppColors.navy, size: 22),
                    const SizedBox(height: 24),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F6EE),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF0A7D4F), size: 28),
                    ),
                    const SizedBox(height: 18),
                    Text('You are verified', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      'Welcome, ${employee.fullName}. Your enrollment for '
                      '${group.name} will continue here.',
                      style: const TextStyle(color: AppColors.muted, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.coralSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.coralLine),
                      ),
                      child: const Text(
                        'The enrollment portal (personal info, plan selection, '
                        'and signing) is the next milestone.',
                        style: TextStyle(color: Color(0xFF8A3A33), fontSize: 13),
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
