import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

/// HealthPass wordmark with a coral heart.
class BrandWordmark extends StatelessWidget {
  final Color color;
  final double size;
  const BrandWordmark({super.key, this.color = Colors.white, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.favorite_rounded, color: AppColors.coral, size: size),
        const SizedBox(width: 8),
        Text(
          'HealthPass',
          style: GoogleFonts.inter(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.95,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

/// Small uppercase eyebrow label (coral by default).
class Eyebrow extends StatelessWidget {
  final String text;
  final Color color;
  const Eyebrow(this.text, {super.key, this.color = AppColors.coral});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        color: color,
        fontWeight: FontWeight.w800,
        fontSize: 11.5,
        letterSpacing: 1.4,
      ),
    );
  }
}

/// A titled, bordered content card used to group form sections.
class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;

  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = subtitle;
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      if (sub != null) const SizedBox(height: 4),
                      if (sub != null)
                        Text(sub,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted)),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

/// A field with an uppercase label above it.
class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final String? hint;
  const LabeledField({super.key, required this.label, required this.child, this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            color: AppColors.muted,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
            letterSpacing: 0.6,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint!, style: GoogleFonts.inter(color: AppColors.muted, fontSize: 12)),
        ],
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// Centers content with a max width and makes it scrollable.
class CenteredColumn extends StatelessWidget {
  final double maxWidth;
  final EdgeInsets padding;
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  const CenteredColumn({
    super.key,
    this.maxWidth = 880,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => Scrollbar(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: padding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: crossAxisAlignment,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scrollable page body that fills the content area width (with padding),
/// used inside the admin content area so pages are not a narrow centered strip.
class PageBody extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;
  final EdgeInsets padding;
  final CrossAxisAlignment crossAxisAlignment;

  const PageBody({
    super.key,
    this.maxWidth = 1400,
    this.padding = const EdgeInsets.fromLTRB(40, 32, 40, 48),
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => Scrollbar(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: padding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: crossAxisAlignment,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen centered loading state.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: AppColors.coral)),
    );
  }
}

/// A navigation item for the navy sidebars (admin shell + group detail).
class NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final Color iconActiveColor;
  const NavItem({
    super.key,
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
    this.iconActiveColor = AppColors.coral,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.white : Colors.white.withValues(alpha: 0.72);
    return Material(
      color: active ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(icon, size: 19, color: active ? iconActiveColor : fg),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                      color: fg, fontWeight: FontWeight.w600, fontSize: 14.5)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A coral status pill (used for group status).
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  const StatusPill(this.label, {super.key, required this.color, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
            color: color, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5),
      ),
    );
  }
}
