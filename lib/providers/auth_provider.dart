import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Firebase 초기화 여부 — main.dart에서 ProviderScope override로 설정됨
final firebaseAvailableProvider = Provider<bool>((_) => false);

/// 현재 로그인 상태 스트림
final authStateProvider = StreamProvider<User?>((ref) {
  if (!ref.read(firebaseAvailableProvider)) {
    return Stream.value(null);
  }
  return FirebaseAuth.instance.authStateChanges();
});

class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signInWithGoogle() async {
    try {
      state = const AsyncLoading();
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        state = const AsyncData(null);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      state = const AsyncData(null);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  Future<void> signInAnonymously() async {
    try {
      state = const AsyncLoading();
      await FirebaseAuth.instance.signInAnonymously();
      state = const AsyncData(null);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    state = const AsyncData(null);
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);
