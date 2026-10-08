import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';

class MapControl extends StatelessWidget {
  const MapControl({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => PointerInterceptor(
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icon, size: 21),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      ),
    ),
  );
}

Future<bool?> explainPermissions(BuildContext context) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => PointerInterceptor(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 36,
                  color: AppColors.flame,
                ),
                const SizedBox(height: 16),
                Text(
                  c.t('permissionTitle'),
                  style: Theme.of(c).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text(c.t('permissionBody')),
                const SizedBox(height: 16),
                Text(
                  c.t('privacyNote'),
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(c.t('allow')),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(c.t('cancel')),
                ),
              ],
            ),
          ),
        ),
      ),
    );

class Countdown extends StatefulWidget {
  const Countdown({super.key});
  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  int value = 3;
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    for (var i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => value = i);
      await Future<void>.delayed(const Duration(milliseconds: 650));
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => PointerInterceptor(
    child: Dialog(
      backgroundColor: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.w900,
                color: AppColors.flame,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.t('cancel')),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showMapLayers(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (c) => PointerInterceptor(
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(c.t('layers'), style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 20),
            Text(c.t('offlineMapInfo')),
            const SizedBox(height: 12),
            const Text(
              '© OpenStreetMap contributors · ODbL',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Text(c.t('territoryLayers')),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.hexagon_outlined,
                  color: AppColors.muted,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(c.t('free')),
              ],
            ),
          ],
        ),
      ),
    ),
  ),
);
