import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinshift/core/saved_login.dart';
import 'package:pinshift/data/login_vault.dart';

final loginStorageProvider = Provider<LoginStorage>(
  (ref) => SecureLoginStorage(),
);

final authenticatorProvider = Provider<Authenticator>(
  (ref) => DeviceAuthenticator(),
);

final loginsControllerProvider =
    NotifierProvider<LoginsController, List<SavedLogin>>(LoginsController.new);

/// Holds saved logins in memory only while the logins sheet is unlocked.
class LoginsController extends Notifier<List<SavedLogin>> {
  @override
  List<SavedLogin> build() => const [];

  LoginStorage get _storage => ref.read(loginStorageProvider);

  Future<UnlockResult> unlock() async {
    final result = await ref
        .read(authenticatorProvider)
        .unlock('Unlock your saved logins');
    if (result == UnlockResult.unlocked) {
      state = await _storage.load();
    }
    return result;
  }

  /// Drops the decrypted logins from memory.
  void lock() => state = const [];

  Future<void> _set(List<SavedLogin> logins) async {
    state = logins;
    await _storage.save(logins);
  }

  Future<void> add({
    required String host,
    required String username,
    required String password,
  }) {
    return _set([
      ...state,
      SavedLogin(
        id: 'login-${DateTime.now().microsecondsSinceEpoch}',
        host: normalizeHost(host),
        username: username,
        password: password,
      ),
    ]);
  }

  Future<void> edit(
    String id, {
    required String host,
    required String username,
    required String password,
  }) {
    return _set([
      for (final login in state)
        if (login.id == id)
          login.copyWith(
            host: normalizeHost(host),
            username: username,
            password: password,
          )
        else
          login,
    ]);
  }

  Future<void> delete(String id) {
    return _set([
      for (final login in state)
        if (login.id != id) login,
    ]);
  }

  Future<void> restore(int index, SavedLogin login) {
    final logins = [...state];
    logins.insert(index.clamp(0, logins.length), login);
    return _set(logins);
  }
}
