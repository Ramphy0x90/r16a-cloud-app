import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/session/session_providers.dart';
import '../data/dashboard_api.dart';
import '../domain/dashboard_metrics.dart';

final dashboardApiProvider = Provider((ref) => DashboardApi(ref.watch(dioProvider)));

/// Mirrors the web client's `dashboardState$` — the owner id comes from the
/// signed-in user, same as every other owner-scoped endpoint.
final dashboardProvider = FutureProvider.autoDispose<DashboardResponse>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  return ref.watch(dashboardApiProvider).getDashboard(user.id);
});
