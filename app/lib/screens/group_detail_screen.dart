import 'package:flutter/material.dart';
import '../models/group.dart';
import '../services/group_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'group_plan_form.dart';
import 'roster_view.dart';

/// Detail view for a single group, using a left sidebar for navigation
/// (Plan & rates / Roster) to match the admin shell.
class GroupDetailScreen extends StatefulWidget {
  final Group group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;

  late final List<Widget> _bodies = [
    GroupPlanForm(group: widget.group),
    RosterView(groupId: widget.group.id!),
  ];

  void _select(int i) {
    setState(() => _index = i);
    _scaffoldKey.currentState?.closeDrawer();
  }

  Future<void> _delete() async {
    _scaffoldKey.currentState?.closeDrawer();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text('This permanently removes "${widget.group.name}" and its roster.'),
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
    await GroupService().delete(widget.group.id!);
    if (mounted) Navigator.of(context).maybePop();
  }

  Widget _sidebar() {
    final g = widget.group;
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NavItem(
            icon: Icons.arrow_back_rounded,
            label: 'All groups',
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.business_rounded, color: AppColors.coral, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    g.name.isEmpty ? 'Group' : g.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          NavItem(
            icon: Icons.tune_rounded,
            label: 'Plan & rates',
            active: _index == 0,
            onTap: () => _select(0),
          ),
          const SizedBox(height: 4),
          NavItem(
            icon: Icons.people_alt_rounded,
            label: 'Roster',
            active: _index == 1,
            onTap: () => _select(1),
          ),
          const Spacer(),
          Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
          const SizedBox(height: 10),
          NavItem(
            icon: Icons.delete_outline_rounded,
            label: 'Delete group',
            onTap: _delete,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = IndexedStack(index: _index, children: _bodies);
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 820;
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                SizedBox(width: 258, child: _sidebar()),
                Expanded(child: content),
              ],
            ),
          );
        }
        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(title: Text(widget.group.name.isEmpty ? 'Group' : widget.group.name)),
          drawer: Drawer(backgroundColor: AppColors.navy, child: _sidebar()),
          body: content,
        );
      },
    );
  }
}
