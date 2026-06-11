import 'package:flutter/material.dart';
import 'group_plan_form.dart';

/// Standalone screen for creating a new group.
class GroupFormScreen extends StatelessWidget {
  const GroupFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('New group'),
      ),
      body: GroupPlanForm(onSaved: () => Navigator.of(context).maybePop()),
    );
  }
}
