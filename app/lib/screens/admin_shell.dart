import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/group.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'group_detail_screen.dart';
import 'group_form_screen.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 820;
        if (wide) {
          return const Scaffold(
            body: Row(
              children: [
                SizedBox(width: 258, child: SideNav()),
                Expanded(child: GroupDashboard()),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const BrandWordmark(size: 20)),
          drawer: const Drawer(
            backgroundColor: AppColors.navy,
            child: SideNav(),
          ),
          body: const GroupDashboard(),
        );
      },
    );
  }
}

/// Left navigation rail (permanent on wide screens, in a drawer on narrow).
class SideNav extends StatelessWidget {
  const SideNav({super.key});

  @override
  Widget build(BuildContext context) {
    final email = AuthService().currentUser?.email ?? '';
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: BrandWordmark(size: 22),
          ),
          const SizedBox(height: 30),
          const NavItem(icon: Icons.business_rounded, label: 'Groups', active: true),
          const Spacer(),
          Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  child: Text(
                    email.isNotEmpty ? email[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          NavItem(
            icon: Icons.logout_rounded,
            label: 'Sign out',
            onTap: () => AuthService().signOut(),
          ),
        ],
      ),
    );
  }
}

class GroupDashboard extends StatelessWidget {
  const GroupDashboard({super.key});

  Future<void> _newGroup(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GroupFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Group>>(
      stream: GroupService().watchGroups(),
      builder: (context, snap) {
        final groups = snap.data ?? [];
        return CenteredColumn(
          maxWidth: 920,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Admin'),
                      const SizedBox(height: 6),
                      Text('Groups', style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text('Configure rates and invite employees to enroll.',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: AppColors.muted)),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _newGroup(context),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Create New Group'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (snap.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator(color: AppColors.coral)),
              )
            else if (snap.hasError)
              _ErrorState(snap.error.toString())
            else if (groups.isEmpty)
              _EmptyState(onCreate: () => _newGroup(context))
            else
              ...groups.map((g) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GroupCard(group: g),
                  )),
          ],
        );
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  final Group group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final created = group.createdAt != null
        ? DateFormat.yMMMd().format(group.createdAt!)
        : 'Not set';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
        ),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.coralSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.business_rounded, color: AppColors.coralStrong),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.name.isEmpty ? 'Untitled group' : group.name,
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        group.contactEmail.isEmpty ? 'No contact email' : group.contactEmail,
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                _statusPill(group.status),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Created', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.muted)),
                    Text(created, style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ],
            ),
          ),
        ),
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

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.coralSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.groups_rounded, color: AppColors.coralStrong, size: 30),
            ),
            const SizedBox(height: 18),
            Text('No groups yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('Create your first group to configure rates and invite employees.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Create New Group'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState(this.message);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.coralStrong),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Could not load groups.\n$message',
                  style: const TextStyle(color: AppColors.ink)),
            ),
          ],
        ),
      ),
    );
  }
}
