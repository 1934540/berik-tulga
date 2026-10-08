import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../domain/territory.dart';

class CaptureSummary extends StatelessWidget {
  const CaptureSummary({
    super.key,
    required this.capture,
    this.pending = false,
    this.local = false,
  });
  final CaptureResult capture;
  final bool pending, local;
  @override
  Widget build(BuildContext context) {
    final key = capture.area > 0
        ? 'territoryCaptured'
        : capture.defended > 0
        ? 'territoryDefended'
        : capture.attacked > 0
        ? 'territoryAttacked'
        : pending
        ? 'capturePending'
        : local
        ? 'captureOnlineOnly'
        : capture.status == 'disabled'
        ? 'captureDisabled'
        : capture.status == 'no_playable'
        ? 'captureNoPlayable'
        : 'captureRequirements';
    return Semantics(
      liveRegion: true,
      child: AnimatedContainer(
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: capture.area > 0
              ? AppColors.flame.withValues(alpha: .12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: capture.area > 0 ? AppColors.flame : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t(key),
              style: TextStyle(
                color: capture.area > 0 ? AppColors.flame : AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (capture.area > 0) ...[
              const SizedBox(height: 8),
              Text(
                '+${grouped(capture.area)} м²',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            if (capture.cells.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${capture.cells.length} ${context.t('cells')}',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
