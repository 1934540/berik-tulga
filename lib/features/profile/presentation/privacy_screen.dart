import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../shared/widgets/components.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.t('privacyTitle'))),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          PageHeading(context.t('privacyTitle'), 'Берік Тұлға'),
          Text(context.t('privacyPolicy')),
          const SizedBox(height: 24),
          Text(context.t('permissionBody')),
          const SizedBox(height: 24),
          Text(context.t('privacyNote')),
        ],
      ),
    ),
  );
}
