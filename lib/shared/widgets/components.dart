import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 42});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.flame.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(size * .3),
      border: Border.all(color: AppColors.flame.withValues(alpha: .4)),
    ),
    child: Icon(
      Icons.local_fire_department_rounded,
      color: AppColors.flame,
      size: size * .7,
    ),
  );
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.border.withValues(alpha: .7)),
    ),
    child: child,
  );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = AppColors.flame, this.icon});
  final String text;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

class Metric extends StatelessWidget {
  const Metric({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.color = AppColors.text,
  });
  final String value, label;
  final IconData? icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (icon != null) ...[
        Icon(icon, color: AppColors.muted, size: 20),
        const SizedBox(height: 10),
      ],
      Text(
        value,
        style: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: -.8,
        ),
      ),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
    ],
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, this.subtitle, {super.key, this.trailing});
  final String title, subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 24),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.message, {
    super.key,
    this.icon = Icons.route_rounded,
    this.action,
  });
  final String message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      children: [
        Icon(icon, size: 40, color: AppColors.flame),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: AppColors.flame.withValues(alpha: .08),
    child: Text(
      context.t('demoNotice'),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 11, color: AppColors.muted),
    ),
  );
}

class PrimaryAction extends StatelessWidget {
  const PrimaryAction({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.active = false,
    this.busy = false,
  });
  final String title, subtitle;
  final VoidCallback? onPressed;
  final bool active, busy;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        backgroundColor: active ? AppColors.raised : AppColors.flame,
        foregroundColor: active ? AppColors.flame : AppColors.background,
      ),
      child: Row(
        children: [
          busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  active ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  size: 30,
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, size: 22),
        ],
      ),
    ),
  );
}

void showNotice(BuildContext context, String key) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(context.t(key))));
}
