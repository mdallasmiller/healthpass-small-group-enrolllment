import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/employee.dart';
import '../models/group.dart';
import '../services/employee_service.dart';
import '../services/enrollment_service.dart';
import '../services/group_service.dart';
import '../theme.dart';
import '../utils/codes.dart';
import '../utils/formatters.dart';
import '../utils/reports.dart';
import '../utils/roster_import.dart';
import '../utils/web_download.dart';
import '../widgets/ui.dart';
import 'enroll_portal.dart';
import 'enrollment_detail_screen.dart';

class RosterView extends StatefulWidget {
  final Group group;
  const RosterView({super.key, required this.group});

  String get groupId => group.id!;

  @override
  State<RosterView> createState() => _RosterViewState();
}

class _RosterViewState extends State<RosterView> {
  String _searchQuery = '';
  String _sortMode = 'name'; // 'name' or 'status'
  final _searchController = TextEditingController();

  String get groupId => widget.group.id!;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Employee> _filterAndSort(List<Employee> employees) {
    // Filter by search query
    var filtered = employees;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where((e) =>
              e.firstName.toLowerCase().contains(query) ||
              e.lastName.toLowerCase().contains(query) ||
              e.fullName.toLowerCase().contains(query))
          .toList();
    }

    // Sort
    if (_sortMode == 'name') {
      filtered.sort((a, b) => a.firstName.compareTo(b.firstName));
    } else if (_sortMode == 'status') {
      // Completed first, then others
      filtered.sort((a, b) {
        final aCompleted = a.status == EmployeeStatus.completed ? 0 : 1;
        final bCompleted = b.status == EmployeeStatus.completed ? 0 : 1;
        return aCompleted.compareTo(bCompleted);
      });
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Employee>>(
      stream: EmployeeService().watch(groupId),
      builder: (context, snap) {
        final employees = snap.data ?? [];
        final filtered = _filterAndSort(employees);
        return PageBody(
          children: [
            // Title and buttons row
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
                            : filtered.isEmpty && _searchQuery.isNotEmpty
                                ? 'No matches for "$_searchQuery"'
                                : '${filtered.length} of ${employees.length} employee${employees.length == 1 ? '' : 's'}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                if (widget.group.status == GroupStatus.draft)
                  OutlinedButton.icon(
                    onPressed: () => _finalize(context),
                    icon: const Icon(Icons.verified_rounded, size: 18),
                    label: const Text('Finalize group'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0A7D4F),
                      side: const BorderSide(color: Color(0xFF9ED9BC), width: 1.5),
                    ),
                  ),
                if (widget.group.status == GroupStatus.draft) const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _importCensus(context),
                  icon: const Icon(Icons.table_chart_outlined, size: 18),
                  label: const Text('Import census'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _importCsv(context),
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Import roster'),
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
            // Search and sort controls
            if (employees.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search by name...',
                        hintStyle: const TextStyle(color: AppColors.muted),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.muted),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'name',
                        label: Text('A-Z'),
                        icon: Icon(Icons.sort_by_alpha_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: 'status',
                        label: Text('Status'),
                        icon: Icon(Icons.done_all_rounded, size: 16),
                      ),
                    ],
                    selected: {_sortMode},
                    onSelectionChanged: (selected) =>
                        setState(() => _sortMode = selected.first),
                  ),
                ],
              ),
            if (employees.isNotEmpty) const SizedBox(height: 16),
            if (employees.isNotEmpty) ...[
              _legend(),
              const SizedBox(height: 12),
              _reportsBar(context),
              const SizedBox(height: 12),
            ],
            if (snap.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator(color: AppColors.coral)),
              )
            else if (employees.isEmpty)
              _empty(context)
            else if (filtered.isEmpty)
              _noResults()
            else
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < filtered.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _EmployeeRow(
                        employee: filtered[i],
                        onDelete: () => EmployeeService().delete(groupId, filtered[i].id!),
                        onInvite: () => _showInvite(context, filtered[i]),
                        onSendInvite: () => _sendInviteToOne(context, filtered[i]),
                        onOpen: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => EnrollPortal(
                              group: widget.group, employee: filtered[i], adminMode: true),
                        )),
                        onView: filtered[i].status == EmployeeStatus.completed
                            ? () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => EnrollmentDetailScreen(
                                    groupId: groupId,
                                    employee: filtered[i],
                                  ),
                                ))
                            : null,
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

  Widget _reportsBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Text('Finalize / reports',
                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
          ),
          _reportBtn('Census CSV', Icons.table_view_rounded,
              () => _exportCensus(context, pdf: false)),
          _reportBtn('Census PDF', Icons.picture_as_pdf_outlined,
              () => _exportCensus(context, pdf: true)),
          _reportBtn('Deductions CSV', Icons.table_view_rounded,
              () => _exportDeduction(context, pdf: false)),
          _reportBtn('Deductions PDF', Icons.picture_as_pdf_outlined,
              () => _exportDeduction(context, pdf: true)),
          _DentalCountChip(groupId: groupId),
        ],
      ),
    );
  }

  Widget _reportBtn(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Future<List<Map<String, dynamic>>?> _loadEnrollments(BuildContext context) async {
    final enr = await EnrollmentService().getGroupEnrollments(groupId);
    if (enr.isEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No submitted enrollments yet.')),
      );
      return null;
    }
    return enr;
  }

  Future<void> _exportCensus(BuildContext context, {required bool pdf}) async {
    final enr = await _loadEnrollments(context);
    if (enr == null) return;
    final safe = widget.group.name.isEmpty ? 'group' : widget.group.name;
    if (pdf) {
      await Printing.sharePdf(
          bytes: await censusPdf(widget.group.name, enr), filename: '$safe census.pdf');
    } else {
      downloadText('$safe census.csv', censusCsv(widget.group.name, enr));
    }
  }

  Future<void> _exportDeduction(BuildContext context, {required bool pdf}) async {
    final enr = await _loadEnrollments(context);
    if (enr == null) return;
    final safe = widget.group.name.isEmpty ? 'group' : widget.group.name;
    if (pdf) {
      await Printing.sharePdf(
          bytes: await deductionPdf(widget.group.name, enr),
          filename: '$safe deduction report.pdf');
    } else {
      downloadText('$safe deduction report.csv', deductionCsv(enr));
    }
  }

  Widget _legend() {
    Widget item(IconData icon, String bold, String rest) => Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: AppColors.navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12.5, height: 1.4),
                    children: [
                      TextSpan(
                          text: bold,
                          style: const TextStyle(
                              color: AppColors.navy, fontWeight: FontWeight.w700)),
                      TextSpan(text: rest),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          item(Icons.play_circle_outline_rounded, 'Enroll now',
              ': open the portal here, in person. No access code needed.'),
          const SizedBox(width: 20),
          item(Icons.link_rounded, 'Send link + code',
              ': copy the employee\'s link + code to email/text them. They enter the code to start.'),
        ],
      ),
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
                  onPressed: () => _importCensus(context),
                  icon: const Icon(Icons.table_chart_outlined, size: 18),
                  label: const Text('Import census'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _importCsv(context),
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Import roster'),
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

  Widget _noResults() {
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
                color: AppColors.field,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.search_off_rounded, color: AppColors.muted, size: 28),
            ),
            const SizedBox(height: 16),
            Text('No matches found', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('Try a different search term.',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Future<void> _finalize(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalize group?'),
        content: Text(
          'This marks "${widget.group.name}" as active and ready for enrollment. '
          'You can still edit it afterwards.',
          style: const TextStyle(color: AppColors.muted, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.muted))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Finalize')),
        ],
      ),
    );
    if (ok != true) return;
    await GroupService().update(widget.group.id!, widget.group.copyWith(status: GroupStatus.active));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group finalized. Status set to Active')),
      );
    }
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
        url: buildEnrollUrl(kEnrollBaseUrl, groupId, id),
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

    final parsed = parseRosterCsv(bytes);
    if (!context.mounted) return;
    if (parsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid rows found in the CSV.')),
      );
      return;
    }
    final (fresh, skipped) = await _dedupe(parsed);
    if (!context.mounted) return;
    if (fresh.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            'All ${parsed.length} already in the roster. Nothing to import.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import roster'),
        content: Text(
            'Found ${fresh.length} new employee${fresh.length == 1 ? '' : 's'} to import.'
            '${skipped > 0 ? ' ($skipped duplicate(s) already in the roster will be skipped.)' : ''} Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.muted))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import')),
        ],
      ),
    );
    if (confirmed != true) return;

    final count = await EmployeeService().addMany(groupId, fresh);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $count'
            '${skipped > 0 ? ', skipped $skipped duplicate(s)' : ''}')),
      );
    }
  }

  /// Drops parsed employees whose email or SSN already exists in the roster
  /// (and de-duplicates within the batch). Returns the fresh ones + skip count.
  Future<(List<Employee>, int)> _dedupe(List<Employee> parsed) async {
    final existing = await EmployeeService().getAll(groupId);
    final emails = <String>{};
    final ssns = <String>{};
    for (final e in existing) {
      if (e.email.trim().isNotEmpty) emails.add(e.email.trim().toLowerCase());
      if (e.ssn.trim().isNotEmpty) ssns.add(e.ssn.trim());
    }
    final fresh = <Employee>[];
    var skipped = 0;
    for (final e in parsed) {
      final email = e.email.trim().toLowerCase();
      final ssn = e.ssn.trim();
      final dup = (email.isNotEmpty && emails.contains(email)) ||
          (ssn.isNotEmpty && ssns.contains(ssn));
      if (dup) {
        skipped++;
        continue;
      }
      if (email.isNotEmpty) emails.add(email);
      if (ssn.isNotEmpty) ssns.add(ssn);
      fresh.add(e);
    }
    return (fresh, skipped);
  }

  Future<void> _importCensus(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;

    final parsed = parseCensusCsv(bytes);
    if (!context.mounted) return;
    if (parsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid rows found in the census.')),
      );
      return;
    }
    final (fresh, skipped) = await _dedupe(parsed);
    if (!context.mounted) return;
    if (fresh.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            'All ${parsed.length} already in the roster. Nothing to import.')),
      );
      return;
    }
    final ineligible = fresh.where((e) => !e.eligible).length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import census'),
        content: Text(
          'Found ${fresh.length} new employee${fresh.length == 1 ? '' : 's'}. '
          'Their demographics will auto-load into the enrollment portal.'
          '${skipped > 0 ? '\n\n$skipped duplicate(s) already in the roster will be skipped.' : ''}'
          '${ineligible > 0 ? '\n\n$ineligible marked ineligible (no invitation will be sent).' : ''}',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.muted))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import')),
        ],
      ),
    );
    if (confirmed != true) return;

    final count = await EmployeeService().addMany(groupId, fresh);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $count'
            '${skipped > 0 ? ', skipped $skipped duplicate(s)' : ''}')),
      );
    }
  }

  /// Sends this one employee their invite (email + SMS) via the sendInvites
  /// Cloud Function with an employeeId filter.
  Future<void> _sendInviteToOne(BuildContext context, Employee e) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Sending invitation to ${e.fullName}…')),
    );
    try {
      final res = await FirebaseFunctions.instance
          .httpsCallable('sendInvites')
          .call({'groupId': groupId, 'employeeId': e.id});
      final data = res.data as Map?;
      final sent = (data?['sent'] ?? 0) as int;
      messenger.showSnackBar(SnackBar(
        content: Text(sent > 0
            ? 'Invitation sent to ${e.fullName}.'
            : 'Nothing was sent — check the email/phone and sending setup.'),
      ));
    } catch (err) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not send: $err'),
      ));
    }
  }

  Future<void> _showInvite(BuildContext context, Employee e) async {
    final code = await EmployeeService().ensureAccessCode(groupId, e);
    final url = buildEnrollUrl(kEnrollBaseUrl, groupId, e.id!);
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
    return AppDialog(
      width: 520,
      title: justCreated
          ? '${name.isEmpty ? 'Employee' : name} added'
          : 'Enrollment invite',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (justCreated) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F6EE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF0A7D4F), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Saved. The invite is ready to send.',
                        style: TextStyle(
                            color: Color(0xFF0A5538),
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Send this link and access code to ${name.isEmpty ? 'the employee' : name}. '
            'They open the link and enter the code to start enrollment.',
            style: const TextStyle(color: AppColors.muted, fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: 20),
          LabeledField(label: 'Enrollment link', child: _CopyBox(text: url)),
          const SizedBox(height: 16),
          LabeledField(label: 'Access code', child: _CopyBox(text: code, big: true)),
        ],
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
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

/// Shows how many submitted enrollments elected dental coverage.
class _DentalCountChip extends StatefulWidget {
  final String groupId;
  const _DentalCountChip({required this.groupId});
  @override
  State<_DentalCountChip> createState() => _DentalCountChipState();
}

class _DentalCountChipState extends State<_DentalCountChip> {
  String? _text;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enr = await EnrollmentService().getGroupEnrollments(widget.groupId);
    final dental = enr.where((e) {
      final d = ((e['data'] as Map)['dental'] as Map?);
      return d != null && d['enrolled'] == true;
    }).length;
    if (mounted) setState(() => _text = 'Dental elected: $dental of ${enr.length}');
  }

  @override
  Widget build(BuildContext context) {
    if (_text == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.coralSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.medical_services_outlined, size: 15, color: AppColors.coralStrong),
          const SizedBox(width: 6),
          Text(_text!,
              style: const TextStyle(
                  color: AppColors.coralStrong, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  final Employee employee;
  final VoidCallback onDelete;
  final VoidCallback onInvite;
  final VoidCallback onSendInvite;
  final VoidCallback onOpen;
  final VoidCallback? onView;
  const _EmployeeRow({
    required this.employee,
    required this.onDelete,
    required this.onInvite,
    required this.onSendInvite,
    required this.onOpen,
    this.onView,
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
          if (!employee.eligible) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFDECEC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Ineligible',
                  style: TextStyle(
                      color: Color(0xFFB42318),
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5)),
            ),
            const SizedBox(width: 8),
          ],
          _statusPill(employee.status),
          const SizedBox(width: 14),
          if (created.isNotEmpty)
            Text(created, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
          const SizedBox(width: 12),
          if (onView != null)
            TextButton.icon(
              onPressed: onView,
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('View'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.navy,
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (onView != null) const SizedBox(width: 4),
          Tooltip(
            message: 'Enroll in person now: opens the portal directly, no access code needed.',
            child: TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
              label: const Text('Enroll now'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.navy,
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Copy the employee\'s personal link + access code to send to them.',
            child: OutlinedButton.icon(
              onPressed: onInvite,
              icon: const Icon(Icons.link_rounded, size: 16),
              label: const Text('Send link + code'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Email + text this employee their enrollment link and code now.',
            child: FilledButton.icon(
              onPressed: onSendInvite,
              icon: const Icon(Icons.send_rounded, size: 15),
              label: const Text('Send invitation'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                visualDensity: VisualDensity.compact,
              ),
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
    return AppDialog(
      title: 'Add employee',
      width: 460,
      content: Form(
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
                  inputFormatters: [phoneChars],
                  decoration: const InputDecoration(hintText: '(555) 123-4567'),
                ),
              ),
            ],
          ),
        ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted))),
        const SizedBox(width: 8),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
