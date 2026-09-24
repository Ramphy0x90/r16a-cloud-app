import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_controller.dart';
import '../core/auth/auth_state.dart';
import '../core/session/session_providers.dart';
import '../core/session/user_preferences.dart';
import '../features/auth/presentation/login_screen.dart';
import 'shell/home_shell.dart';
import 'theme/app_theme.dart';

class R16aCloudApp extends ConsumerWidget {
  const R16aCloudApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authControllerProvider.select((s) => s.status));

    // Mirrors `app.ts`'s `currentTheme$` subscription: the signed-in user's
    // `preferredTheme` drives the theme app-wide. Nothing to read before
    // sign-in (or while `/user/me` is loading), so fall back to the system
    // setting.
    final themeMode = status == AuthStatus.authenticated
        ? ref.watch(currentUserProvider).maybeWhen(
              data: (user) => switch (user.preferences.theme) {
                AppThemePreference.light => ThemeMode.light,
                AppThemePreference.dark => ThemeMode.dark,
              },
              orElse: () => ThemeMode.system,
            )
        : ThemeMode.system;

    return MaterialApp(
      title: 'R16a Cloud',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: switch (status) {
        // Session restore (read stored tokens / silent refresh) hasn't
        // resolved yet — avoid flashing the login screen before we know.
        AuthStatus.unknown => const _SplashScreen(),
        AuthStatus.unauthenticated => const LoginScreen(),
        AuthStatus.authenticated => const HomeShell(),
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
