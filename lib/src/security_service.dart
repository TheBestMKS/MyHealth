import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:local_auth/local_auth.dart';

class PinCredential {
  const PinCredential({required this.hash, required this.salt});

  final String hash;
  final String salt;
}

class SecurityService {
  SecurityService._();

  static final instance = SecurityService._();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final Pbkdf2 _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 120000,
    bits: 256,
  );

  Future<PinCredential> createPin(String pin) async {
    final random = Random.secure();
    final salt = List<int>.generate(24, (_) => random.nextInt(256));
    final hash = await _derive(pin, salt);
    return PinCredential(hash: base64Encode(hash), salt: base64Encode(salt));
  }

  Future<bool> verifyPin(String pin, String hash, String salt) async {
    if (pin.isEmpty || hash.isEmpty || salt.isEmpty) return false;
    try {
      final actual = await _derive(pin, base64Decode(salt));
      final expected = base64Decode(hash);
      if (actual.length != expected.length) return false;
      var difference = 0;
      for (var index = 0; index < actual.length; index++) {
        difference |= actual[index] ^ expected[index];
      }
      return difference == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric() async {
    try {
      if (!await _localAuth.isDeviceSupported()) return false;
      return _localAuth.authenticate(
        localizedReason: 'Разблокируйте медицинский сейф «Моё здоровье»',
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<List<int>> _derive(String pin, List<int> salt) async {
    final key = await _kdf.deriveKeyFromPassword(password: pin, nonce: salt);
    return key.extractBytes();
  }
}
