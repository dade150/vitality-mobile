import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class SecureLocalStorage extends LocalStorage {
  const SecureLocalStorage();

  static const _storage = FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() {
    return _storage.read(key: supabasePersistSessionKey);
  }

  @override
  Future<bool> hasAccessToken() {
    return _storage.containsKey(key: supabasePersistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) {
    return _storage.write(key: supabasePersistSessionKey, value: persistSessionString);
  }

  @override
  Future<void> removePersistedSession() {
    return _storage.delete(key: supabasePersistSessionKey);
  }
}

class SupabaseConfig {
  static Future<void> initialize() async {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');

    if (url.isEmpty || key.isEmpty) {
      throw StateError(
        'SUPABASE_URL/SUPABASE_ANON_KEY mancanti: '
        'lancia con --dart-define-from-file=config/env.json',
      );
    }

    await Supabase.initialize(
      url: url,
      publishableKey: key,
      authOptions: const FlutterAuthClientOptions(
        localStorage: SecureLocalStorage(),
      ),
    );
  }
}

final supabase = Supabase.instance.client;