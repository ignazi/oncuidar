import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ClientEncryptionService {
  ClientEncryptionService({String? testKey}) : _testKey = testKey;
  final String? _testKey;
  final _storage = const FlutterSecureStorage();
  final AesGcm _cipher = AesGcm.with256bits();
  SecretKey? _activeKey;
  String? _activeUid;

  Future<bool> restoreLocalKey(String uid) async {
    final value = _testKey ?? await _storage.read(key: 'oncuidar.data-key.$uid');
    if (value == null) return false;
    await setKey(uid, value);
    return true;
  }

  Future<void> setKey(String uid, String encoded) async {
    final bytes = base64.decode(encoded);
    if (bytes.length != 32) throw const FormatException('Clave de datos inválida.');
    _activeKey = SecretKey(bytes);
    _activeUid = uid;
    if (_testKey == null) await _storage.write(key: 'oncuidar.data-key.$uid', value: encoded);
  }

  void lock() { _activeKey = null; _activeUid = null; }

  Future<String> encrypt(String uid, String text) async {
    final box = await _cipher.encrypt(utf8.encode(text), secretKey: _key(uid));
    return [base64UrlEncode(box.nonce), base64UrlEncode(box.cipherText), base64UrlEncode(box.mac.bytes)].join('.');
  }

  Future<String> decrypt(String uid, String value) async {
    final p = value.split('.');
    if (p.length != 3) throw const FormatException('Texto cifrado inválido.');
    final clear = await _cipher.decrypt(SecretBox(base64Url.decode(p[1]), nonce: base64Url.decode(p[0]), mac: Mac(base64Url.decode(p[2]))), secretKey: _key(uid));
    return utf8.decode(clear);
  }

  SecretKey _key(String uid) {
    if (_activeKey == null && _testKey != null) {
      _activeKey = SecretKey(base64.decode(_testKey));
      _activeUid = uid;
    }
    if (_activeKey == null || _activeUid != uid) throw StateError('Clave de datos no disponible.');
    return _activeKey!;
  }
}
