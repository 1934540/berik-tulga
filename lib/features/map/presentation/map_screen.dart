import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/components.dart';
import '../../activity/presentation/activity_controller.dart';
import '../../activity/presentation/activity_result.dart';
import '../../auth/data/account_controller.dart';
import 'map_controls.dart';
import 'map_stats.dart';
import 'route_map.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  int centerVersion = 0;
  Future<void> action() async {
    final controller = ref.read(activityProvider.notifier);
    if (ref.read(activityProvider).current != null) {
      final result = await controller.finish();
      if (result != null && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ActivityResult(activity: result),
          ),
        );
      }
      return;
    }
    if (!ref.read(accountProvider).demo) {
      final accepted = await explainPermissions(context);
      if (accepted != true || !mounted) return;
    }
    if (!MediaQuery.of(context).disableAnimations) {
      final done = await showDialog<bool>(
        context: context,
        builder: (_) => const Countdown(),
      );
      if (done != true || !mounted) return;
    }
    await controller.start(
      notificationTitle: 'Берік Тұлға',
      notificationBody: context.t('live'),
    );
    if (mounted && ref.read(activityProvider).error == 'locationDenied') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('locationDenied')),
          action: SnackBarAction(
            label: context.t('settings'),
            onPressed: Geolocator.openAppSettings,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider),
        activity = ref.watch(activityProvider);
    final map = Stack(
      children: [
        Positioned.fill(
          child: RouteMap(
            demo: account.demo,
            points: activity.current?.points ?? const [],
            position: activity.position,
            centerVersion: centerVersion,
            tracking: activity.current != null && !activity.recovered,
            cells: activity.territoryCells,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.background,
                  AppColors.background.withValues(alpha: .94),
                  AppColors.background.withValues(alpha: 0),
                ],
                stops: const [0, .85, 1],
              ),
            ),
            child: Row(
              children: [
                const BrandMark(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('goodMorning'),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${account.profile?.name ?? ''}.',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.7,
                        ),
                      ),
                    ],
                  ),
                ),
                Tag(
                  account.demo ? '12 ${context.t('days')}' : context.t('city'),
                  icon: account.demo
                      ? Icons.local_fire_department_outlined
                      : Icons.location_on_outlined,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 106,
          left: 20,
          child: SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 15,
                  color: AppColors.flame,
                ),
                const SizedBox(width: 6),
                Text(
                  context.t('city'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 100,
          right: 18,
          child: Column(
            children: [
              MapControl(
                icon: Icons.layers_outlined,
                label: context.t('layers'),
                onPressed: () => showMapLayers(context),
              ),
              const SizedBox(height: 8),
              MapControl(
                icon: Icons.my_location_rounded,
                label: context.t('locate'),
                onPressed: () async {
                  if (!account.demo &&
                      await Geolocator.checkPermission() ==
                          LocationPermission.denied) {
                    if (!context.mounted) return;
                    final allowed = await showDialog<bool>(
                      context: context,
                      builder: (c) => PointerInterceptor(
                        child: AlertDialog(
                          title: Text(c.t('locate')),
                          content: Text(c.t('locationInfo')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: Text(c.t('cancel')),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: Text(c.t('locate')),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (allowed != true || !mounted) return;
                  }
                  await ref.read(activityProvider.notifier).locate();
                  if (mounted) setState(() => centerVersion++);
                },
              ),
            ],
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxHeight < 500 ||
            MediaQuery.textScalerOf(context).scale(16) > 22) {
          return ListView(
            children: [
              SizedBox(height: 380, child: map),
              MapStats(onAction: action),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: map),
            MapStats(onAction: action),
          ],
        );
      },
    );
  }
}
