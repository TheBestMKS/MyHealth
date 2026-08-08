import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class DocumentVaultService {
  DocumentVaultService({
    Directory? rootDirectory,
    Directory? cacheDirectory,
    SecretKey? testKey,
  }) : _rootDirectory = rootDirectory,
       _cacheDirectory = cacheDirectory,
       _testKey = testKey;

  static final instance = DocumentVaultService();
  static const _keyName = 'my_health_document_vault_key_v1';
  static const _secureStorage = FlutterSecureStorage();

  final Directory? _rootDirectory;
  final Directory? _cacheDirectory;
  final SecretKey? _testKey;
  final AesGcm _cipher = AesGcm.with256bits();

  bool isVaultPath(String path) => path.toLowerCase().endsWith('.mhv');

  Future<String> importFile(String sourcePath, String documentId) async {
    if (sourcePath.trim().isEmpty || isVaultPath(sourcePath)) return sourcePath;
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Прикреплённый файл не найден', sourcePath);
    }
    return importBytes(
      await source.readAsBytes(),
      fileName: _fileName(sourcePath),
      documentId: documentId,
    );
  }

  Future<String> importBytes(
    List<int> bytes, {
    required String fileName,
    required String documentId,
  }) async {
    final nonce = _cipher.newNonce();
    final box = await _cipher.encrypt(
      bytes,
      secretKey: await _secretKey(),
      nonce: nonce,
    );
    final directory = await _vaultDirectory();
    await directory.create(recursive: true);
    final safeId = documentId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final target = File(
      '${directory.path}${Platform.pathSeparator}$safeId-'
      '${DateTime.now().microsecondsSinceEpoch}.mhv',
    );
    await target.writeAsString(
      jsonEncode({
        'version': 1,
        'name': fileName,
        'nonce': base64Encode(box.nonce),
        'cipherText': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
      }),
      encoding: utf8,
      flush: true,
    );
    return target.path;
  }

  Future<File> materialize(String storedPath) async {
    final source = File(storedPath);
    if (!isVaultPath(storedPath)) return source;
    if (!await source.exists()) {
      throw FileSystemException(
        'Файл в медицинском сейфе не найден',
        storedPath,
      );
    }
    final payload = jsonDecode(await source.readAsString(encoding: utf8));
    if (payload is! Map<String, dynamic> || payload['version'] != 1) {
      throw const FormatException(
        'Неизвестный формат файла медицинского сейфа',
      );
    }
    final box = SecretBox(
      base64Decode(payload['cipherText'] as String),
      nonce: base64Decode(payload['nonce'] as String),
      mac: Mac(base64Decode(payload['mac'] as String)),
    );
    final bytes = await _cipher.decrypt(box, secretKey: await _secretKey());
    final directory = await _previewDirectory();
    await directory.create(recursive: true);
    await _removeExpiredPreviews(directory);
    final name = _safeFileName(payload['name'] as String? ?? 'document.bin');
    final target = File(
      '${directory.path}${Platform.pathSeparator}'
      '${DateTime.now().microsecondsSinceEpoch}_$name',
    );
    await target.writeAsBytes(bytes, flush: true);
    return target;
  }

  Future<void> deleteStoredFile(String storedPath) async {
    if (!isVaultPath(storedPath)) return;
    final file = File(storedPath);
    if (await file.exists()) await file.delete();
  }

  Future<void> clearVault() async {
    final vault = await _vaultDirectory();
    if (await vault.exists()) await vault.delete(recursive: true);
    final previews = await _previewDirectory();
    if (await previews.exists()) await previews.delete(recursive: true);
  }

  Future<Directory> _vaultDirectory() async {
    final root = _rootDirectory ?? await getApplicationSupportDirectory();
    return Directory('${root.path}${Platform.pathSeparator}document_vault');
  }

  Future<Directory> _previewDirectory() async {
    final root = _cacheDirectory ?? await getTemporaryDirectory();
    return Directory('${root.path}${Platform.pathSeparator}my_health_previews');
  }

  Future<SecretKey> _secretKey() async {
    if (_testKey != null) return _testKey;
    try {
      final saved = await _secureStorage.read(key: _keyName);
      if (saved != null && saved.isNotEmpty) {
        return SecretKey(base64Decode(saved));
      }
      final bytes = _randomKey();
      await _secureStorage.write(key: _keyName, value: base64Encode(bytes));
      return SecretKey(bytes);
    } catch (_) {
      final root = _rootDirectory ?? await getApplicationSupportDirectory();
      final keyFile = File(
        '${root.path}${Platform.pathSeparator}.document_vault.key',
      );
      if (await keyFile.exists()) {
        return SecretKey(base64Decode(await keyFile.readAsString()));
      }
      final bytes = _randomKey();
      await keyFile.parent.create(recursive: true);
      await keyFile.writeAsString(base64Encode(bytes), flush: true);
      return SecretKey(bytes);
    }
  }

  List<int> _randomKey() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256));
  }

  Future<void> _removeExpiredPreviews(Directory directory) async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      try {
        if ((await entity.stat()).modified.isBefore(cutoff)) {
          await entity.delete();
        }
      } catch (_) {
        // A viewer may still hold the temporary file open on desktop.
      }
    }
  }
}

String _fileName(String path) => path.split(RegExp(r'[\\/]')).last;

String _safeFileName(String value) {
  final normalized = value.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
  return normalized.trim().isEmpty ? 'document.bin' : normalized;
}
