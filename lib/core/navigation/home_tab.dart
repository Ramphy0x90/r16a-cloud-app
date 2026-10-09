import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The dock tabs, in dock order. Stands in for the web's top-level routes
/// (`/dashboard`, `/files`, `/photos`, `/profile`) so a screen can send the
/// user to another tab, like `routerLink="/files"` does on web.
enum HomeTab { dashboard, files, photos, profile }

/// The tab `HomeShell` shows. Auto-disposed with the shell, so a new sign-in
/// starts on the dashboard again.
final homeTabProvider =
    NotifierProvider.autoDispose<HomeTabController, HomeTab>(
      HomeTabController.new,
    );

class HomeTabController extends Notifier<HomeTab> {
  @override
  HomeTab build() => HomeTab.dashboard;

  void select(HomeTab tab) => state = tab;
}
