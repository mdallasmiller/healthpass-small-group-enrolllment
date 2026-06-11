import 'package:flutter/material.dart';
import '../models/group.dart';
import '../services/group_service.dart';
import '../theme.dart';
import 'group_plan_form.dart';
import 'roster_view.dart';

/// Detail view for a single group: a "Plan & rates" tab (editable) and a
/// "Roster" tab (employees).
class GroupDetailScreen extends StatelessWidget {
  final Group group;
  const GroupDetailScreen({super.key, required this.group});

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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(group.name.isEmpty ? 'Group' : group.name),
          actions: [
            IconButton(
              tooltip: 'Delete group',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _delete(context),
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            indicatorColor: AppColors.coral,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xB3FFFFFF),
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Plan & rates'),
              Tab(text: 'Roster'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            GroupPlanForm(group: group),
            RosterView(groupId: group.id!),
          ],
        ),
      ),
    );
  }
}
