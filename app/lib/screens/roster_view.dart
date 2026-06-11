import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';
import '../services/employee_service.dart';
import '../theme.dart';
import '../utils/codes.dart';
import '../widgets/ui.dart';

class RosterView extends StatelessWidget {
  final String groupId;
  const RosterView({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Employee>>(
      stream: EmployeeService().watch(groupId),
      builder: (context, snap) {
        final employees = snap.data ?? [];
        return PageBody(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Roster', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text(
                        employees.isEmpty
                            ? 'Add the employees you want to invite.'
                            : '${employees.length} employee${employees.length == 1 ? '' : 's'}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _importCsv(context),
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Import CSV'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () => _addEmployee(context),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Add employee'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (snap.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator(color: AppColors.coral)),
              )
            else if (employees.isEmpty)
              _empty(context)
            else
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < employees.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _EmployeeRow(
                        employee: employees[i],
                        onDelete: () => EmployeeService().delete(groupId, employees[i].id!),
                        onInvite: () => _showInvite(context, employees[i]),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Widget _empty(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.coralSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.group_add_rounded, color: AppColors.coralStrong, size: 28),
            ),
            const SizedBox(height: 16),
            Text('No employees yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('Add employees one by one, or import a CSV.',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _importCsv(context),
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Import CSV'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () => _addEmployee(context),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Add employee'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addEmployee(BuildContext context) async {
    final e = await showDialog<Employee>(
      context: context,
      builder: (_) => const _AddEmployeeDialog(),
    );
    if (e == null) return;
    // Generate the invite code up front so the link is ready immediately.
    final withCode = e.copyWith(accessCode: generateAccessCode());
    final id = await EmployeeService().add(groupId, withCode);
    if (!context.mounted) return;
    // Show the invite right away: clear confirmation that the link exists.
    showDialog(
      context: context,
      builder: (_) => _InviteDialog(
        name: withCode.fullName,
        url: buildEnrollUrl(Uri.base.origin, groupId, id),
        code: withCode.accessCode,
        justCreated: true,
      ),
    );
  }

  Future<void> _importCsv(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;

    final employees = _parseCsv(bytes);
    if (!context.mounted) return;
    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid rows found in the CSV.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import roster'),
        content: Text(
            'Found ${employees.length} employee${employees.length == 1 ? '' : 's'} to import. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.muted))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import')),
        ],
      ),
    );
    if (confirmed != true) return;

    final count = await EmployeeService().addMany(groupId, employees);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $count employees')),
      );
    }
  }

  Future<void> _showInvite(BuildContext context, Employee e) async {
    final code = await EmployeeService().ensureAccessCode(groupId, e);
    final url = buildEnrollUrl(Uri.base.origin, groupId, e.id!);
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => _InviteDialog(name: e.fullName, url: url, code: code),
    );
  }
}

class _InviteDialog extends StatelessWidget {
  final String name;
  final String url;
  final String code;
  final bool justCreated;
  const _InviteDialog({
    required this.name,
    required this.url,
    required this.code,
    this.justCreated = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          if (justCreated) ...[
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFFE7F6EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Color(0xFF0A7D4F), size: 20),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(justCreated
                ? '${name.isEmpty ? 'Employee' : name} added'
                : 'Enrollment invite'),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              justCreated
                  ? 'Their enrollment link and access code are ready. Send both to '
                      '${name.isEmpty ? 'the employee' : name} to start enrollment.'
                  : 'Send this link and access code to ${name.isEmpty ? 'the employee' : name}. '
                      'They open the link and enter the code to start enrollment.',
              style: const TextStyle(color: AppColors.muted, fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 20),
            LabeledField(label: 'Enrollment link', child: _CopyBox(text: url)),
            const SizedBox(height: 16),
            LabeledField(label: 'Access code', child: _CopyBox(text: code, big: true)),
          ],
        ),
      ),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    );
  }
}

class _CopyBox extends StatelessWidget {
  final String text;
  final bool big;
  const _CopyBox({required this.text, this.big = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              text,
              style: big
                  ? const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color: AppColors.navy)
                  : const TextStyle(fontSize: 13.5, color: AppColors.ink),
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.muted),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied')),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Parses CSV bytes into employees. Expected columns (in order):
/// First Name, Last Name, Email, Phone. A header row is auto-detected and skipped.
List<Employee> _parseCsv(List<int> bytes) {
  final text = utf8.decode(bytes, allowMalformed: true);
  final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
      .convert(text);
  final out = <Employee>[];
  for (final row in rows) {
    if (row.length < 3) continue;
    final first = row[0].toString().trim();
    final last = row[1].toString().trim();
    final email = row[2].toString().trim();
    final phone = row.length > 3 ? row[3].toString().trim() : '';
    // Skip header / invalid rows (email must look like an address).
    if (!email.contains('@') || !email.contains('.')) continue;
    if (first.isEmpty && last.isEmpty) continue;
    out.add(Employee(
      firstName: first,
      lastName: last,
      email: email,
      phone: phone,
      accessCode: generateAccessCode(),
    ));
  }
  return out;
}

class _EmployeeRow extends StatelessWidget {
  final Employee employee;
  final VoidCallback onDelete;
  final VoidCallback onInvite;
  const _EmployeeRow({
    required this.employee,
    required this.onDelete,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final created = employee.createdAt != null
        ? DateFormat.yMMMd().format(employee.createdAt!)
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.coralSoft,
            child: Text(
              _initials(employee),
              style: const TextStyle(
                  color: AppColors.coralStrong, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(employee.fullName.isEmpty ? 'Unnamed' : employee.fullName,
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  [employee.email, if (employee.phone.isNotEmpty) employee.phone].join('  ·  '),
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          _statusPill(employee.status),
          const SizedBox(width: 14),
          if (created.isNotEmpty)
            Text(created, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onInvite,
            icon: const Icon(Icons.link_rounded, size: 16),
            label: const Text('Invite link'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.muted),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  String _initials(Employee e) {
    final a = e.firstName.isNotEmpty ? e.firstName[0] : '';
    final b = e.lastName.isNotEmpty ? e.lastName[0] : '';
    final i = (a + b).toUpperCase();
    return i.isEmpty ? '?' : i;
  }

  Widget _statusPill(EmployeeStatus s) {
    switch (s) {
      case EmployeeStatus.completed:
        return const StatusPill('Completed',
            color: Color(0xFF0A7D4F), background: Color(0xFFE7F6EE));
      case EmployeeStatus.inProgress:
        return const StatusPill('In progress',
            color: Color(0xFF8A5A00), background: Color(0xFFFDF3E2));
      case EmployeeStatus.opened:
        return const StatusPill('Opened',
            color: AppColors.navy, background: Color(0xFFEEF3FB));
      case EmployeeStatus.pending:
        return const StatusPill('Pending',
            color: AppColors.muted, background: AppColors.field);
    }
  }
}

class _AddEmployeeDialog extends StatefulWidget {
  const _AddEmployeeDialog();

  @override
  State<_AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<_AddEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      Employee(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add employee'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'First name',
                      child: TextFormField(
                        controller: _first,
                        decoration: const InputDecoration(hintText: 'Jane'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LabeledField(
                      label: 'Last name',
                      child: TextFormField(
                        controller: _last,
                        decoration: const InputDecoration(hintText: 'Doe'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: 'Email',
                child: TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'jane@acme.com'),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: 'Phone',
                child: TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: '(555) 123-4567'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted))),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
