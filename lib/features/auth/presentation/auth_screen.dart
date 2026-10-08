import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/components.dart';
import '../../map/presentation/demo_map.dart';
import '../data/account_controller.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(28),
        children: [
          Row(
            children: [
              const BrandMark(),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'БЕРІК ТҰЛҒА',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => ref
                    .read(localeProvider.notifier)
                    .set(ref.read(localeProvider) == 'kk' ? 'ru' : 'kk'),
                child: Text(ref.watch(localeProvider).toUpperCase()),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 270,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: const DemoMap(decorative: true),
            ),
          ),
          const SizedBox(height: 28),
          Tag(context.t('city'), icon: Icons.location_on_outlined),
          const SizedBox(height: 20),
          Text(
            context.t('welcomeTitle'),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 16),
          Text(
            context.t('welcomeBody'),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 16,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => ref.read(accountProvider.notifier).enterLocal(),
            child: Text(context.t('localWalk')),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => ref.read(accountProvider.notifier).enterDemo(),
            child: Text(context.t('exploreDemo')),
          ),
          if (AppConfig.hasBackend)
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
              ),
              icon: const Icon(Icons.login_rounded),
              label: Text(context.t('signIn')),
            ),
        ],
      ),
    ),
  );
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final login = TextEditingController(), password = TextEditingController();
  bool busy = false, hidePassword = true;
  String? error;

  @override
  void dispose() {
    login.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    final value = login.text.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      setState(() => error = 'invalidLogin');
      return;
    }
    if (password.text.isEmpty) {
      setState(() => error = 'passwordRequired');
      return;
    }
    final client = ref.read(backendProvider);
    if (client == null) {
      setState(() => error = 'configureBackend');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await client.auth.signInWithPassword(
        email: value,
        password: password.text,
      );
      if (response.session == null) throw const AuthException('No session');
      if (!mounted) return;
      await ref.read(accountProvider.notifier).load();
      if (mounted) {
        password.clear();
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthException catch (failure) {
      if (mounted) {
        setState(() {
          error = switch (failure.code) {
            'invalid_credentials' => 'incorrectLogin',
            'email_not_confirmed' => 'accountNotReady',
            'over_request_rate_limit' ||
            'over_email_send_rate_limit' => 'tooManyAttempts',
            _ => 'authError',
          };
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'authError');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: SafeArea(
      child: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            const BrandMark(size: 64),
            const SizedBox(height: 32),
            Text(
              context.t('auth'),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            Text(
              context.t('passwordAuthBody'),
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 32),
            TextField(
              key: const ValueKey('loginEmail'),
              controller: login,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              autocorrect: false,
              decoration: InputDecoration(
                labelText: context.t('loginEmail'),
                hintText: 'you@example.com',
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              key: const ValueKey('loginPassword'),
              controller: password,
              enabled: !busy,
              obscureText: hidePassword,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => submit(),
              decoration: InputDecoration(
                labelText: context.t('password'),
                suffixIcon: IconButton(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  tooltip: context.t(
                    hidePassword ? 'showPassword' : 'hidePassword',
                  ),
                  onPressed: busy
                      ? null
                      : () => setState(() => hidePassword = !hidePassword),
                  icon: Icon(
                    hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    context.t(error!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : submit,
              child: busy
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: context.t('signingIn'),
                      ),
                    )
                  : Text(context.t('signIn')),
            ),
            const SizedBox(height: 24),
            Text(
              context.t('adminCreatesAccounts'),
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}
