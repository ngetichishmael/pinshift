import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinshift/core/saved_login.dart';
import 'package:pinshift/data/login_vault.dart';
import 'package:pinshift/presentation/logins_controller.dart';

class _FakeStorage implements LoginStorage {
  List<SavedLogin> saved = [
    const SavedLogin(
      id: 'seed',
      host: 'hrms.example.com',
      username: 'me@example.com',
      password: 'hunter2',
    ),
  ];

  @override
  Future<List<SavedLogin>> load() async => [...saved];

  @override
  Future<void> save(List<SavedLogin> logins) async => saved = [...logins];
}

class _FakeAuth implements Authenticator {
  _FakeAuth(this.result);

  UnlockResult result;

  @override
  Future<UnlockResult> unlock(String reason) async => result;
}

void main() {
  group('host matching', () {
    test('normalizes addresses and URLs', () {
      expect(normalizeHost('https://WWW.Example.com/login?x=1'), 'example.com');
      expect(normalizeHost('example.com'), 'example.com');
      expect(normalizeHost('  '), '');
    });

    test('fills only the same site or its subdomains', () {
      const login = SavedLogin(
        id: 'a',
        host: 'example.com',
        username: 'u',
        password: 'p',
      );
      expect(loginMatchesHost(login, 'example.com'), isTrue);
      expect(loginMatchesHost(login, 'www.example.com'), isTrue);
      expect(loginMatchesHost(login, 'hrms.example.com'), isTrue);
      expect(loginMatchesHost(login, 'evil-example.com'), isFalse);
      expect(loginMatchesHost(login, 'example.com.evil.io'), isFalse);
      expect(loginMatchesHost(login, null), isFalse);
    });
  });

  group('logins controller', () {
    late _FakeStorage storage;
    late _FakeAuth auth;
    late ProviderContainer container;

    setUp(() {
      storage = _FakeStorage();
      auth = _FakeAuth(UnlockResult.unlocked);
      container = ProviderContainer(
        overrides: [
          loginStorageProvider.overrideWithValue(storage),
          authenticatorProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(container.dispose);
    });

    List<SavedLogin> logins() => container.read(loginsControllerProvider);
    LoginsController controller() =>
        container.read(loginsControllerProvider.notifier);

    test('passwords stay out of memory until unlocked', () async {
      expect(logins(), isEmpty);

      auth.result = UnlockResult.denied;
      expect(await controller().unlock(), UnlockResult.denied);
      expect(logins(), isEmpty);

      auth.result = UnlockResult.unavailable;
      expect(await controller().unlock(), UnlockResult.unavailable);
      expect(logins(), isEmpty);

      auth.result = UnlockResult.unlocked;
      expect(await controller().unlock(), UnlockResult.unlocked);
      expect(logins().single.password, 'hunter2');

      controller().lock();
      expect(logins(), isEmpty);
    });

    test('add, edit and delete persist to storage', () async {
      await controller().unlock();

      await controller().add(
        host: 'https://www.Other.com/signin',
        username: 'a',
        password: 'b',
      );
      expect(storage.saved.last.host, 'other.com');

      final id = storage.saved.last.id;
      await controller().edit(
        id,
        host: 'other.com',
        username: 'a2',
        password: 'b2',
      );
      expect(storage.saved.last.username, 'a2');
      expect(storage.saved.last.password, 'b2');

      await controller().delete(id);
      expect(storage.saved.any((l) => l.id == id), isFalse);
      expect(storage.saved.single.id, 'seed');
    });
  });
}
