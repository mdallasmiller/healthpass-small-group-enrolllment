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
    return EnrollShell(
      loading: _loading,
      child: _loadError != null ? _errorBody() : _formBody(),
    );
  }

  Widget _errorBody() {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.coralSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.link_off_rounded, color: AppColors.coralStrong, size: 26),
        ),
        const SizedBox(height: 18),
        Text('Link not available', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(_loadError!, style: const TextStyle(color: AppColors.muted, height: 1.55)),
        const SizedBox(height: 22),
        const HelpFooter(),
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
        Eyebrow('${_group!.name}  |  Benefits Enrollment'),
        const SizedBox(height: 12),
        Text('Welcome, $first', style: theme.textTheme.headlineSmall?.copyWith(fontSize: 26)),
        const SizedBox(height: 8),
        const Text(
          'Enter the access code from your invitation to review your plan options and enroll.',
          style: TextStyle(color: AppColors.muted, height: 1.55),
        ),
        const SizedBox(height: 28),
        LabeledField(
          label: 'Access code',
          child: TextField(
            controller: _codeCtrl,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              UpperCaseFormatter(),
              LengthLimitingTextInputFormatter(8),
            ],
            onSubmitted: (_) => _submit(),
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 10,
                color: AppColors.navy),
            decoration: const InputDecoration(hintText: '......'),
          ),
        ),
        if (_codeError != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 16, color: AppColors.coralStrong),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_codeError!,
                    style: const TextStyle(color: AppColors.coralStrong, fontSize: 13.5)),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submit,
            child: const Text('Begin enrollment'),
          ),
        ),
        const SizedBox(height: 24),
        const HelpFooter(),
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

/// Branded full-page shell for the employee-facing flow: navy gradient
/// backdrop, soft decorative shapes, and a centered card with a coral accent.
class EnrollShell extends StatelessWidget {
  final Widget child;
  final bool loading;
  final double maxWidth;
  const EnrollShell({
    super.key,
    required this.child,
    this.loading = false,
    this.maxWidth = 520,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF11304F), AppColors.navy, Color(0xFF0A1F36)],
          ),
        ),
        child: Stack(
          children: [
            // Soft decorative shapes
            Positioned(
              top: -120,
              right: -80,
              child: _circle(360, Colors.white.withValues(alpha: 0.04)),
            ),
            Positioned(
              bottom: -140,
              left: -100,
              child: _circle(420, Colors.white.withValues(alpha: 0.03)),
            ),
            Positioned(
              top: 120,
              left: 60,
              child: _circle(14, AppColors.coral.withValues(alpha: 0.5)),
            ),
            Positioned(
              bottom: 160,
              right: 90,
              child: _circle(10, AppColors.periwinkle.withValues(alpha: 0.45)),
            ),
            // Content
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 36, bottom: 8),
                    child: Center(child: BrandWordmark(size: 24)),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: loading
                              ? const Padding(
                                  padding: EdgeInsets.all(48),
                                  child: Center(
                                    child: CircularProgressIndicator(color: AppColors.coral),
                                  ),
                                )
                              : _card(child),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 22, top: 8),
                    child: Text(
                      'HealthPass + Health Access Solutions',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45), fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 50,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 5, color: AppColors.coral),
          Padding(padding: const EdgeInsets.all(36), child: child),
        ],
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

/// "Need help?" footer used across the employee flow.
class HelpFooter extends StatelessWidget {
  const HelpFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          const Icon(Icons.support_agent_rounded, size: 18, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Questions? Email the HealthPass team at ',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                children: [
                  TextSpan(
                    text: 'enrollment@joinhealthpass.com',
                    style: TextStyle(
                        color: AppColors.navy, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown after a valid code: a welcome screen previewing the enrollment steps.
/// The full portal (M5) replaces the step list with the real flow.
class EnrollPortalPlaceholder extends StatelessWidget {
  final Group group;
  final Employee employee;
  const EnrollPortalPlaceholder({super.key, required this.group, required this.employee});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = [
      ('Personal information', 'Your details, address, and dependents'),
      ('Health coverage', 'Compare plan options and live monthly cost'),
      if (group.dental.enabled) ('Dental coverage', 'Optional dental for you and your family'),
      ('Review & sign', 'Confirm your selections and sign'),
    ];
    return EnrollShell(
      maxWidth: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F6EE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.verified_rounded,
                    color: Color(0xFF0A7D4F), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You\'re in, ${employee.firstName}!',
                        style: theme.textTheme.headlineSmall?.copyWith(fontSize: 23)),
                    const SizedBox(height: 2),
                    Text('Benefits enrollment for ${group.name}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 13.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const Text(
            'HERE\'S WHAT\'S AHEAD',
            style: TextStyle(
                color: AppColors.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++) ...[
            _StepTile(index: i + 1, title: steps[i].$1, subtitle: steps[i].$2),
            if (i < steps.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 17),
                child: Container(width: 2, height: 14, color: AppColors.line),
              ),
          ],
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: null,
              child: const Text('Start (available soon)'),
            ),
          ),
          const SizedBox(height: 22),
          const HelpFooter(),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;
  const _StepTile({required this.index, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: index == 1 ? AppColors.coral : AppColors.field,
            shape: BoxShape.circle,
            border: index == 1 ? null : Border.all(color: AppColors.line, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: TextStyle(
              color: index == 1 ? Colors.white : AppColors.muted,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 15)),
              const SizedBox(height: 1),
              Text(subtitle,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
