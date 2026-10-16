import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';

final statisticsProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => ref.watch(apiProvider).request('/api/user/statistics'),
);
