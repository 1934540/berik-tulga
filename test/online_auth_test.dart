import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:berik_tulga/core/l10n/strings.dart';
import 'package:berik_tulga/core/services/providers.dart';
import 'package:berik_tulga/core/theme/app_theme.dart';
import 'package:berik_tulga/features/auth/data/account_controller.dart';
import 'package:berik_tulga/features/auth/presentation/auth_screen.dart';

const userId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
final loginField = find.byKey(const ValueKey('loginEmail'));
final passwordField = find.byKey(const ValueKey('loginPassword'));

SupabaseClient mockBackend(
  List<http.Request> requests, {
  int tokenFailures = 0,
  Future<void>? tokenGate,
}) {
  final expires = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  String encoded(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final token =
      '${encoded({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${encoded({'sub': userId, 'exp': expires, 'role': 'authenticated'})}.test';
  return SupabaseClient(
    'https://example.test',
    'sb_publishable_test',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      requests.add(request);
      final Object body;
      int status = 200;
      switch (request.url.path) {
        case '/auth/v1/token':
          await tokenGate;
          if (tokenFailures > 0) {
            tokenFailures--;
            status = 400;
            body = {
              'code': 'invalid_credentials',
              'msg': 'Invalid login credentials',
            };
          } else {
            body = {
              'access_token': token,
              'refresh_token': 'test-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': userId,
                'aud': 'authenticated',
                'email': 'walker@example.test',
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'app_metadata': <String, Object>{},
                'user_metadata': <String, Object>{},
              },
            };
          }
        case '/rest/v1/users':
          body = {'id': userId, 'full_name': 'Тест', 'username': 'test_user'};
        default:
          throw StateError('Unexpected mock request: ${request.url.path}');
      }
      return http.Response(
        jsonEncode(body),
        status,
        headers: {
          'content-type': 'application/json; charset=utf-8',
          'x-supabase-api-version': '2024-01-01',
        },
        request: request,
      );
    }),
  );
}

Future<void> openAuth(WidgetTester tester, SupabaseClient client) async {
  SharedPreferences.setMockInitialValues({'locale': 'ru'});
  final preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(preferences),
        backendProvider.overrideWithValue(client),
      ],
      child: MaterialApp(
        theme: buildTheme(),
        locale: const Locale('ru'),
        localizationsDelegates: const [
          StringsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ru')],
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                const Text('Главный экран'),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
                  ),
                  child: const Text('Открыть вход'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Открыть вход'));
  await tester.pumpAndSettle();
  expect(find.byType(AuthScreen), findsOneWidget);
}

Future<void> scrollTo(
  WidgetTester tester,
  Finder target, {
  double delta = 150,
}) async {
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: find.byType(Scrollable).last,
  );
}

Future<void> credentials(
  WidgetTester tester, {
  String login = 'walker@example.test',
  String password = 'example-password',
}) async {
  await scrollTo(tester, loginField);
  await tester.enterText(loginField, login);
  await scrollTo(tester, passwordField);
  await tester.enterText(passwordField, password);
  await scrollTo(tester, find.text('Войти'));
}

void main() {
  testWidgets(
    'password sign-in loads profile without signup or email requests',
    (tester) async {
      final requests = <http.Request>[];
      final client = (await tester.runAsync(
        () async => mockBackend(requests),
      ))!;
      addTearDown(() => tester.runAsync(client.dispose));
      await openAuth(tester, client);
      await credentials(
        tester,
        login: '  Walker@Example.test  ',
        password: '  example-password  ',
      );
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();
      expect(find.text('Главный экран'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(container.read(accountProvider).profile?.name, 'Тест');
      final exchange = requests.firstWhere(
        (r) => r.url.path == '/auth/v1/token',
      );
      expect(exchange.url.queryParameters['grant_type'], 'password');
      final body = jsonDecode(exchange.body) as Map<String, dynamic>;
      expect(body['email'], 'walker@example.test');
      expect(body['password'], '  example-password  ');
      expect(
        requests.every(
          (r) =>
              r.url.path == '/auth/v1/token' || r.url.path == '/rest/v1/users',
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('incorrect credentials show an error and allow another attempt', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final client = (await tester.runAsync(
      () async => mockBackend(requests, tokenFailures: 1),
    ))!;
    addTearDown(() => tester.runAsync(client.dispose));
    await openAuth(tester, client);
    await credentials(tester);
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(find.text('Неверный логин или пароль.'), findsOneWidget);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(client.auth.currentUser, isNull);
    await scrollTo(tester, find.text('Войти'));
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(find.text('Главный экран'), findsOneWidget);
    expect(requests.where((r) => r.url.path == '/auth/v1/token'), hasLength(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'empty password is rejected and duplicate requests are disabled',
    (tester) async {
      final requests = <http.Request>[];
      final gate = Completer<void>();
      final client = (await tester.runAsync(
        () async => mockBackend(requests, tokenGate: gate.future),
      ))!;
      addTearDown(() => tester.runAsync(client.dispose));
      await openAuth(tester, client);
      await credentials(tester, password: '');
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();
      expect(find.text('Введи пароль.'), findsOneWidget);
      expect(requests, isEmpty);
      await scrollTo(tester, passwordField, delta: -150);
      await tester.enterText(passwordField, 'example-password');
      await scrollTo(tester, find.text('Войти'));
      await tester.tap(find.text('Войти'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(requests, hasLength(1));
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Главный экран'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'password visibility and form work with large text in landscape',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      for (final size in [const Size(375, 812), const Size(812, 375)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        final requests = <http.Request>[];
        final client = (await tester.runAsync(
          () async => mockBackend(requests, tokenFailures: 1),
        ))!;
        await openAuth(tester, client);
        await credentials(tester);
        await scrollTo(tester, passwordField, delta: -150);
        expect(tester.widget<TextField>(passwordField).obscureText, isTrue);
        await tester.ensureVisible(find.byTooltip('Показать пароль'));
        await tester.tap(find.byTooltip('Показать пароль'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(passwordField).obscureText, isFalse);
        await tester.ensureVisible(find.byTooltip('Скрыть пароль'));
        await tester.tap(find.byTooltip('Скрыть пароль'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(passwordField).obscureText, isTrue);
        await scrollTo(tester, find.text('Войти'));
        await tester.tap(find.text('Войти'));
        await tester.pumpAndSettle();
        await scrollTo(
          tester,
          find.text('Неверный логин или пароль.'),
          delta: -150,
        );
        expect(find.text('Неверный логин или пароль.'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'auth layout: $size');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(client.dispose);
      }
    },
  );
}
