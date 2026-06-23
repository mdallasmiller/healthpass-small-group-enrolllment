import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/group.dart';
import '../services/group_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'campaign_view.dart';
import 'group_plan_form.dart';
import 'roster_view.dart';

/// Group detail as a content page (rendered inside the admin content area, so
/// the main sidebar stays put). Header with name + status + delete, and
/// in-content tabs for Plan & rates / Roster.
class GroupDetailPage extends StatelessWidget {
  final Group group;
  const GroupDetailPage({super.key, required this.group});

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text('This permanently removes "${group.name}" and its roster.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.muted))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await GroupService().delete(group.id!);
    if (context.mounted) Navigator.of(context).maybePop();
  }

  void _showHrLink(BuildContext context) {
    final baseUrl = Uri.base.origin;
    final hrUrl = '$baseUrl?hr=${group.id}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('HR Manager Form Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this link with the HR manager to fill in group details:',
                style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.field,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      hrUrl,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Copy',
                    icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.muted),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: hrUrl));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(40, 18, 40, 0),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.muted),
                      label: const Text('Groups', style: TextStyle(color: AppColors.muted)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () => _showHrLink(context),
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('HR Manager Link'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0A7D4F),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _delete(context),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.coralStrong,
                        side: const BorderSide(color: AppColors.coralLine, width: 1.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Flexible(
                      child: Text(group.name.isEmpty ? 'Group' : group.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineSmall),
                    ),
                    const SizedBox(width: 12),
                    _statusPill(group.status),
                  ],
                ),
                const SizedBox(height: 14),
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: AppColors.coral,
                  indicatorWeight: 3,
                  labelColor: AppColors.navy,
                  unselectedLabelColor: AppColors.muted,
                  labelStyle: TextStyle(fontWeight: FontWeight.w700),
                  unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
                  tabs: [
                    Tab(text: 'Plan & rates'),
                    Tab(text: 'Roster'),
                    Tab(text: 'Enrollment'),
                  ],
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: TabBarView(
              children: [
                GroupPlanForm(group: group),
                RosterView(group: group),
                CampaignView(group: group),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(GroupStatus s) {
    switch (s) {
      case GroupStatus.active:
        return const StatusPill('Active',
            color: Color(0xFF0A7D4F), background: Color(0xFFE7F6EE));
      case GroupStatus.closed:
        return const StatusPill('Closed',
            color: AppColors.muted, background: AppColors.field);
      case GroupStatus.draft:
        return const StatusPill('Draft',
            color: AppColors.coralStrong, background: AppColors.coralSoft);
    }
  }
}
