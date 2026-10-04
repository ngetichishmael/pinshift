import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pinshift/core/saved_login.dart';

const _loginsKey = 'pinshift.saved_logins';

abstract class LoginStorage {
  Future<List<SavedLogin>> load();

  Future<void> save(List<SavedLogin> logins);
}

/// Keychain on iOS, Keystore-backed encrypted preferences on Android.
class SecureLoginStorage implements LoginStorage {
  SecureLoginStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<List<SavedLogin>> load() async {
    final raw = await _storage.read(key: _loginsKey);
    if (raw == null) {
      return [];
    }
    try {
      return [
        for (final item in jsonDecode(raw) as List<dynamic>)
          SavedLogin.fromJson(item as Map<String, dynamic>),
      ];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> save(List<SavedLogin> logins) {
    return _storage.write(
      key: _loginsKey,
      value: jsonEncode([for (final login in logins) login.toJson()]),
    );
  }
}

enum UnlockResult { unlocked, denied, unavailable }

abstract class Authenticator {
  Future<UnlockResult> unlock(String reason);
}

/// Face ID, fingerprint, or the device passcode as fallback.
class DeviceAuthenticator implements Authenticator {
  DeviceAuthenticator([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<UnlockResult> unlock(String reason) async {
    try {
      if (!await _auth.isDeviceSupported()) {
        return UnlockResult.unavailable;
      }
      final ok = await _auth.authenticate(localizedReason: reason);
      return ok ? UnlockResult.unlocked : UnlockResult.denied;
    } on LocalAuthException catch (error) {
      return error.code == LocalAuthExceptionCode.noCredentialsSet ||
              error.code == LocalAuthExceptionCode.noBiometricHardware
          ? UnlockResult.unavailable
          : UnlockResult.denied;
    } catch (_) {
      return UnlockResult.denied;
    }
  }
}
