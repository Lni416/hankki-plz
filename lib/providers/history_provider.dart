import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile_models.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

final historyProvider =
    StreamProvider<List<CookingHistoryEntry>>((ref) {
  if (!ref.read(firebaseAvailableProvider)) {
    return Stream.value(const []);
  }

  final authAsync = ref.watch(authStateProvider);
  if (authAsync.isLoading) {
    final controller = StreamController<List<CookingHistoryEntry>>();
    ref.onDispose(controller.close);
    return controller.stream;
  }

  final uid = authAsync.value?.uid;
  if (uid == null) return Stream.value(const []);
  return FirestoreService.streamHistory(uid);
});
