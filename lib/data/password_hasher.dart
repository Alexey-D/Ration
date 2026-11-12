import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Хэш пароля: PBKDF2-HMAC-SHA256 со случайной солью.
/// Формат строки: `pbkdf2-sha256$<итерации>$<соль base64>$<хэш base64>`.
class PasswordHasher {
  final int iterations;
  const PasswordHasher({this.iterations = 20000});

  static const _scheme = 'pbkdf2-sha256';
  static const _keyLength = 32;

  String hash(String password) {
    final random = Random.secure();
    final salt = Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
    final key = _pbkdf2(utf8.encode(password), salt, iterations);
    return '$_scheme\$$iterations\$${base64.encode(salt)}\$${base64.encode(key)}';
  }

  bool verify(String password, String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != _scheme) return false;
    final rounds = int.tryParse(parts[1]);
    if (rounds == null || rounds < 1) return false;
    final key = _pbkdf2(utf8.encode(password), base64.decode(parts[2]), rounds);
    final expected = base64.decode(parts[3]);
    // сравнение за постоянное время
    if (key.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < key.length; i++) {
      diff |= key[i] ^ expected[i];
    }
    return diff == 0;
  }

  /// PBKDF2 (RFC 8018) для длины ключа ≤ 32 байт — один блок.
  static List<int> _pbkdf2(List<int> password, List<int> salt, int rounds) {
    final hmac = Hmac(sha256, password);
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = Uint8List.fromList(u);
    for (var i = 1; i < rounds; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result.sublist(0, _keyLength);
  }
}
