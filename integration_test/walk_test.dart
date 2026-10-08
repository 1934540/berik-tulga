import 'dart:convert';

import 'package:berik_tulga/app.dart';
import 'package:berik_tulga/features/activity/presentation/activity_controller.dart';
import 'package:berik_tulga/features/activity/presentation/activity_result.dart';
import 'package:berik_tulga/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android demo walk is recorded and reopened from history', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('demo', false);
    await preferences.setBool('local_mode', false);
    await preferences.setString('locale', 'kk');
    await preferences.remove('activities_v1_demo');
    await app.main();
    await tester.pumpAndSettle();

    final demo = find.text('Демо режимді көру');
    await tester.ensureVisible(demo);
    await tester.tap(demo);
    await tester.pumpAndSettle();
    expect(find.text('БАСТАУ'), findsOneWidget);

    await tester.tap(find.text('БАСТАУ'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BerikTulgaApp)),
    );
    final recorded = container.read(activityProvider).current!;
    expect(recorded.points.length, greaterThanOrEqualTo(2));
    expect(recorded.distance, greaterThan(0));
    expect(recorded.steps, greaterThan(0));

    await tester.tap(find.text('АЯҚТАУ'));
    await tester.pumpAndSettle();
    expect(container.read(activityProvider).current, isNull);
    await preferences.reload();
    final raw = preferences.getString('activities_v1_demo')!;
    final entries = jsonDecode(raw) as List<dynamic>;
    expect(entries.any((entry) => entry['id'] == recorded.id), isTrue);
    expect(find.text('ЖАРАЙСЫҢ!'), findsWidgets);

    final returnMap = find.text('Картаға оралу');
    await tester.ensureVisible(returnMap);
    await tester.tap(returnMap);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await app.main();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Белсенділік').last);
    await tester.pumpAndSettle();
    expect(find.text('Таңғы серуен'), findsWidgets);
    await tester.tap(find.text('Таңғы серуен').first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<ActivityResult>(find.byType(ActivityResult)).activity.id,
      recorded.id,
    );
    expect(tester.takeException(), isNull);
    // Dispose tracking and the app retry timer before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
