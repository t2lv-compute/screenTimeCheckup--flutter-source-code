import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:web/web.dart' as web;

/// AES-256-CBC encryption for localStorage values.
///
/// The key is generated once per device and stored (as base64) in localStorage
/// under [_keyStorageKey]. Storing key and data in the same place limits the
/// security guarantee: encrypted values are opaque to casual inspection and
/// browser-extension scripting, but are not protected against a full DevTools
/// session. This is the inherent ceiling of client-side-only encryption with
/// no user password.
class EncryptionService {
  static const String _keyStorageKey = '_stc_k';
  Key? _key;

  Future<void> init() async {
    final stored = web.window.localStorage.getItem(_keyStorageKey);
    if (stored != null) {
      try {
        _key = Key(base64Decode(stored));
        return;
      } catch (_) {
        // Key was corrupted — generate a fresh one.
        // Existing encrypted data will no longer be readable.
      }
    }
    _key = Key.fromSecureRandom(32);
    web.window.localStorage.setItem(_keyStorageKey, base64Encode(_key!.bytes));
  }

  /// Encrypts [plaintext] and returns a string in the format
  /// `base64(iv).base64(ciphertext)`.
  String encrypt(String plaintext) {
    assert(_key != null, 'EncryptionService.init() must be called first');
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(_key!));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${base64Encode(iv.bytes)}.${encrypted.base64}';
  }

  String? decrypt(String value) {
    try {
      final index = value.indexOf('.');
      final iv = IV(base64Decode(value.substring(0,index)));
      final encrypter = Encrypter(AES(_key!));
      final decrypted = encrypter.decrypt64(value.substring(index + 1), iv: iv);
      return decrypted;
    } catch (e) {
      return null;
    }
  }
}
