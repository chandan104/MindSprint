import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Teacher PIN guarding kiosk-mode exit. Only a salted SHA-256 hash is
/// stored, in platform secure storage — the PIN itself never touches disk.
/// This gates a child leaving the assessment screen, not data access (RLS
/// does that), so a 4-digit PIN is proportionate.
class PinService {
  static const _hashKey = 'teacher_pin_hash';
  static const _saltKey = 'teacher_pin_salt';

  final FlutterSecureStorage _storage;
  PinService([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<bool> hasPin() async => (await _storage.read(key: _hashKey)) != null;

  Future<void> setPin(String pin) async {
    final salt = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _hashKey, value: _hash(pin, salt));
  }

  Future<bool> verify(String pin) async {
    final salt = await _storage.read(key: _saltKey);
    final stored = await _storage.read(key: _hashKey);
    if (salt == null || stored == null) return false;
    return _hash(pin, salt) == stored;
  }

  Future<void> clear() async {
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _saltKey);
  }

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
}
