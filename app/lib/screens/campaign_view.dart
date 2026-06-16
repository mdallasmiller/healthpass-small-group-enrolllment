import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../models/group.dart';
import '../services/group_service.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../widgets/ui.dart';

const _emailSubject =
    'ENROLL NOW: Your Health Benefit through HealthPass + Health Access';
const _emailBody =
    'Hello [first name] You can now enroll in your new health benefit through '
    'HealthPass and Health Access Solutions. Our secure enrollment portal will '
    'gather your information and your plan selection. Enrollment begins today, '
    '[Send Date], and will end on [End Date]. Detailed information about the plan '
    'and the total cost to the employee will be presented in this enrollment '
    'portal. If you experience any issues, please email the HealthPass team at '
    'enrollment@joinhealthpass.com. [Begin Enrollment button] [unique group URL]. '
    'When prompted, use the following access code: [access code]';

class CampaignView extends StatefulWidget {
  final Group group;
  const CampaignView({super.key, required this.group});

  @override
  State<CampaignView> createState() => _CampaignViewState();
}

class _CampaignViewState extends State<CampaignView> {
  late final _sendDate = TextEditingController(text: widget.group.schedule.sendDate);
  late final _sendTime = TextEditingController(text: widget.group.schedule.sendTime);
  late final _warningDate =
      TextEditingController(text: widget.group.schedule.warningDate);
  late final _endDate = TextEditingController(text: widget.group.schedule.endDate);
  late final _emailSubjectC = TextEditingController(
      text: widget.group.templates.emailSubject.isEmpty
          ? _emailSubject
          : widget.group.templates.emailSubject);
  late final _emailBodyC = TextEditingController(
      text: widget.group.templates.emailBody.isEmpty
          ? _emailBody
          : widget.group.templates.emailBody);
  late final _smsBodyC = TextEditingController(
      text: widget.group.templates.smsBody.isEmpty
          ? _emailBody
          : widget.group.templates.smsBody);
  bool _busy = false;
  bool _sending = false;

  @override
  void dispose() {
    for (final c in [
      _sendDate, _sendTime, _warningDate, _endDate,
      _emailSubjectC, _emailBodyC, _smsBodyC,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final updated = widget.group.copyWith(
        schedule: EnrollmentSchedule(
          sendDate: _sendDate.text.trim(),
          sendTime: _sendTime.text.trim(),
          warningDate: _warningDate.text.trim(),
          endDate: _endDate.text.trim(),
        ),
        templates: MessageTemplates(
          emailSubject: _emailSubjectC.text.trim(),
          emailBody: _emailBodyC.text.trim(),
          smsBody: _smsBodyC.text.trim(),
        ),
      );
      await GroupService().update(widget.group.id!, updated);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendInvites() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: 'Send invitations?',
        content: const Text(
          'This emails every employee on the roster their enrollment link and '
          'access code. Continue?',
          style: TextStyle(color: AppColors.muted, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.muted))),
          const SizedBox(width: 8),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _sending = true);
    try {
      final res = await FirebaseFunctions.instance
          .httpsCallable('sendInvites')
          .call({'groupId': widget.group.id});
      final data = res.data as Map?;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Sent ${data?['sent'] ?? 0} of ${data?['total'] ?? 0} invitations')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sending is not enabled yet (requires Cloud Functions on Blaze).')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageBody(
      maxWidth: 980,
      children: [
        Text('Enrollment campaign', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('Schedule the enrollment window and review the messages employees receive.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
        const SizedBox(height: 20),
        _scheduleCard(),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _sending ? null : _sendInvites,
            icon: _sending
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: const Text('Send invitations now'),
          ),
        ),
        const SizedBox(height: 16),
        _sendingNote(),
        const SizedBox(height: 16),
        _templatesCard(),
        const SizedBox(height: 16),
        _inPersonCard(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _scheduleCard() {
    return SectionCard(
      title: 'Schedule',
      subtitle: 'Define the enrollment window.',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: LabeledField(
                  label: 'Send date',
                  child: TextField(
                    controller: _sendDate,
                    keyboardType: TextInputType.number,
                    inputFormatters: [DateSlashFormatter()],
                    decoration: const InputDecoration(hintText: 'MM/DD/YYYY'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LabeledField(
                  label: 'Send time',
                  child: TextField(
                    controller: _sendTime,
                    decoration: const InputDecoration(hintText: 'e.g. 9:00 AM'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: LabeledField(
                  label: 'Warning date',
                  hint: 'Reminder before the window closes.',
                  child: TextField(
                    controller: _warningDate,
                    keyboardType: TextInputType.number,
                    inputFormatters: [DateSlashFormatter()],
                    decoration: const InputDecoration(hintText: 'MM/DD/YYYY'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LabeledField(
                  label: 'End date',
                  child: TextField(
                    controller: _endDate,
                    keyboardType: TextInputType.number,
                    inputFormatters: [DateSlashFormatter()],
                    decoration: const InputDecoration(hintText: 'MM/DD/YYYY'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : const Text('Save schedule'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sendingNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.coralSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.coralLine),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.send_rounded, size: 18, color: AppColors.coralStrong),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Automated email + SMS sending (Mailgun + Twilio) runs server-side and '
              'will be enabled once Cloud Functions are deployed. Until then, use '
              '"Send link + code" on each employee in the Roster tab to share access manually.',
              style: TextStyle(color: Color(0xFF8A3A33), fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _templatesCard() {
    return SectionCard(
      title: 'Messages',
      subtitle: 'What employees receive. Tokens in [brackets] are filled in automatically. Edit as needed.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ChannelRow(icon: Icons.mail_outline_rounded, label: 'EMAIL'),
          const SizedBox(height: 10),
          LabeledField(label: 'Subject', child: TextField(controller: _emailSubjectC)),
          const SizedBox(height: 12),
          LabeledField(
            label: 'Body',
            child: TextField(controller: _emailBodyC, minLines: 5, maxLines: 10),
          ),
          const SizedBox(height: 8),
          Text(
            'From: ${widget.group.contactEmail.isEmpty ? '[group contact email]' : widget.group.contactEmail}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
          const Divider(height: 30),
          const _ChannelRow(icon: Icons.sms_outlined, label: 'TEXT MESSAGE'),
          const SizedBox(height: 10),
          LabeledField(
            label: 'Body',
            child: TextField(controller: _smsBodyC, minLines: 4, maxLines: 8),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Save messages'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inPersonCard() {
    return SectionCard(
      title: 'In-person enrollment',
      subtitle: 'Enroll an employee on the spot.',
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.point_of_sale_rounded, size: 18, color: AppColors.navy),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Open the Roster tab, choose an employee, and click "Enroll now" to '
              'launch the enrollment portal directly during an in-person session '
              '(no access code required).',
              style: TextStyle(color: AppColors.muted, fontSize: 13.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ChannelRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.coral),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.8)),
      ],
    );
  }
}
